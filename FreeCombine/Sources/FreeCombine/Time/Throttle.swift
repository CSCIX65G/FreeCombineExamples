//
//  Throttle.swift
//  
//
//  Created by Van Simmons on 12/3/22.
//
import Atomics
import Core

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Publisher {
    func throttle<C: Clock>(
        clock: C,
        interval duration: Swift.Duration,
        latest: Bool = false
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            let isDispatchable = ManagedAtomic<Box<DownstreamState>>.init(.init(value: .init()))
            let downstreamQueue = Queue<Publisher<Output>.Result>.init(buffering: .unbounded)
            let downstreamFolderRef = MutableBox<DownstreamFold?>.init(value: .none)

            let throttler: ManagedAtomic<Box<(value: Output , cancellable: Cancellable<Void>)>?> = .init(.none)

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
                        _ = await box?.value.cancellable.result
                        downstreamQueue.continuation.yield(r)
                        downstreamQueue.finish()
                        switch await downstreamFolderRef.value?.result {
                            case .success, .none: return
                            case let .failure(error): throw error
                        }

                    case let .value(newValue):
                        switch (box, latest) {
                            case (.none, false):
                                let trigger = await Promise<Void>()
                                let cancellable = Cancellable {
                                    try await trigger.value
                                    do { try folder.send(.value(newValue)) }
                                    catch { fatalError("Could not send") }
                                    try await clock.sleep(until: clock.now.advanced(by: duration), tolerance: .none)
                                    _ = throttler.exchange(.none, ordering: .sequentiallyConsistent)
                                }
                                _ = throttler.exchange(Box(value: (newValue, cancellable)), ordering: .sequentiallyConsistent)
                                try! trigger.succeed()
                            case (.none, true):
                                let trigger = await Promise<Void>()
                                let cancellable = Cancellable {
                                    try await trigger.value
                                    try await clock.sleep(until: clock.now.advanced(by: duration), tolerance: .none)
                                    do {
                                        guard let newBox = throttler.load(ordering: .sequentiallyConsistent) else {
                                            fatalError("Missing box")
                                        }
                                        try folder.send(.value(newBox.value.value))
                                    }
                                    catch { fatalError("Could not send") }
                                    _ = throttler.exchange(.none, ordering: .sequentiallyConsistent)
                                }
                                _ = throttler.exchange(Box(value: (newValue, cancellable)), ordering: .sequentiallyConsistent)
                                try! trigger.succeed()
                            case (.some, false):
                                return
                            case let (.some(currentBox), true):
                                let replacement = Box<(value: Output, cancellable: Cancellable<Void>)>(
                                    value: (
                                        value: newValue,
                                        cancellable: currentBox.value.cancellable
                                    )
                                )
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
                                let trigger = await Promise<Void>()
                                let cancellable = Cancellable {
                                    try await trigger.value
                                    try await clock.sleep(until: clock.now.advanced(by: duration), tolerance: .none)
                                    do {
                                        guard let newBox = throttler.load(ordering: .sequentiallyConsistent) else {
                                            fatalError("Missing box")
                                        }
                                        try folder.send(.value(newBox.value.value))
                                    }
                                    catch { fatalError("Could not send") }
                                    _ = throttler.exchange(.none, ordering: .sequentiallyConsistent)
                                }
                                _ = throttler.exchange(Box(value: (newValue, cancellable)), ordering: .sequentiallyConsistent)
                                try! trigger.succeed()
                        }
                }

            }
        }
    }
}
