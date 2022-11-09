//: [Previous](@previous)

/*:
 ### Race Conditions
 Three requirements for a race condition:

 1. Shared, mutable state
 2. Access from multiple threads
 3. One of the threads must be a write

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
 */
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true




let t1 = Task<Int, Never> { 13 }
let t2 = Task {
    try? await Task.sleep(nanoseconds: 200_000_000)
    t1.cancel()
}
let t3 = Task {
    try await Task.sleep(nanoseconds: 100_000_000)
    if t1.isCancelled { "t3 failed"; return }
    "t3 succeeded, value = \(await t1.value)"
}
let t4 = Task {
    try await Task.sleep(nanoseconds: 300_000_000)
    if t1.isCancelled { "t4 failed"; return }
    "t4 succeeded, value = \(await t1.value)"
}

await t1.result
await t2.result
await t3.result
await t4.result






PlaygroundPage.current.finishExecution()

/*:
 [Swift Evolution Proposal 304: Structured Concurrency / Cancellation](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#cancellation-1)

 > Do note however that checking cancellation while concurrently setting cancellation may be slightly racy, i.e. if the cancel is performed from another thread, the isCancelled may not return true.

 */
/*:

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

 # Cancellation is a failure condition

 Consider the following function.  If cancelled, what should it return?  If you answer: "we should change the signature of the function", then why not make the Task it is housed in `throwing`?
 */
func collatz(_ anInt: Int) -> Void {
    guard anInt > 1 else { return }
    return anInt % 2 == 0
        ? collatz(anInt / 2)
        : collatz((3 * anInt + 1) / 2)
}
//: [Next](@next)
