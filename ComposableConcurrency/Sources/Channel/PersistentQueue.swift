//
//  PersistentQueue.swift
//  
//
//  Created by Van Simmons on 12/31/22.
//
import HashTreeCollections

public enum PersistentQueues {
    public enum Buffering {
        case newest(Int)
        case oldest(Int)
        case unbounded
    }
}

public struct PersistentQueue<Element> {
    let buffering: PersistentQueues.Buffering
    let range: Range<UInt64>
    private let storage: TreeDictionary<UInt64, Element>

    private init(
        buffering: PersistentQueues.Buffering = .unbounded,
        range: Range<UInt64>,
        storage: TreeDictionary<UInt64, Element>
    ) {
        self.buffering = buffering
        self.range = range
        self.storage = storage
    }
}

public extension PersistentQueue {
    init(buffering: PersistentQueues.Buffering = .unbounded) {
        self.init(
            buffering: buffering,
            range: 0 ..< 0,
            storage: .init()
        )
    }

    init(
        buffering: PersistentQueues.Buffering = .unbounded,
        _ value: Element
    ) {
        self.init(
            buffering: buffering,
            range: 0 ..< 1,
            storage: .init(dictionaryLiteral: (UInt64(0), value))
        )
    }


    init<S: Sequence>(
        buffering: PersistentQueues.Buffering = .unbounded,
        _ initialValues: S
    ) where S.Element == Element {
        var backingStore: TreeDictionary<UInt64, Element> = .init()
        var range = UInt64.zero ..< .zero
        for value in initialValues {
            switch buffering {
                case let .newest(bound) where backingStore.count >= bound:
                    backingStore[range.lowerBound] = .none
                    backingStore[range.upperBound] = value
                    range = range.lowerBound + 1 ..< range.upperBound + 1
                case let .oldest(bound) where backingStore.count >= bound:
                    ()
                default:
                    backingStore[range.upperBound] = value
                    range = range.lowerBound ..< range.upperBound + 1
            }
        }
        self.init(
            buffering: buffering,
            range: range,
            storage: backingStore
        )
    }

    init<S: RandomAccessCollection>(
        buffering: PersistentQueues.Buffering = .unbounded,
        _ initialValues: S
    ) where S.Element == Element {
        var keysAndValues: [(UInt64, Element)]!
        var size = initialValues.count
        switch buffering {
            case .unbounded:
                keysAndValues = (0 ..< initialValues.count).map { (UInt64($0), initialValues[_offset: $0]) }
            case let .newest(bound):
                size = bound
                keysAndValues = (0 ..< bound).map { (UInt64($0), initialValues[_offset: initialValues.count - bound + $0]) }
            case let .oldest(bound):
                size = bound
                keysAndValues = (0 ..< bound).map { (UInt64($0), initialValues[_offset: $0]) }
        }
        self.init(
            buffering: buffering,
            range: 0 ..< UInt64(size),
            storage: .init(uniqueKeysWithValues: keysAndValues)
        )
    }

    var count: Int { range.count }
    var isEmpty: Bool { count == 0 }

    func enqueue(_ element: Element) -> (dropped: Element?, tail: PersistentQueue<Element>) {
        var dropped: Element? = .none
        var newRange = range
        var newStorage: TreeDictionary<UInt64, Element> = .init(storage)
        newStorage[range.upperBound] = element
        switch buffering {
            case .unbounded:
                break
            case let .newest(bound):
                guard newStorage.count > bound else { break }
                dropped = newStorage[newRange.lowerBound]
                newStorage[newRange.lowerBound] = .none
                newRange = newRange.lowerBound + 1 ..< newRange.upperBound
            case let .oldest(bound):
                guard newStorage.count > bound else { break }
                dropped = newStorage[newRange.upperBound]
                newStorage[newRange.upperBound] = .none
                newRange = newRange.lowerBound ..< newRange.upperBound - 1
        }
        return (
            dropped: dropped,
            tail: .init(
                buffering: buffering,
                range: newRange.lowerBound ..< newRange.upperBound + 1,
                storage: newStorage
            )
        )
    }

    func dequeue() -> (head: Element?, tail: PersistentQueue<Element>) {
        guard let head = self.storage[range.lowerBound] else {
            return (head: .none, tail: self)
        }

        var newStorage: TreeDictionary<UInt64, Element> = .init(storage)
        newStorage[range.lowerBound] = .none

        let newRange: Range<UInt64> = count == 1 ? 0 ..< 0 : range.lowerBound + 1 ..< range.upperBound

        return (
            head: head,
            tail: .init(
                buffering: buffering,
                range: newRange,
                storage: newStorage
            )
        )
    }

    func forEach(_ action: (Element) -> Void) -> Void {
        range.forEach { key in action(storage[key]!) }
    }
}
