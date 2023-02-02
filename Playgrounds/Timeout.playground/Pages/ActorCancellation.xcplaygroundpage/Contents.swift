//: [Previous](@previous)

import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

actor RandomIntegerGenerator {
    func generate() -> Int {
        let clock = ContinuousClock()
        let start = clock.now
        while true {
            let i = Int.random(in: 0 ..< 1_000_000_000)
            if clock.now - start > .seconds(10.0) { return i }
        }
    }
}

await Task {
    let generator = RandomIntegerGenerator()

    let t1: Task<Void, Error> = .init {
        let clock = ContinuousClock()
        let start = clock.now
        let i = await generator.generate()
        let end = clock.now
        print("I finished in \(end - start) seconds and got value \(i)")
    }

    t1.cancel()
    _ = await t1.result
}.result

PlaygroundPage.current.finishExecution()
//: [Next](@next)
