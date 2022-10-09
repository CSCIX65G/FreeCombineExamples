//: [Previous](@previous)

/*:
 ### Race Conditions
 Three requirements for a race condition:

 1. Shared, mutable state
 2. Access from multiple threads
 3. One of the threads must be a write

 */
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

let t1 = Task<Int, Never> { 13 }
let t2 = Task<Void, Never> {
    try? await Task.sleep(nanoseconds: 200_000_000)
    t1.cancel()
    return
}
let t3 = Task<Void, Error> {
    try await Task.sleep(nanoseconds: 100_000_000)
    if t1.isCancelled { print("t3 failed"); return }
    let value = await t1.value
    print("t3 succeeded, value = \(value)")
}
let t4 = Task<Void, Error> {
    try await Task.sleep(nanoseconds: 300_000_000)
    if t1.isCancelled {
        print("t4 failed"); return
    }
    let value = await t1.value
    print("t4 succeeded, value = \(value)")
}

await t1.result
await t2.result
await t3.result
await t4.result

PlaygroundPage.current.finishExecution()

//: [Next](@next)
