//
//  Meet.swift
//
//
//  Created by Van Simmons on 3/4/23.
//
import Core
import SendableAtomics

/*:
 The Meet class provides functionality for synchronizing between a producer and a consumer. It provides the ability to set a producer, which produces a value of type Value or an error, and a consumer, which receives the produced value or error.  If the consumer is set first, the consumer waits for the producer to arrive, if the producer is set first it waits for the consumer. Waiting is accomplished via callbacks.

 The Completion, Producer, and Consumer type aliases define the types of closures used to handle the produced value or error, and to notify the consumer when the producer has completed.

 As an affordance, Meet also has an initializer that takes several arguments, including the function, file, and line number where the Meet instance was created, a deinitBehavior argument that specifies what should happen if the instance is deallocated without being cancelled, and an optional value argument that allows a producer to be set upon initialization.

 Meet is Sendable if Value is Sendable.
 */
public final class Meet<Value> {
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

    /*:
     The deinit method of the Meet class is responsible for cleaning up any resources that were allocated by the instance of the class. In particular, it needs to ensure that any unresolved promises are cancelled, so that any coroutines that are waiting on the promises can be resumed.

     The deinit method first attempts to cancel any unresolved promises by calling the cancel method with a dummy value of type Void. If the cancel method throws an error, it means that the promise was already resolved or cancelled, so the method simply returns.

     Next, the deinit method checks the deinitBehavior property of the class, which determines what action to take if any promises are leaked. If the behavior is set to .cancel, the method simply does nothing. If the behavior is set to .assert, the method raises an assertion failure, indicating that a promise was leaked. If the behavior is set to .fatal, the method raises a fatal error, terminating the program.

     The reason for the deinit method taking this form is to ensure that any resources associated with a Meet instance are properly cleaned up, even if the instance is not used correctly by the caller. In particular, if a Meet instance is leaked and not properly deallocated, any coroutines that are waiting on its promises will be blocked indefinitely, leading to deadlocks or other issues. By providing different behavior options for handling leaked promises, the Meet class allows the caller to choose an appropriate level of safety for their use case.
     */
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

extension Meet: Sendable where Value: Sendable { }

/*:
 This extension provides additional methods and computed properties for the Meet class. Here's a brief explanation of what each method and property does:

 * complete(_:, with:): Calls the completion closure with the specified result.
 * cancel(with:): Fails the Meet instance with a CancellationError, and calls the completion closure with the resulting Result.
 * fail(_:with:): Fails the Meet instance with the specified error, and calls the completion closure with the resulting Result.
 * succeed(_:with:): Writes a successful Result with the specified value to the Meet instance, and calls the completion closure with the resulting Result.
 * write(_:with:): Writes the specified result to the Meet instance, and calls the completion closure with the resulting Result. If there is a consumer waiting for a result, it will be called with the same result value.
 * succeed(_:):: Writes a successful Result with the specified value to the Meet instance using async/await syntax.
 * fail(_:):: Fails the Meet instance with the specified error using async/await syntax.
 * write(result:): Writes the specified result to the Meet instance using async/await syntax. This method uses pause(for: Resumption<Value>) to pause the current task and wait for the completion closure to be called.
 * consume(_:with:): Calls the consumer closure with the specified result.
 * read(with resumption:): Calls the read(with:) method with a closure that will resume the specified resumption.
 * read(with:): Sets the consumer closure for the Meet instance, and calls it with the latest result value if there is one. The complete(_:, with:) method is called with the result of calling the consumer closure.
 * value: A computed property that returns the latest Value value from the Meet instance using async/await syntax. This property uses pause(for: Value) to pause the current task and wait for the completion closure to be called.
 * result: A computed property that returns the latest Result<Value, Swift.Error> value from the Meet instance using async/await syntax. If there is an error, it is wrapped in a failure case of the Result.
 */
public extension Meet {
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

public extension Meet where Value == Void {
    @Sendable func succeed(with completion: @escaping Completion) throws -> Void {
        try succeed((), with: completion)
    }

    @Sendable func succeed() async throws -> Void {
        try await succeed(())
    }
}
