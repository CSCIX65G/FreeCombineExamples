//
//  IdentifiedStreamedFunc.swift
//  
//
//  Created by Van Simmons on 11/25/22.
//
class IdentifiedAsyncFunc<A, R>: Identifiable {
    let f: (A) async throws -> R
    private(set) var id: ObjectIdentifier! = .none

    init(f: @escaping (A) async throws -> R) {
        self.f = f
        self.id = ObjectIdentifier(self)
    }
}
