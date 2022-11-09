//: [Previous](@previous)
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

var localContinuation: AsyncStream<Int>.Continuation!
let stream = AsyncStream<Int>.init(bufferingPolicy: .unbounded) { localContinuation = $0 }
(0 ..< 10).forEach { i in localContinuation.yield(i) }

let t1: Task<Void, Error> = .init {
    try? await Task.sleep(nanoseconds: 100_000_000_000)
    for try await element in stream {
        let _: Void = try await withUnsafeThrowingContinuation { continuation in
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                continuation.resume()
            }
        }
        print("\(element) and cancellation is: \(Task.isCancelled)")
    }
    print("I finished")
}

t1.cancel()
_ = await t1.result

PlaygroundPage.current.finishExecution()

//: [Next](@next)
