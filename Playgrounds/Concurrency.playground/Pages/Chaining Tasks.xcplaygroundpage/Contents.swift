//: [Previous](@previous)
import _Concurrency

func identity<T>(_ t: T) -> T { t }
func compose<A, B, C>(
    _ f: @escaping (A) async -> B,
    _ g: @escaping (B) async -> C
) -> (A) async -> C {
    { a in await g(f(a)) }
}

struct AsyncContinuation<A, B> {
    let call: @Sendable (@escaping (A) async -> B) -> Task<B, Never>

    init(_ call: @Sendable @escaping (@escaping (A) async -> B) -> Task<B, Never>) {
        self.call = call
    }

    //func flipFork<A, B>(_ a: A) -> (@escaping (A) async -> B) -> Task<B, Never> {
    //    { f in .init { await f(a) } }
    //}
    init(_ a: A) {
        call = { f in .init { await f(a) } }
    }

    //    func composedFlipFork<A, B>(_ t: Task<A, Never>) -> (@escaping (A) async -> B) -> Task<B, Never> {
    //        { f in .init { await f(t.value) } }
    //    }
    init(_ t: Task<A, Never>) {
        call = { f in .init { await f(t.value) } }
    }
}

extension Task where Failure == Never {
    typealias Continuation = AsyncContinuation<Success, Void>
    var continuation: Continuation { .init(self) }
}

extension AsyncContinuation {
    func callAsFunction(_ downstream: @escaping (A) async -> B) -> Task<B, Never> {
        call(downstream)
    }

    func map<C>(f: @escaping (A) async -> C) -> AsyncContinuation<C, B> {
        .init { downstream in
            // downstream: (C) -> B
            // f:          (A) -> C
            // self.call:  ((A) -> B) -> Task<B>
            // self.call { a in await downstream(f(a)) }
            // self.call(compose(f, downstream))
            self(compose(f, downstream))
        }
    }

    func flatMap<C>(_ f: @escaping (A) async -> AsyncContinuation<C, B>) -> AsyncContinuation<C, B> {
        .init { downstream in
            // downstream: (C) -> B
            // f:          (A) -> AsyncContinuation<C, B>
            // self.call:  ((A) -> B) -> Task<B>
            // self.call { a in await f(a).call(downstream).value }
            self { a in await f(a)(downstream).value }
        }
    }

    func join<C>() -> AsyncContinuation<C, B> where A == AsyncContinuation<C, B> {
        flatMap(identity)
    }
}

func flatMap<A, B, C>(
    _ me: AsyncContinuation<A, B>
) -> (@escaping (A) async -> AsyncContinuation<C, B>) -> AsyncContinuation<C, B> {
    { f in .init { downstream in me { a in await f(a)(downstream).value } } }
}

func join<A, B>(_ outer: AsyncContinuation<AsyncContinuation<A, B>, B>) -> AsyncContinuation<A, B> {
    flatMap(outer)(identity)
}

print("Compiled 'Chaining Tasks' and ran")

//: [Next](@next)
