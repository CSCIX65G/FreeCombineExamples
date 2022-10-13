//: [Previous](@previous)

/*:
 # Challenge:

 Write a function with the following signature:
 ```
 func process<Output>(
     timeout: UInt64,
     _ process: @escaping () async -> Output
 ) -> Task<Output, Swift.Error>
 ```
 where:

 1. If `process` completes before `timeout`, the task returns `process`'s Output
 1. If `timeout` completes before `process`, the task returns TimeoutError
 1. If the task is cancelled before either `process` or `timeout` completes, it returns CancellationError
 1. The returned task does _not_ wait on either cancelled subtasks to complete
 1. These should go without saying, but...
     * No race conditions
     * No undefined behavior
     * No leaks

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 [Swift Evolution Proposal 304: Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md)

 ### The primary rule of structured concurrency: a child task cannot live longer than the parent task in which it was created

 [Unstructured Tasks](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#unstructured-tasks)

     So far all types of tasks we discussed were child-tasks and respected the primary rule of structured concurrency: that a child task cannot live longer than the parent task (or scope) in which it was created. This is both true for task groups as well as SE-0317 async let.

     Sometimes however, these rigid rules end up being too restrictive. We might need to create new tasks whose lifetime is not bound to the creating task, for example in order to fire-and-forget some operation or to initiate asynchronous work from synchronous code. Unstructured tasks are not able to utilize some of the optimization techniques wrt. allocation and metadata propagation as child-tasks are, however they remain a very important building block especially for more free-form usages and integration with legacy APIs.

 Structured concurrency as of today means: TaskGroup, `async let` and actors. We don't expect to be able to use them for the function above for exactly the reasons mentioned in SE-304, i.e. #4 above violates "the primary rule".

 Structured concurrency doesn't make sense in (at least) the following circumstances:

 1. Tasks which allow cancellation of individual child tasks
 1. Tasks created from synchronous context
 1. Tasks which can be resumed from synchronous context
 1. Tasks iterating over data from synchronous context
 1. Tasks of signature: `Task<Task<Output, _>, _>` (i.e. tasks which are flatMapped or joined)
 1. Task "trees" (require flatMap)
 1. Situations where you already know the result of a task, including but not limited to:
    * Tasks of signature: `Task<Void, Never>` (side effects)
    * Tasks of signature: `Task<Never, Never>` (server processes and apps)

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;

 &nbsp;
 ![Structured Concurrency covers very few of my uses cases](Jedi.png)
 */

//: [Next](@next)
