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

//template<typename T>
//class mpmc_bounded_queue
//{
//public:
//  mpmc_bounded_queue(size_t buffer_size)
//    : buffer_(new cell_t [buffer_size])
//    , buffer_mask_(buffer_size - 1)
//  {
//    assert((buffer_size >= 2) &&
//      ((buffer_size & (buffer_size - 1)) == 0));
//    for (size_t i = 0; i != buffer_size; i += 1)
//      buffer_[i].sequence_.store(i, std::memory_order_relaxed);
//    enqueue_pos_.store(0, std::memory_order_relaxed);
//    dequeue_pos_.store(0, std::memory_order_relaxed);
//  }
//  ~mpmc_bounded_queue()
//  {
//    delete [] buffer_;
//  }
//  bool enqueue(T const& data)
//  {
//    cell_t* cell;
//    size_t pos = enqueue_pos_.load(std::memory_order_relaxed);
//    for (;;)
//    {
//      cell = &buffer_[pos & buffer_mask_];
//      size_t seq =
//        cell->sequence_.load(std::memory_order_acquire);
//      intptr_t dif = (intptr_t)seq - (intptr_t)pos;
//      if (dif == 0)
//      {
//        if (enqueue_pos_.compare_exchange_weak
//            (pos, pos + 1, std::memory_order_relaxed))
//          break;
//      }
//      else if (dif < 0)
//        return false;
//      else
//        pos = enqueue_pos_.load(std::memory_order_relaxed);
//    }
//    cell->data_ = data;
//    cell->sequence_.store(pos + 1, std::memory_order_release);
//    return true;
//  }
//  bool dequeue(T& data)
//  {
//    cell_t* cell;
//    size_t pos = dequeue_pos_.load(std::memory_order_relaxed);
//    for (;;)
//    {
//      cell = &buffer_[pos & buffer_mask_];
//      size_t seq =
//        cell->sequence_.load(std::memory_order_acquire);
//      intptr_t dif = (intptr_t)seq - (intptr_t)(pos + 1);
//      if (dif == 0)
//      {
//        if (dequeue_pos_.compare_exchange_weak
//            (pos, pos + 1, std::memory_order_relaxed))
//          break;
//      }
//      else if (dif < 0)
//        return false;
//      else
//        pos = dequeue_pos_.load(std::memory_order_relaxed);
//    }
//    data = cell->data_;
//    cell->sequence_.store
//      (pos + buffer_mask_ + 1, std::memory_order_release);
//    return true;
//  }
//private:
//  struct cell_t
//  {
//    std::atomic<size_t>   sequence_;
//    T                     data_;
//  };
//  static size_t const     cacheline_size = 64;
//  typedef char            cacheline_pad_t [cacheline_size];
//  cacheline_pad_t         pad0_;
//  cell_t* const           buffer_;
//  size_t const            buffer_mask_;
//  cacheline_pad_t         pad1_;
//  std::atomic<size_t>     enqueue_pos_;
//  cacheline_pad_t         pad2_;
//  std::atomic<size_t>     dequeue_pos_;
//  cacheline_pad_t         pad3_;
//  mpmc_bounded_queue(mpmc_bounded_queue const&);
//  void operator = (mpmc_bounded_queue const&);
//};
