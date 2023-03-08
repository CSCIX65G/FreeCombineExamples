//
//  Promise.swift
//
//
//  Created by Van Simmons on 2/15/23.
//
import Atomics
import Core
import SendableAtomics

public final class UnbreakablePromise<Value: Sendable>: Sendable {
    public typealias Producer = Value
    public typealias Consumer = @Sendable (Value) throws -> Void

    private let function: StaticString
    private let file: StaticString
    private let line: UInt
    private let deinitBehavior: Uncancellables.LeakBehavior

    private let setProducer: @Sendable (Producer) throws -> (Producer, Consumer)?
    private let setConsumer: @Sendable (@escaping Consumer) throws -> (Producer, Consumer)?

    private var leakFailureString: String {
        "LEAKED \(type(of: Self.self)):\(self). CREATED in \(function) @ \(file): \(line)"
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: Uncancellables.LeakBehavior = .assert,
        _ value: Value? = .none
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
        do {
            _ = try setConsumer { _ in }
            return
        }
        catch {
            switch deinitBehavior {
                case .assert: // Taking the NIO approach...
                    assertionFailure("ASSERTION FAILURE: \(self.leakFailureString)") // Taking the NIO approach
                case .fatal:  // Taking the Chuck Norris approach
                    fatalError("FATAL ERROR: \(self.leakFailureString)")
            }
        }
    }
}

public extension UnbreakablePromise {
    func wait(with resumption: UnfailingResumption<Value>) throws -> Void {
        try wait(with: resumption.resume(returning:))
    }

    func wait(with consumer: @escaping Consumer) throws -> Void {
        guard let (result, _) = try setConsumer(consumer) else { return }
        try consumer(result)
    }

    func succeed(_ value: Value) throws -> Void {
        guard let (_, consumer) = try setProducer(value) else { return }
        try? consumer(value)
    }

    var value: Value {
        get async {
            await unfailingPause(for: Value.self) { resumption in
                guard let (result, _) = try? setConsumer(resumption.resume(returning:)) else { return }
                try! resumption.resume(returning: result)
            }
        }
    }
}

public extension UnbreakablePromise where Value == Void {
    func succeed() throws -> Void {
        try succeed(())
    }
}
