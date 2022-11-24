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




