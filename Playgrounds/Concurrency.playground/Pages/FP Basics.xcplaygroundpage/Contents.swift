//: [Previous](@previous)

/// FP Basics

func identity<T>(
    _ t: T
) -> T {
    t
}

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

func uninformativeInvoke<A, B>(
    f: @escaping (A) -> B
) -> (A) -> B {
    f /// just the identity function on f...
}

func invoke<A, B>(f: @escaping (A) -> B) -> (A) -> B {
    { value in f(value) }
}

func apply<A, B>(_ value: A) -> (@escaping (A) -> B) -> B {
    { f in f(value) }
}

func uncurriedApply<A, B>(value: A, f: @escaping (A) -> B) -> B {
    f(value)
}

/// we can make the apply function into a type by storing the value explicitly...
struct Object<A> {
    let value: A
    init(_ value: A) { self.value = value }
    func apply<B>(_ f: @escaping (A) -> B) -> B { f(value) }
}

/// we can even make the apply method on _that_ type be a type,
/// by having the method capture the value...
struct Continuation<A, B> {
    let apply: (@escaping (A) -> B) -> B
    /// init + storing the returned func = apply
//    func apply<A, B>(_ value: A) -> (@escaping (A) -> B) -> B {
//        { f in f(value) }
//    }
    init(_ value: A) { self.apply = { f in f(value) } }
    func callAsFunction(_ f: @escaping (A) -> B) -> B { apply(f) }
}


//: [Next](@next)
