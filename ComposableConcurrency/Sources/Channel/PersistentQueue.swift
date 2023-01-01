//
//  PersistentQueue.swift
//  
//
//  Created by Van Simmons on 12/31/22.
//
import HashTreeCollections

public struct PersistentQueue<Element> {
    let range: Range<UInt64>
    private let storage: TreeDictionary<UInt64, Element>

    private init(range: Range<UInt64>, storage: TreeDictionary<UInt64, Element>) {
        self.range = range
        self.storage = storage
    }
}

public extension PersistentQueue {
    init() { self.init(range: 0 ..< 0, storage: .init()) }
    
    var count: Int { range.count }
    var isEmpty: Bool { count == 0 }

    func enqueue(_ element: Element) -> PersistentQueue<Element> {
        var newStorage: TreeDictionary<UInt64, Element> = .init(storage)
        newStorage[range.upperBound] = element
        return .init(
            range: range.lowerBound ..< range.upperBound + 1,
            storage: newStorage
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
                range: newRange,
                storage: newStorage
            )
        )
    }

    func forEach(_ action: (Element) -> Void) -> Void {
        range.forEach { key in action(storage[key]!) }
    }
}
