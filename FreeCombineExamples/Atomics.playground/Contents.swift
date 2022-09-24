import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

import FreeCombine

let promise: Promise<Int> = await .init()
let c: Cancellable<Void> = .init(operation: {
    do { try promise.succeed(13) }
    catch { print("Could not complete") }
})
let promiseResult = await promise.result
switch promiseResult {
    case .success(let value):
        assert(value == 13, "Got the wrong value")
    case .failure(let error):
        assertionFailure("Got an error: \(error)")
}
print(promiseResult)
_ = await c.result

PlaygroundPage.current.finishExecution()
