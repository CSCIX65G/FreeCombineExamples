/*:
 ### Review Items

 1. Side-effects in Void-returning/accepting functions
 1. Type-level and Value-level functions
 1. `init`'s as static functions
 1. structuring/destructuring
 1. function invocation as single-argument functions
 1. point-free vs point-ed style
 1. Function-returning functions, aka composition
 1. flip
 1. curry
 1. compose
 1. apply
 1. Functions as Nominal types
 1. continuation-passing style vs direct style
 1. type-erasure
 1. generics as type constructors NOT as types.

 ### Observations:

 1. Just for fun: strict vs non-strict evaluation order
 1. OO

 */

func asyncCompose<A, B, C>(
    _ f: @escaping (A) async throws -> B,
    _ g: @escaping (B) async throws -> C
) -> (A) async throws -> C {
    { a in try await g(f(a)) }
}

struct AsyncFunc<A, R> {
    let call: (A) async throws -> R
    init(_ call: @escaping (A) async throws -> R) {
        self.call = call
    }
    func callAsFunction(_ a: A) async throws -> R {
        try await call(a)
    }
}

func asyncCompose<A, B, C>(
    _ f: AsyncFunc<A, B>,
    _ g: AsyncFunc<B, C>
) -> AsyncFunc<A, C> {
    .init { a in try await g(f(a)) }
}

func curriedAsyncCompose<A, B, C>(
    _ f: AsyncFunc<A, B>
) -> (AsyncFunc<B, C>) -> AsyncFunc<A, C> {
    { g in .init { a in try await g(f(a)) } }
}

extension AsyncFunc {
    func map<B>(_ f: @escaping (R) async throws -> B) -> AsyncFunc<A, B> {
        .init { a in try await f(self(a)) }
    }
}

// async func <-> Task func isomorphism
func toAsync<A, R>(
    _ f: @escaping (A) -> Task<R, Error>
) -> (A) async throws -> R {
    { a in try await f(a).value }
}

func toTask<A, R>(
    _ f: @escaping (A) async throws -> R
) -> (A) -> Task<R, Error> {
    { a in .init { try await f(a) } }
}

// Flipped toTask
func continuation<A, R>(
    _ a: A
) -> (@escaping (A) async throws -> R) -> Task<R, Error> {
    { f in .init { try await f(a) } }
}

func continuation<A, R>(
    _ ta: Task<A, Error>
) -> (@escaping (A) async throws -> R) -> Task<R, Error> {
    { f in .init { try await f(ta.value) } }
}

struct AsyncContinuation<A, R> {
    let sink: (@escaping (A) async throws -> R) -> Task<R, Error>
    init(_ a: A) {
        sink = { f in .init { try await f(a) } }
    }
    init(_ ta: Task<A, Error>) {
        sink = { f in .init { try await f(ta.value) } }
    }
    func callAsFunction(
        _ f: @escaping (A) async throws -> R
    ) -> Task<R, Error> {
        sink(f)
    }
}

struct AsyncPipe<A, R> {
    let sink: (@escaping (A) async throws -> R) async throws -> R
    init(_ a: A) {
        sink = { f in try await f(a) }
    }
    init(_ ta: Task<A, Error>) {
        sink = { f in try await f(ta.value) }
    }
    func callAsFunction(
        _ f: @escaping (A) async throws -> R
    ) async throws -> R {
        try await sink(f)
    }
}

func channel<Value>(
    _ buffering: AsyncStream<Value>.Continuation.BufferingPolicy = .bufferingOldest(1)
) -> (continuation: AsyncStream<Value>.Continuation, stream: AsyncStream<Value>) {
    var continuation: AsyncStream<Value>.Continuation!
    let stream = AsyncStream<Value>.init(bufferingPolicy: buffering) { continuation = $0 }
    return (continuation, stream)
}

enum EnqueueError<R>: Error {
    case dropped(R)
    case terminated
}

func streamedFunc<A, R>(
    _ f: @escaping (A) async throws -> R
) -> (AsyncStream<R>.Continuation) -> (A) async throws -> Void {
    { continuation in { a in switch try await continuation.yield(f(a)) {
        case .enqueued: return
        case .terminated: throw EnqueueError<R>.terminated
        case let .dropped(r): throw EnqueueError.dropped(r)
    } } }
}

struct StreamedFunc<A, R> {
    let f: (A) async throws -> R
    init(f: @escaping (A) async throws -> R) {
        self.f = f
    }
    func callAsFunction(continuation: AsyncStream<R>.Continuation, value: A) async throws -> Void {
        switch try await continuation.yield(f(value)) {
            case .enqueued: return
            case .terminated: throw EnqueueError<R>.terminated
            case let .dropped(r): throw EnqueueError.dropped(r)
        }
    }
    func callAsFunction(continuation: AsyncStream<R>.Continuation) -> (A) async throws -> Void {
        { value in try await self(continuation: continuation, value: value)}
    }
    func callAsFunction(continuation: AsyncStream<R>.Continuation) -> AsyncFunc<A, Void> {
        .init(self.callAsFunction(continuation: continuation))
    }
}

class IdentifiedStreamedFunc<A, R>: Identifiable {
    let f: (A) async throws -> R
    private(set) var id: ObjectIdentifier! = .none

    init(f: @escaping (A) async throws -> R) {
        self.f = f
        self.id = ObjectIdentifier(self)
    }

    func callAsFunction(continuation: AsyncStream<(ObjectIdentifier, R)>.Continuation, value: A) async throws -> Void {
        switch try await continuation.yield((id, f(value))) {
            case .enqueued: return
            case .terminated: throw EnqueueError<R>.terminated
            case let .dropped(r): throw EnqueueError.dropped(r)
        }
    }
    func callAsFunction(continuation: AsyncStream<(ObjectIdentifier, R)>.Continuation) -> (A) async throws -> Void {
        { value in try await self(continuation: continuation, value: value)}
    }
    func callAsFunction(continuation: AsyncStream<(ObjectIdentifier, R)>.Continuation) -> AsyncFunc<A, Void> {
        .init(self.callAsFunction(continuation: continuation))
    }
}

func reduce<State, Action>(
    stream: AsyncStream<Action>
) -> (State) -> (@escaping (State, Action) async -> State) async -> State {
    { initialState in { reducer in
        var state = initialState
        for await action in stream { state = await reducer(state, action) }
        return state
    } }
}

extension AsyncStream {
    func reduce<State>(
        initialState: State,
        reducer: @escaping (State, Element) async -> State
    ) async -> State {
        var state = initialState
        for await action in self { state = await reducer(state, action) }
        return state
    }
}
