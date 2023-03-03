//
//  Promise.swift
//  
//
//  Created by Van Simmons on 2/15/23.
//
import Atomics
import Core
import SendableAtomics

public final class Promise<Value: Sendable>: Sendable {
    public typealias Producer = Result<Value, Swift.Error>
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
        _ value: Result<Value, Swift.Error>? = .none
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
        do { try cancel() }
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

public extension Promise {
    func wait(with resumption: Resumption<Value>) throws -> Void {
        try wait(with: resumption.resume(with:))
    }

    func wait(with consumer: @escaping Consumer) throws -> Void {
        guard let (result, _) = try setConsumer(consumer) else { return }
        try consumer(result)
    }

    func cancel() throws -> Void {
        try fail(CancellationError())
    }

    func fail(_ error: Swift.Error) throws -> Void {
        try resolve(.failure(error))
    }

    func succeed(_ value: Value) throws -> Void {
        try resolve(.success(value))
    }

    func resolve(_ result: Result<Value, Swift.Error>) throws -> Void {
        guard let (_, consumer) = try setProducer(result) else { return }
        try? consumer(result)
    }

    var value: Value {
        get async throws {
            try await pause(for: Value.self) { resumption in
                do {
                    guard let (result, _) = try setConsumer(resumption.resume(with:)) else { return }
                    try resumption.resume(with: result)
                } catch {
                    try? resumption.resume(throwing: error)
                }
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

public extension Promise where Value == Void {
    func succeed() throws -> Void {
        try succeed(())
    }
}
