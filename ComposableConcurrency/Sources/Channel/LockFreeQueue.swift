//
//  LockFreeQueue.swift
//  
//
//  Created by Van Simmons on 12/5/22.
//
//  Borrowed from swift-atomics
//
import Atomics

private let nodeCount = ManagedAtomic<Int>(0)

public class LockFreeQueue<Element> {
    final class Node: AtomicReference {
        let next: ManagedAtomic<Node?>
        var value: Element?

        init(value: Element?, next: Node?) {
            self.value = value
            self.next = ManagedAtomic(next)
            nodeCount.wrappingIncrement(ordering: .relaxed)
        }

        deinit {
            var values = 0
            // Prevent stack overflow when reclaiming a long queue
            var node = self.next.exchange(nil, ordering: .relaxed)
            while node != nil && isKnownUniquelyReferenced(&node) {
                let next = node!.next.exchange(nil, ordering: .relaxed)
                withExtendedLifetime(node) {
                    values += 1
                }
                node = next
            }
            if values > 0 {
                print(values)
            }
            nodeCount.wrappingDecrement(ordering: .relaxed)
        }
    }

    let head: ManagedAtomic<Node>
    let tail: ManagedAtomic<Node>

    // Used to distinguish removed nodes from active nodes with a nil `next`.
    let marker = Node(value: nil, next: nil)

    public init() {
        let dummy = Node(value: nil, next: nil)
        self.head = ManagedAtomic(dummy)
        self.tail = ManagedAtomic(dummy)
    }

    public func enqueue(_ newValue: Element) {
        let new = Node(value: newValue, next: nil)

        var tail = self.tail.load(ordering: .acquiring)
        while true {
            let next = tail.next.load(ordering: .acquiring)
            if tail === marker || next === marker {
                // The node we loaded has been unlinked by a dequeue on another thread.
                // Try again.
                tail = self.tail.load(ordering: .acquiring)
                continue
            }
            if let next = next {
                // Assist competing threads by nudging `self.tail` forward a step.
                let (exchanged, original) = self.tail.compareExchange(
                    expected: tail,
                    desired: next,
                    ordering: .acquiringAndReleasing
                )
                tail = (exchanged ? next : original)
                continue
            }
            let (exchanged, current) = tail.next.compareExchange(
                expected: nil,
                desired: new,
                ordering: .acquiringAndReleasing
            )
            if exchanged {
                _ = self.tail.compareExchange(expected: tail, desired: new, ordering: .releasing)
                return
            }
            tail = current!
        }
    }

    public func dequeue() -> Element? {
        while true {
            let head = self.head.load(ordering: .acquiring)
            let next = head.next.load(ordering: .acquiring)
            if next === marker { continue }
            guard let n = next else { return nil }
            let tail = self.tail.load(ordering: .acquiring)
            if head === tail {
                // Nudge `tail` forward a step to make sure it doesn't fall off the
                // list when we unlink this node.
                _ = self.tail.compareExchange(expected: tail, desired: n, ordering: .acquiringAndReleasing)
            }
            if self.head.compareExchange(expected: head, desired: n, ordering: .releasing).exchanged {
                let result = n.value!
                n.value = nil
                // To prevent threads that are suspended in `enqueue`/`dequeue` from
                // holding onto arbitrarily long chains of removed nodes, we unlink
                // removed nodes by replacing their `next` value with the special
                // `marker`.
                head.next.store(marker, ordering: .releasing)
                return result
            }
        }
    }
}
