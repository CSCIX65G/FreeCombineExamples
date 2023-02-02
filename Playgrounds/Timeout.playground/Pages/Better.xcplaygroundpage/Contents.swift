//: [Previous](@previous)

import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true





let t1 = Task<Int, Error> {
    try Task.checkCancellation()
    return 13
}
let t2 = Task<Void, Never> {
    try? await Task.sleep(nanoseconds: 200_000_000)
    t1.cancel()
    /// try? await t1.result.get()
    return
}
let t3 = Task<Void, Error> {
    try await Task.sleep(nanoseconds: 100_000_000)
    guard let value = try? await t1.result.get() else {
        "t3 failed"; return
    }
    "t3 succeeded, value = \(value)"
}
let t4 = Task<Void, Error> {
    try await Task.sleep(nanoseconds: 300_000_000)
    guard let value = try? await t1.result.get() else {
        "t4 failed"; return
    }
    "t4 succeeded, value = \(value)"
}

await t1.result
await t2.result
await t3.result
await t4.result

PlaygroundPage.current.finishExecution()



/*:
 # Cancellation must be a _failable_ and _atomic_ operation
*/
//: [Next](@next)
