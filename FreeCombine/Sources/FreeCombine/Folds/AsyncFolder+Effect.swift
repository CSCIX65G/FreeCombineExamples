//
//  AsyncFolder+Effect.swift
//  
//
//  Created by Van Simmons on 9/26/22.
//
public func +<State, Action>(
    _ left: AsyncFolder<State, Action>.Effect,
    _ right: AsyncFolder<State, Action>.Effect
) -> AsyncFolder<State, Action>.Effect {
    left.append(right)
}

extension AsyncFolder {
    public enum Effect: Sequence {
        case none  // Multiply by 1
        case completion(Completion) // Multiply by 0
        indirect case effects(Effect, Effect)
        case emit((State) async throws -> Void)
        case publish((Channel<Action>) -> Void)

        public func makeIterator() -> Iterator {
            .init(effect: self)
        }

        public struct Iterator: IteratorProtocol {
            public typealias Element = Effect
            private var first: Effect?
            private var second: Effect? = nil
            init(effect: Effect) {
                switch effect {
                    case let .effects(left, right):
                        first = left
                        second = right
                    default:
                        first = effect
                        second = Effect?.none
                }
            }
            public mutating func next() -> Element? {
                let retVal = first
                switch second {
                    case let .effects(left, right):
                        first = left
                        second = right
                    default:
                        first = second
                        second = Effect?.none
                }
                return retVal
            }
        }

        public func append(_ other: Effect) -> Effect {
            switch (self, other) {
                case (.completion, _), (.effects(_, .completion), _), (_, .none):
                    return self
                case (.none, _):
                    return other
                case let (.effects(left, right), _):
                    return .effects(left, .effects(right, other))
                default:
                    return .effects(self, other)
            }
        }
    }
}
