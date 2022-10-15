//
//  Future+Value.swift
//  
//
//  Created by Van Simmons on 10/14/22.
//

extension Future {
    var value: Output {
        get async throws { try await futureValue.value }
    }

    var result: Result<Output, Swift.Error> {
        get async { await futureValue.result }
    }

    var futureValue: Cancellable<Output> {
        get {
            .init {
                let ref: ValueRef<Result<Output, Swift.Error>?> = .init(value: .none)
                let z: Cancellable<Void> = await self.sink { ref.set(value: $0) }
                return try await withTaskCancellationHandler(
                    operation: {
                        _ = await z.result
                        return try ref.value!.get()
                    },
                    onCancel: {  try? z.cancel() }
                )
            }
        }
    }
}
