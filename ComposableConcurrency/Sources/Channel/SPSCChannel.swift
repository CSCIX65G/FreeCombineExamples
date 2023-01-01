//
//  SPSCChannel.swift
//
//
//  Created by Van Simmons on 11/28/22.
//  FIXME: This is woefully non-performant and needs to adapt a real MPMC fifo algorithm
//  But I don't want to invent one and all the ones I can find are C++ header macros.  sigh.
//

import Atomics
import Core
@_implementationOnly import DequeModule

public final class SPSCChannel<Value> {
    private struct ChannelError: Error { let wrapper: Wrapper }

    private final class Wrapper: AtomicReference, Identifiable, Equatable {
        let value: AsyncResult<Value?, Error>
        let reader: Resumption<Value>?
        let writer: Resumption<Void>?

        init(
            result: AsyncResult<Value?, Error>,
            reader: Resumption<Value>? = .none,
            writer: Resumption<Void>? = .none
        ) {
            self.value = result
            self.reader = reader
            self.writer = writer
        }

        init(
            _ value: Value?,
            reader: Resumption<Value>? = .none,
            writer: Resumption<Void>? = .none
        ) {
            self.value = .success(value)
            self.reader = reader
            self.writer = writer
        }

        static func == (lhs: SPSCChannel<Value>.Wrapper, rhs: SPSCChannel<Value>.Wrapper) -> Bool { lhs.id == rhs.id }
        var id: ObjectIdentifier { .init(self) }
    }

    private let wrapped: ManagedAtomic<Wrapper>

    public func cancel(with error: Error = CancellationError()) throws -> Void {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        while true {
            _ = try localWrapped.value.get()
            let reader = localWrapped.reader
            let writer = localWrapped.writer
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: .init(result: .failure(error), reader: .none, writer: .none),
                ordering: .sequentiallyConsistent
            )
            if success {
                reader?.resume(throwing: error)
                writer?.resume(throwing: error)
                break
            } else {
                localWrapped = newLocalWrapped
            }
        }
    }

    public init(_ value: Value? = .none) {
        self.wrapped = ManagedAtomic(Wrapper(value))
    }

    public func write(blocking: Bool = true) async throws -> Void where Value == Void {
        try await write(blocking: blocking, ())
    }

    public func write(blocking: Bool = true, _ value: Value) async throws -> Void {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        guard localWrapped.writer == nil else { throw ChannelOccupiedError() }
        while true {
            switch try (localWrapped.value.get(), blocking) {
                case (.some, true):
                    guard let newLocalWrapped = try await blockForWriting(localWrapped, .none) else { return }
                    localWrapped = newLocalWrapped
                case (.none, true):
                    guard let newLocalWrapped = try await dispatchReaderOrBlockForWriting(localWrapped, value) else { return }
                    localWrapped = newLocalWrapped
                case (.some, false):
                    throw FailedWriteError()
                case (.none, false):
                    let newVar = Wrapper(value, reader: localWrapped.reader, writer: .none)
                    let (success, newLocalWrapped) = wrapped.compareExchange(
                        expected: localWrapped,
                        desired: newVar,
                        ordering: .sequentiallyConsistent
                    )
                    guard !success else { return }
                    localWrapped = newLocalWrapped
            }
        }
    }

    /// Non-blocking, failable read
    public func read(blocking: Bool = true) async throws -> Value {
        var localWrapped = wrapped.load(ordering: .sequentiallyConsistent)
        guard localWrapped.reader == nil else { throw ChannelOccupiedError() }
        while true {
            switch try localWrapped.value.get() {
                case let .some(value):
                    do { return try dispatchWriter(localWrapped, value) }
                    catch {
                        guard let error = error as? ChannelError else { throw error }
                        localWrapped = error.wrapper
                        continue
                    }
                case .none:
                    if !blocking { throw FailedReadError() }
                    do { return try await blockForReading(&localWrapped) }
                    catch { continue }
            }
        }
    }

    private func blockForWriting(_ localWrapped: Wrapper, _ value: Value?) async throws -> Wrapper? {
        do {
            let _: Void = try await pause { resumption in
                let newVar = Wrapper(value, reader: localWrapped.reader, writer: resumption)
                let (success, newLocalWrapped) = wrapped.compareExchange(
                    expected: localWrapped,
                    desired: newVar,
                    ordering: .sequentiallyConsistent
                )
                if success { return }
                else { resumption.resume(throwing: ChannelError(wrapper: newLocalWrapped)) }
            }
            return .none
        } catch {
            guard let error = error as? ChannelError else { throw error }
            return error.wrapper
        }
    }

    private func dispatchReaderOrBlockForWriting(_ localWrapped: Wrapper, _ value: Value) async throws -> Wrapper? {
        if let reader = localWrapped.reader {
            let newVar = Wrapper(.none, reader: .none, writer: localWrapped.writer)
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: newVar,
                ordering: .sequentiallyConsistent
            )
            if success {
                reader.resume(returning: value)
                return .none
            } else {
                return newLocalWrapped
            }
        } else {
            return try await blockForWriting(localWrapped, value)
        }
    }

    private func blockForReading(_ localWrapped: inout SPSCChannel<Value>.Wrapper) async throws -> Value {
        let value: Value = try await pause { resumption in
            let newVar = Wrapper(.none, reader: resumption, writer: localWrapped.writer)
            let (success, newLocalWrapped) = wrapped.compareExchange(
                expected: localWrapped,
                desired: newVar,
                ordering: .sequentiallyConsistent
            )
            if success {
                return
            }
            else {
                localWrapped = newLocalWrapped
                resumption.resume(throwing: ChannelError(wrapper: newLocalWrapped))
            }
        }
        return value
    }

    private func dispatchWriter(_ localWrapped: Wrapper, _ value: Value) throws -> Value {
        let writer: Resumption<Void>? = localWrapped.writer
        let newVar = Wrapper(.none, reader: localWrapped.reader, writer: .none)
        let (success, newLocalWrapped) = wrapped.compareExchange(
            expected: localWrapped,
            desired: newVar,
            ordering: .sequentiallyConsistent
        )
        if success {
            writer?.resume()
            return value
        } else {
            throw ChannelError(wrapper: newLocalWrapped)
        }
    }
}
