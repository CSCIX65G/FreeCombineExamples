
// FP Basics
func identity<T>(_ t: T) -> T { t }

func flip<A, B, C>(
    _ f: @escaping (A, B) async -> C
) -> (B, A) async -> C {
    { b, a in await f(a, b) }
}

func curry<A, B, C>(
    _ f: @escaping (A, B) async -> C
) -> (A) -> (B) async -> C {
    { a in { b in await f(a, b) } }
}

func uncurry<A, B, C>(
    _ f: @escaping (A) -> (B) async -> C
) -> (A, B) async -> C {
    { a, b in await f(a)(b) }
}

func flip<A, B, C>(
    _ f: @escaping (A) async -> (B) async -> C
) -> (B) -> (A) async -> C {
    { b in  { a in await f(a)(b) } }
}

func compose<A, B, C>(
    _ f: @escaping (A) async -> B,
    _ g: @escaping (B) async -> C
) -> (A) async -> C {
    { a in await g(f(a)) }
}

enum MyOptional<T> {
    case some(T)
    case none
}

extension MyOptional {
    func map<U>(_ f: (T) -> U) -> MyOptional<U> {
        switch self {
            case let .some(t): return .some(f(t))
            case .none: return .none
        }
    }
    func flatMap<U>(_ f: (T) -> MyOptional<U>) -> MyOptional<U> {
        switch self {
            case let .some(t): return f(t)
            case .none: return .none
        }
    }
    func zip<U>(_ other: MyOptional<U>) -> MyOptional<(T, U)> {
        switch (self, other) {
            case let (.some(t), .some(u)): return .some((t, u))
            default: return .none
        }
    }
}

//func invoke<A, B>(
//    f: @escaping (A) -> B
//) -> (A) -> B {
//    f
//}

func invoke<A, B>(f: @escaping (A) -> B) -> (A) -> B {
    { value in f(value) }
}

func apply<A, B>(_ value: A) -> (@escaping (A) -> B) -> B {
    { f in f(value) }
}

func uncurriedApply<A, B>(value: A, f: @escaping (A) -> B) -> B {
    f(value)
}

struct Continuation<A, B> {
    let sink: (@escaping (A) -> B) -> B
//    func apply<A, B>(_ value: A) -> (@escaping (A) -> B) -> B {
//        { f in f(value) }
//    }
    init(_ value: A) {
        self.sink = { f in f(value) }
    }
    func callAsFunction(_ f: @escaping (A) -> B) -> B {
        sink(f)
    }
}

func pure<A>(_ a: A) -> Task<A, Never> {
    .init { a }
}

extension Task where Failure == Never {
    init(_ a: Success) { self = .init { a } }
}

@inlinable
func unpure<A>(_ t: Task<A, Never>) async -> A {
    await t.value
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

func join<A>(_ outer: Task<Task<A, Never>, Never>) -> Task<A, Never> {
    .init { await outer.value.value }
}

extension Task where Failure == Never {
    func join<A>() -> Task<A, Never> where Success == Task<A, Never> {
        .init { await value.value }
    }
}


func fork<A, B>(_ f: @escaping (A) async -> B) -> (A) -> Task<B, Never> {
    { a in .init { await f(a) } }
}

func rejoin<A, B>(_ f: @escaping (A) -> Task<B, Never>) -> (A) async -> B {
    { a in await f(a).value }
}

func flipFork<A, B>(_ a: A) -> (@escaping (A) async -> B) -> Task<B, Never> {
    { f in .init { await f(a) } }
}

/*:
 unpure:     Task<A> async ->   A
 flipFork:                     (A) -> ((A) async -> B) -> Task<B>
 composed:   Task<A> async -> ((A) async -> B) -> Task<B>
 composedFlipFork: Task<A> -> ((A) async -> B) -> Task<B>
 */

func composedFlipFork<A, B>(_ t: Task<A, Never>) -> (@escaping (A) async -> B) -> Task<B, Never> {
    { f in .init { await f(t.value) } }
}

func map<A, B>(_ f: @escaping (A) async -> B) -> (Task<A, Never>) -> Task<B, Never> {
    { t in .init { await f(t.value) } }
}

extension Task where Failure == Never {
    func map<B>(_ f: @escaping (Success) async -> B) -> Task<B, Never> {
        .init { await f(self.value) }
    }
}

func taskFlattener<A, B>(_ t: Task<A, Never>) -> (@escaping (A) async -> Task<B, Never>) -> Task<B, Never> {
    //    { f in .init { await f(t.value).value } }
    //    { f in join(map(f)(t)) }
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

struct AsyncContinuation<A, B> {
    let call: @Sendable (@escaping (A) async -> B) -> Task<B, Never>

    init(_ call: @escaping @Sendable (@escaping (A) async -> B) -> Task<B, Never>) {
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
typealias Uncancellable<Success> = Task<Success, Never>

extension Task where Failure == Never {
    typealias Future = AsyncContinuation<Success, Void>
    var future: Future { .init(self) }
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

