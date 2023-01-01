//
//  PersistentQueue.swift
//  
//
//  Created by Van Simmons on 12/31/22.
//
import HashTreeCollections

public enum Buffering {
    case newest(Int)
    case oldest(Int)
    case unbounded
}

public struct PersistentQueue<Element> {
    let buffering: Buffering
    let range: Range<UInt64>
    private let storage: TreeDictionary<UInt64, Element>

    private init(
        buffering: Buffering = .unbounded,
        range: Range<UInt64>,
        storage: TreeDictionary<UInt64, Element>
    ) {
        self.buffering = buffering
        self.range = range
        self.storage = storage
    }
}

public extension PersistentQueue {
    init(buffering: Buffering = .unbounded) {
        self.init(
            buffering: buffering,
            range: 0 ..< 0,
            storage: .init()
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
                if newStorage.count > bound {
                    dropped = newStorage[newRange.lowerBound]
                    newStorage[newRange.lowerBound] = .none
                    newRange = newRange.lowerBound + 1 ..< newRange.upperBound
                }
            case let .oldest(bound):
                if newStorage.count > bound {
                    dropped = newStorage[newRange.upperBound]
                    newStorage[newRange.upperBound] = .none
                    newRange = newRange.lowerBound ..< newRange.upperBound - 1
                }
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
        newStorage[range.lowerBound] = nil

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
