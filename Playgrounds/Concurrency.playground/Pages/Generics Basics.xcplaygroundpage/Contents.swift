//: [Previous](@previous)

enum MyOptional<T> {
    case some(T)
    case none
}

func identity<T>(_ t: T) -> T { t }
func void<T>(_ t: T) -> Void { }

func compose<A, B, C>(
    _ f: @escaping (A) -> B,
    _ g: @escaping (B) -> C
) -> (A) -> C {
    { a in g(f(a)) }
}

extension MyOptional {
    func map<U>(_ f: (T) -> U) -> MyOptional<U> {
        switch self {
            case let .some(t): return .some(f(t))
            case .none: return .none
        }
    }
    func join<U>() -> MyOptional<U> where T == MyOptional<U> {
        // flatMap(identity)
        switch self {
            case let .some(wrapped): return wrapped
            case .none: return .none
        }
    }
    func flatMap<U>(_ f: (T) -> MyOptional<U>) -> MyOptional<U> {
        // map(f).join()
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

struct Object<T> {
    let value: T
    init(_ value: T) { self.value = value }
    func get() -> T { value }
    func apply<U>(_ f: (T) -> U) -> U { f(value) }
}

extension Object {
    func map<U>(_ f: (T) -> U) -> Object<U> {
//        .init(f(value))
        // (Object<T>) -> T                                     unpure(Object<T>)
        //               (T) -> ((T) -> U) -> U                 apply(f)
        //                                   (U) -> Object<U>   pure(u)
        .init(apply(f))
    }

    // Object<Object<U>> -> Object<U>
    func join<U>() -> Object<U> where T == Object<U> {
        .init(self.value.value)
    }

    func flatMap<U>(_ f: (T) -> Object<U>) -> Object<U> {
        // map(f).join()
        f(value)
    }
    
    func zip<U>(_ other: Object<U>) -> Object<(T, U)> {
        .init((value, other.value))
    }
}

struct Func<A, B> {
    let call: (A) -> B
    init(_ call: @escaping (A) -> B) { self.call = call }
}

extension Func {
    func map<C>(_ f: @escaping (B) -> C) -> Func<A, C> {
        .init(compose(call, f))
    }

    func join<C>() -> Func<A, C> where B == Func<A, C> {
        .init { a in self.call(a).call(a) }
    }

    func flatMap<C>(_ f: @escaping (A) -> Func<A, C>) -> Func<A, C> {
        .init { a in f(a).call(a) }
    }

    func zip<C>(_ other: Func<A, C>) -> Func<A, (B, C)> {
        .init { a in (self.call(a), other.call(a)) }
    }
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
