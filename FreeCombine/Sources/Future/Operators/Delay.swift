//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//
import Core

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
