//: [Previous](@previous)

/*:
 # Challenge:

 Write a function with the following signature:
 ```
 func debounce<Output>(
     interval: UInt64,
     stream: AsyncStream<Output>,
     _ downstream: @Sendable @escaping (Output) async throws -> Void
 ) -> Task<Output, Swift.Error>
 ```
 where:

 1. If `process` completes before `timeout`, and before a cancel, the task returns `process`'s Output
 1. If `timeout` completes before `process`, and before a cancel, the task returns TimeoutError
 1. If the task is cancelled before either `process` or `timeout` completes, it returns CancellationError
 1. The returned task does _not_ wait on either cancelled subtasks to complete
 1. These should go without saying, but...
     * No race conditions
     * No undefined behavior
     * No leaks

*/

//: [Next](@next)
