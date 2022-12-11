//
//  File.swift
//  
//
//  Created by Van Simmons on 12/10/22.
//

public extension Cancellable {
    func join<T>() -> Cancellable<T> where Output == Cancellable<T> {
        .init {
            let inner = try await self.value
            guard !Cancellables.isCancelled else {
                try? inner.cancel()
                throw CancellationError()
            }
            let value = try await withTaskCancellationHandler(
                operation: {try await inner.value },
                onCancel: {
                    try? inner.cancel()
                }
            )

            return value
        }
    }
}

extension Uncancellable {
    public func join<T>() -> Uncancellable<T> where Output == Uncancellable<T> {
        .init { await self.value.value }
    }
}
