//
//  AsyncFolder+Effect.swift
//  
//
//  Created by Van Simmons on 9/26/22.
//

extension AsyncFolder {
    public enum Effect {
        case none  // Multiply by 1
        case completion(Completion) // Multiply by 0
        case emit((State) async throws -> Void)
        case publish((Channel<Action>) -> Void)
    }
}
