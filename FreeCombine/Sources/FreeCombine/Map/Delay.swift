//
//  Delay.swift
//  
//
//  Created by Van Simmons on 9/18/22.
//
extension Future {
    func delay(
        _ duration: Duration
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                try? await Task.sleep(nanoseconds: duration.inNanoseconds)
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


