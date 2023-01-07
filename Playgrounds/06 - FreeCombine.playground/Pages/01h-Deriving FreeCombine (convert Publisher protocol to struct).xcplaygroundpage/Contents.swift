//: [Previous](@previous)

import _Concurrency

enum Demand: Equatable {
    case more
    case done
}

enum Value<Supply> {
    case value(Supply)
    case failure(Swift.Error)
    case finished
}

typealias Sink<Output> = (Value<Output>) async throws -> Demand

public struct Publisher<Output> {
    let sink: (@escaping Sink<Output>) -> Task<Demand, Swift.Error>
    init(_ sink: @escaping (@escaping Sink<Output>) -> Task<Demand, Swift.Error>) {
        self.sink = sink
    }
}

public extension Publisher {
    func map<T>(_ f: @escaping (Output) async -> T) -> Publisher<T> {
        .init { (downstream: @escaping Sink<T>) -> Task<Demand, Swift.Error> in
            self.sink { (value: Value<Output>) async throws -> Demand in
                switch value {
                    case let .value(output): return try await downstream(.value(f(output)))
                    case let .failure(error): return try await downstream(.failure(error))
                    case .finished: return try await downstream(.finished)
                }
            }
        }
    }

    func flatMap<T>(_ f: @escaping (Output) async -> Publisher<T>) -> Publisher<T> {
        .init { (downstream: @escaping Sink<T>) -> Task<Demand, Swift.Error> in
            self.sink { (value: Value<Output>) async throws -> Demand in
                switch value {
                    case let .value(output): return try await f(output)(downstream).value
                    case let .failure(error): return try await downstream(.failure(error))
                    case .finished: return try await downstream(.finished)
                }
            }
        }
    }
}

extension Publisher {
    public enum Error: Swift.Error, CaseIterable, Equatable {
        case cancelled
    }
    func callAsFunction(_ downstream: @escaping Sink<Output>) -> Task<Demand, Swift.Error> {
        sink(downstream)
    }
}

extension Publisher {
    init<S: Sequence>(
        _ sequence: S
    ) where S.Element == Output {
        self = .init { downstream in
            return .init {
                guard !Task.isCancelled else { return .done }
                for a in sequence {
                    guard !Task.isCancelled else { return .done }
                    guard try await downstream(.value(a)) == .more else { return .done }
                }
                guard !Task.isCancelled else { return .done }
                return try await downstream(.finished)
            }
        }
    }
}

let publisher: Publisher<Int> = .init((0 ..< 100).shuffled()[0 ..< 50])

let t = publisher.sink { input in
    print("subscriber receiving: \(input)")
    guard case let .value(value) = input, value != 57 else {
        print("subscriber replying .done")
        return .done
    }
    if (0 ..< 4).randomElement() == 0 {
        print("waiting a bit...")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    print("subscriber replying .more")
    return .more
}
let result = await t.result
print(result)
//: [Next](@next)
