//
//  Throttle.swift
//  
//
//  Created by Van Simmons on 12/3/22.
//
import Atomics
import Channel
import Core

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    final class Throttler: Sendable, AtomicReference, Identifiable, Equatable {
        static func == (lhs: Publisher<Output>.Throttler, rhs: Publisher<Output>.Throttler) -> Bool {
            lhs.id == rhs.id
        }

        let value: Output
        let cancellable: Cancellable<Void>

        var id: ObjectIdentifier { .init(self) }

        init(_ value: Output, _ cancellable: Cancellable<Void>) {
            self.value = value
            self.cancellable = cancellable
        }
    }

    private func sleepThenSend<C: Clock>(
        value: Output,
        throttler: ManagedAtomic<Throttler?>,
        folder: DownstreamFold,
        clock: C,
        duration: C.Duration,
        synchronizer: Channel<Swift.Result<Void, Swift.Error>>
    ) -> Cancellable<Void> {
        .init {
            try await synchronizer.read().get()
            try await clock.sleep(until: clock.now.advanced(by: duration), tolerance: .none)
            do {
                guard let currentThrottler = throttler.load(ordering: .sequentiallyConsistent) else {
                    fatalError("Missing throttler")
                }
                try folder.send(.value(currentThrottler.value))
            }
            catch { fatalError("Could not send") }
            let previous = throttler.exchange(.none, ordering: .sequentiallyConsistent)
            guard previous != nil else {
                fatalError("throttle synchronization failure")
            }
            try? previous?.cancellable.cancel()
        }
    }

    private func sendThenSleep<C: Clock>(
        value: Output,
        throttler: ManagedAtomic<Throttler?>,
        folder: DownstreamFold,
        clock: C,
        duration: C.Duration,
        synchronizer: Channel<Swift.Result<Void, Swift.Error>>
    ) -> Cancellable<Void> where C.Duration == Swift.Duration {
        .init {
            try await synchronizer.read().get()
            do { try folder.send(.value(value)) }
            catch { fatalError("Could not send") }
            try await clock.sleep(until: clock.now.advanced(by: duration), tolerance: .none)
            let previous = throttler.exchange(.none, ordering: .sequentiallyConsistent)
            guard previous != nil else {
                fatalError("throttle synchronization failure")
            }
            try? previous?.cancellable.cancel()
        }
    }

    func swapThrottler(
        newValue: Output,
        cancellable: Cancellable<Void>,
        throttler: ManagedAtomic<Throttler?>,
        synchronizer: Channel<Swift.Result<Void, Swift.Error>>
    ) async throws -> Void {
        guard throttler.exchange(.init(newValue, cancellable), ordering: .sequentiallyConsistent) == nil else {
            try await synchronizer.write(.failure(SynchronizationError()))
            fatalError("throttle synchronization failure")
        }
        try await synchronizer.write(.success(()))
    }

    func throttle<C: Clock>(
        clock: C,
        interval duration: Swift.Duration,
        latest: Bool = false
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let isDispatchable = ManagedAtomic<Box<DownstreamState>>.init(.init(value: .init()))
            let downstreamQueue = Queue<Publisher<Output>.Result>.init(buffering: .unbounded)
            let downstreamFolderRef = MutableBox<DownstreamFold?>.init(value: .none)

            let synchronizer = Channel<Swift.Result<Void, Swift.Error>>()
            let throttler: ManagedAtomic<Throttler?> = .init(.none)

            return self(onStartup: resumption) { r in
                try Self.check(isDispatchable)
                if downstreamFolderRef.value == nil, case .value = r {
                    downstreamFolderRef.set(
                        value: await Self.createDownstreamFold(isDispatchable, downstreamQueue, downstream)
                    )
                }
                let folder = downstreamFolderRef.value!
                let box = throttler.load(ordering: .sequentiallyConsistent)
                switch r {
                    case .completion:
                        try? box?.cancellable.cancel()
                        _ = await box?.cancellable.result
                        downstreamQueue.continuation.yield(r)
                        downstreamQueue.finish()
                        switch await downstreamFolderRef.value?.result {
                            case .success, .none: return
                            case let .failure(error): throw error
                        }

                    case let .value(newValue):
                        switch (box, latest) {
                            case (.none, false):
                                let cancellable = sendThenSleep(
                                    value: newValue,
                                    throttler: throttler,
                                    folder: folder,
                                    clock: clock,
                                    duration: duration,
                                    synchronizer: synchronizer
                                )
                                try await swapThrottler(
                                    newValue: newValue,
                                    cancellable: cancellable,
                                    throttler: throttler,
                                    synchronizer: synchronizer
                                )
                             case (.none, true):
                                 let cancellable = sleepThenSend(
                                    value: newValue,
                                    throttler: throttler,
                                    folder: folder,
                                    clock: clock,
                                    duration: duration,
                                    synchronizer: synchronizer
                                )
                                try await swapThrottler(
                                    newValue: newValue,
                                    cancellable: cancellable,
                                    throttler: throttler,
                                    synchronizer: synchronizer
                                )
                             case (.some, false):
                                return
                            case let (.some(currentBox), true):
                                let replacement = Throttler(newValue, currentBox.cancellable)
                                let (success, hopefullyNone) = throttler.compareExchange(
                                    expected: currentBox,
                                    desired: replacement,
                                    ordering: .sequentiallyConsistent
                                )
                                guard hopefullyNone == nil || hopefullyNone == currentBox else {
                                    fatalError("could not reach this state")
                                }
                                guard !success else {
                                    return
                                }
                                let cancellable = sleepThenSend(
                                    value: newValue,
                                    throttler: throttler,
                                    folder: folder,
                                    clock: clock,
                                    duration: duration,
                                    synchronizer: synchronizer
                                )
                                try await swapThrottler(
                                    newValue: newValue,
                                    cancellable: cancellable,
                                    throttler: throttler,
                                    synchronizer: synchronizer
                                )
                        }
                }
            }
        }
    }
}
