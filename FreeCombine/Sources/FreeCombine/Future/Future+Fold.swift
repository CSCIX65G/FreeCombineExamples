//
//  Future+Fold.swift
//  
//
//  Created by Van Simmons on 9/13/22.
//

public extension Future {
    func fold<Other>(
        futures: [Future<Other>],
        with combiningFunction: @escaping @Sendable (Output, Other) -> Self
    ) -> Self {
        var this = self
        for future in futures {
            this = zip(this, future).flatMap(combiningFunction)
        }
        return this
    }
}
