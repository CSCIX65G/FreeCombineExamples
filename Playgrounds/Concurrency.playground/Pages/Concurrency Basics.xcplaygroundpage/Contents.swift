//: [Previous](@previous)
func pure<A>(_ a: A) -> Task<A, Never> {
    .init { a }
}

// pure == Task.init
extension Task where Failure == Never {
    init(_ a: Success) { self = .init { a } }
}

@available(macOS 13, iOS 16, watchOS 9, tvOS 16, *)
func unpure<A>(_ t: Task<A, Never>) async -> A {
    await t.value
}

extension Task where Failure == Never {
    func get() async -> Success { await value }
}

//func join<A>(_ outer: Task<Task<A, Never>, Never>) async -> Task<A, Never> {
//    await outer.value
//}
//
//extension Task where Failure == Never {
//    func join<A>() async -> Task<A, Never> where Success == Task<A, Never> {
//        await value
//    }
//}

func unpureUnpure<A>(_ outer: Task<Task<A, Never>, Never>) async -> A {
    await outer.value.value
}

func forked<A, B>(_ f: @escaping (A) async -> B) -> (A) -> Task<B, Never> {
    { a in .init { await f(a) } }
}

func rejoined<A, B>(_ f: @escaping (A) -> Task<B, Never>) -> (A) async -> B {
    { a in await f(a).value }
}

// join = compose(unpureUnpure, pure)
func join<A>(_ outer: Task<Task<A, Never>, Never>) -> Task<A, Never> {
    .init { await outer.value.value }
}

extension Task where Failure == Never {
    func join<A>() -> Task<A, Never> where Success == Task<A, Never> {
        .init { await value.value }
    }
}

func awaitFireAndForget<A>(
    _ f: @escaping (A) async -> Void
) async -> UnsafeContinuation<A, Swift.Error> {
    await withUnsafeContinuation { outer in
        Task { try await f(withUnsafeThrowingContinuation(outer.resume)) }
    }
}

func promise<A, B>(
    _ f: @escaping (A) async throws -> B
) async -> (UnsafeContinuation<A, Swift.Error>, Task<B, Swift.Error>) {
    var localTask: Task<B, Swift.Error>!
    return (
        await withUnsafeContinuation { outer in
            localTask = Task<B, Swift.Error> {  try await f(withUnsafeThrowingContinuation(outer.resume)) }
        },
        localTask
    )
}

func promise<A>() async -> (UnsafeContinuation<A, Swift.Error>, Task<A, Swift.Error>) {
    var localTask: Task<A, Swift.Error>!
    return (
        await withUnsafeContinuation { outer in
            localTask = Task<A, Swift.Error> {  try await withUnsafeThrowingContinuation(outer.resume) }
        },
        localTask
    )
}

func awaitFireAndForget<A>(
    _ f: @escaping (A) async -> Void
) -> Task<UnsafeContinuation<A, Swift.Error>, Never> {
    .init {
        await withUnsafeContinuation { outer in
            Task<Void, Swift.Error> {
                try await f(withUnsafeThrowingContinuation(outer.resume))
            }
        }
    }
}

func awaitFireAndForget<A>() -> Task<UnsafeContinuation<A, Swift.Error>, Never> {
    .init {
        await withUnsafeContinuation { outer in
            Task<Void, Swift.Error> {
                _ = try await withUnsafeThrowingContinuation(outer.resume)
            }
        }
    }
}

func promise<A, B>(
    _ f: @escaping (A) async throws -> B
) -> Task<(UnsafeContinuation<A, Swift.Error>, Task<B, Swift.Error>) , Never> {
    .init {
        var localTask: Task<B, Swift.Error>! = .none
        let resumption = await withUnsafeContinuation { outer in
            localTask = Task<B, Swift.Error> {
                try await f(withUnsafeThrowingContinuation(outer.resume))
            }
        }
        return (resumption, localTask)
    }
}

func promise<A>() -> Task<(UnsafeContinuation<A, Swift.Error>, Task<A, Swift.Error>) , Never> {
    .init {
        var localTask: Task<A, Swift.Error>! = .none
        let resumption = await withUnsafeContinuation { outer in
            localTask = Task<A, Swift.Error> {
                try await withUnsafeThrowingContinuation(outer.resume)
            }
        }
        return (resumption, localTask)
    }
}


func flipForked<A, B>(_ a: A) -> (@escaping (A) async -> B) -> Task<B, Never> {
    { f in .init { await f(a) } }
}

/*:
 unpure:     Task<A> async ->   A
 flipFork:                     (A) -> ((A) async -> B) -> Task<B>
 composed:   Task<A> async -> ((A) async -> B) -> Task<B>
 composedFlipFork: Task<A> -> ((A) async -> B) -> Task<B>
 */

func composedFlipForked<A, B>(_ t: Task<A, Never>) -> (@escaping (A) async -> B) -> Task<B, Never> {
    { f in .init { await f(t.value) } }
}

extension Task where Failure == Never {
    func map<B>(_ f: @escaping (Success) async -> B) -> Task<B, Never> {
        .init { await f(self.value) }
    }
}

func flatMap<A, B>(_ t: Task<A, Never>) -> (@escaping (A) async -> Task<B, Never>) -> Task<B, Never> {
    //    { f in .init { await f(t.value).value } }
    //    { f in .init { await map(f)(t).value.value } }
    //    { f in .init { await t.map(f).value.value } }
    //    { f in join(map(f)(t)) }
    //    { f in join(t.map(f)) }
    { f in t.map(f).join() }
}

func flatMap<A, B>(_ f: @escaping (A) async -> Task<B, Never>) -> (Task<A, Never>) -> Task<B, Never> {
    //    { f in .init { await f(t.value).value } }
    //    { f in join(map(f)(t)) }
    { t in t.map(f).join() }
}

extension Task where Failure == Never {
    func flatMap<B>(_ f: @escaping (Success) async -> Task<B, Never>) -> Task<B, Never> {
        //        .init { await f(self.value).value }
        //        Playground.join(Playground.map(f)(self))
        map(f).join()
    }
}

//func flipFork<A, B>(_ a: A) -> (@escaping (A) async -> B) -> Task<B, Never> {
//    { f in .init { await f(a) } }
//}

print("Compiled 'Concurrency Basics' and ran")

//: [Next](@next)

