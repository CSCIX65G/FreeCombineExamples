//: [Previous](@previous)
let t1 = Task<Void, Error> {
    do {
        print("starting await")
        try await Task.sleep(nanoseconds: 100_000_000_000)
        print("Hey I woke up")
    }
    catch {
        print("await was cancelled")
    }
}
t1.cancel()
_ = await t1.result
print("I did the cancel")

let t2 = Task<Void, Error> {
    do {
        print("starting await 2")
        let _: Void = try await withUnsafeThrowingContinuation { continuation in
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000_000)
                continuation.resume()
            }
        }
        print("Hey I woke up 2")
    }
    catch {
        print("await was cancelled 2")
    }
}
t2.cancel()
_ = await t2.result
print("I did the cancel 2")

//: [Next](@next)
