//
//  Delay.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
extension Future {
    func delay<C: Clock>(
        clock: C,
        duration: Swift.Duration
    ) -> Self where C.Duration == Swift.Duration {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                try? await clock.sleep(until: clock.now.advanced(by: duration), tolerance: .none)
                return await downstream(r)
            }
        }
    }
}

public extension AsyncContinuation {
    func delay(
        _ nanoseconds: UInt64
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                try? await Task.sleep(nanoseconds: nanoseconds)
                return try await downstream(r)
            }
        }
    }
}


