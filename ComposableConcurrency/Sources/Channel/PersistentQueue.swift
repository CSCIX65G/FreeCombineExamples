//
//  PersistentQueue.swift
//  
//
//  Created by Van Simmons on 12/31/22.
//
public struct PersistentLazyQueue<Element> {
    private let front : [Element]
    private let rear : [Element]

    public init(front: [Element] = [], rear: [Element] = []) {
        self.front = front
        self.rear = rear
    }

    public var isEmpty: Bool { front.count == 0 }
    public var head: Element? { front.first }

    public func tail() -> PersistentLazyQueue<Element> {
        check(fStream: .init(front.dropFirst()), rStream: rear)
    }

    public func snoc(_ elem: Element) -> PersistentLazyQueue<Element> {
        check(fStream: front, rStream: [elem] + rear)
    }

    public func enqueue(_ elem: Element) -> PersistentLazyQueue<Element> {
        check(fStream: front, rStream: [elem] + rear)
    }

    public func dequeue() -> (head: Element?, tail: PersistentLazyQueue<Element>) {
        (head: head, tail: tail())
    }
}

private extension PersistentLazyQueue {
    func check(
        fStream: [Element],
        rStream: [Element]
    ) -> PersistentLazyQueue<Element> {
        rStream.count <= fStream.count
        ? .init(front: fStream, rear: rStream)
        : .init(front: fStream + rStream.reversed(), rear: [])
    }
}
