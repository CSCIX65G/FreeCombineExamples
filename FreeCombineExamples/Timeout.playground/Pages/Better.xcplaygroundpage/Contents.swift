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
    return
}
let t3 = Task<Void, Error> {
    try await Task.sleep(nanoseconds: 100_000_000)
    guard let value = try? await t1.result.get() else {
        print("t3 failed"); return
    }
    print("t3 succeeded, value = \(value)")
}
let t4 = Task<Void, Error> {
    try await Task.sleep(nanoseconds: 300_000_000)
    guard let value = try? await t1.result.get() else {
        print("t4 failed"); return
    }
    print("t4 succeeded, value = \(value)")
}

await t1.result
await t2.result
await t3.result
await t4.result

PlaygroundPage.current.finishExecution()

/*:
 # Cancellation is a failure condition

 Consider the following function.  If cancelled, what should it return.  If you answer we should change the signature of the function, then why not make the Task it is housed in `throwing`?
 */
func collatz(_ anInt: Int) -> Void {
    guard anInt > 1 else { return }
    return anInt % 2 == 0 ? collatz(anInt / 2) : collatz((3 * anInt + 1) / 2)
}
//: [Next](@next)
