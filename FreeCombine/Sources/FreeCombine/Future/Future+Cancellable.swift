//
//  Future+Cancellable.swift
//  
//
//  Created by Van Simmons on 10/8/22.
//

public extension Cancellable {
    var future: Future<Output> {
        .init { resumption, downstream in
            .init {
                resumption.resume()
                await downstream(self.result)
            }
        }
    }
}
