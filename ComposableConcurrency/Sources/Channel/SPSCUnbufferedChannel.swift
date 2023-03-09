//
//  SPSCChannel.swift
//
//
//  Created by Van Simmons on 3/4/23.
//
import Core
import SendableAtomics

public final class SPSCUnbufferedChannel<Value> {
    public typealias Completion = @Sendable (Result<Void, Swift.Error>) -> Void
    public typealias Producer = (value: Result<Value, Swift.Error>, completion: Completion)
    public typealias Consumer = @Sendable (Result<Value, Swift.Error>) throws -> Void

    private let function: StaticString
    private let file: StaticString
    private let line: UInt
    private let deinitBehavior: Cancellables.LeakBehavior

    private let setProducer: @Sendable (Producer) throws -> (Producer, Consumer)?
    private let setConsumer: @Sendable (@escaping Consumer) throws -> (Producer, Consumer)?

    private var leakFailureString: String {
        "LEAKED \(type(of: Self.self)):\(self). CREATED in \(function) @ \(file): \(line)"
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Cancellables.LeakBehavior = .assert,
        value: (Result<Value, Swift.Error>, @Sendable (Result<Void, Swift.Error>) -> Void)? = .none
    ) {
        let localPair = Pair<Producer, Consumer>.init(left: value)

        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.setProducer = localPair.setLeft
        self.setConsumer = localPair.setRight
    }

    deinit {
        do { try cancel(with: void1) }
        catch { return }
        switch deinitBehavior {
            case .cancel: // Taking the combine approach...
                ()
            case .assert: // Taking the NIO approach...
                assertionFailure("ASSERTION FAILURE: \(self.leakFailureString)") // Taking the NIO approach
            case .fatal:  // Taking the Chuck Norris approach
                fatalError("FATAL ERROR: \(self.leakFailureString)")
        }
    }
}

extension SPSCUnbufferedChannel: Sendable where Value: Sendable { }

public extension SPSCUnbufferedChannel {
    @Sendable func complete(
        _ result: Result<Void, Swift.Error>,
        with completion: @escaping Completion
    ) throws -> Void {
        completion(result)
    }

    @Sendable func cancel(with completion: @escaping Completion) throws -> Void {
        try fail(CancellationError(), with: completion)
    }

    @Sendable func fail(_ error: Swift.Error, with completion: @escaping Completion) throws -> Void {
        try write(.failure(error), with: completion)
    }

    @Sendable func succeed(_ value: Value, with completion: @escaping Completion) throws -> Void {
        try write(.success(value), with: completion)
    }

    @Sendable func write(
        _ result: Result<Value, Swift.Error>,
        with completion: @escaping @Sendable (Result<Void, Swift.Error>) -> Void
    ) throws -> Void {
        guard let (_, consumer) = try setProducer((value: result, completion: completion)) else { return }
        try? consumer(result)
    }

    @Sendable func succeed(_ value: Value) async throws -> Void {
        try await write(result: .success(value))
    }

    @Sendable func fail(_ error: Error) async throws -> Void {
        try await write(result: .failure(error))
    }

    @Sendable func write(result: Result<Value, Swift.Error>) async throws -> Void {
        try await pause(for: Void.self) { resumption in
            do { try write(result, with: { try? resumption.resume(with: $0) }) }
            catch { try? resumption.resume(throwing: error) }
        }
    }

    @Sendable func consume(
        _ result: Result<Value, Swift.Error>,
        with  consumer: @escaping Consumer
    ) throws -> Void {
        try consumer(result)
    }

    @Sendable func read(with resumption: Resumption<Value>) throws -> Void {
        try read(with: resumption.resume(with:))
    }

    @Sendable func read(with consumer: @escaping Consumer) throws -> Void {
        guard let (result, _) = try setConsumer(consumer) else { return }
        try? complete(Result { try consume(result.value, with: consumer) }, with: result.completion)
    }

    var value: Value {
        get async throws {
            try await pause(for: Value.self) { resumption in
                do { try read(with: resumption.resume(with:)) }
                catch { try! resumption.resume(throwing: error) }
            }
        }
    }

    var result: Result<Value, Swift.Error> {
        get async {
            do { return try await .success(value) }
            catch { return .failure(error) }
        }
    }
}

public extension SPSCUnbufferedChannel where Value == Void {
    @Sendable func succeed(with completion: @escaping Completion) throws -> Void {
        try succeed((), with: completion)
    }

    @Sendable func succeed() async throws -> Void {
        try await succeed(())
    }
}
