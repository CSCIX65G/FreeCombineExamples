//: [Previous](@previous)

/// FP Basics
func void0() -> Void { }
func void1<T>(_ t: T) -> Void { }

// 1. There are 256^256 (2^2048) ways of writing the following function
func transform0(_ byte: UInt8) -> UInt8 {
    byte
}

func transform1(_ byte: UInt8) -> UInt8 {
    switch byte {
        case 0x47: return 0x48
        case 0x48: return 0x47
        default:   return byte
    }
}

func transform2(_ byte: UInt8) -> UInt8 {
    (0x41 ... 0x5A).contains(byte) ? byte + 0x20 : byte
}

// 2. There is only one way to write this function though
// 3. Generic functions are implications/deductions. Curry-Howard Correspondance
func identity<T>(_ t: T) -> T { t }

// 4. functions and closures are equivalent.
// 4a. functions are named closures
// 4b. closures are anonymous functions
// 5. nil and .none are synonyous
let optArray: [Int?] = [1, Optional<Int>.none, 2, Int?.none, 3, .none, nil]
let arr1 = optArray.compactMap { $0 }
let arr2 = optArray.compactMap(identity)

// 6. Functions are 1st class objects
func fidentity<A, B>(_ f: @escaping (A) -> B) -> (A) -> B {
    // Again, anywhere I see a func I should be able to plug in a closure
    //f
    { a in f(a) }
}

func invoke<A, B>(_ f: (A) -> B, _ a: (A)) -> B {
    f(a)
}

// 7. Line 29 and 33 seem the same.  We can generalize.
func uncurry<A, B, C>(
    _ f: @escaping (A) -> (B) async -> C
) -> (A, B) async -> C {
    { a, b in await f(a)(b) }
}
// 8. Equational reasoning
// uncurry(fidentity) = invoke

// 9. uncurry is the inverse of curry
// 10. functional languages all want functions in curried form.
func curry<A, B, C>(
    _ f: @escaping (A, B) async -> C
) -> (A) -> (B) async -> C {
    { a in { b in await f(a, b) } }
}
// curry(invoke) = fidentity


// 11. Order of arguments to a function don't matter
func flippedInvoke<A, B>(
    _ a: (A),
    _ f: (A) -> B
) -> B {
    f(a)
}

func flip<A, B, C>(
    _ f: @escaping (A, B) async -> C
) -> (B, A) async -> C {
    { b, a in await f(a, b) }
}
// flip(invoke) = flippedInvoke


// 12. Order of arguments to a _curried_ function doesn't matter
func flip<A, B, C>(
    _ f: @escaping (A) -> (B) async -> C
) -> (B) -> (A) async -> C {
    { b in  { a in await f(a)(b) } }
}
// flip(fidentity) = curry(uncurriedApply)

func compose<A, B, C>(
    _ f: @escaping (A) async -> B,
    _ g: @escaping (B) async -> C
) -> (A) async -> C {
    { a in await g(f(a)) }
}

func apply<A, B>(_ a: A) -> (@escaping (A) -> B) -> B {
    { f in f(a) }
}

/// we can make the apply function into a type by storing the value explicitly...
/// This demonstrates how "capture semantics" work
struct IntWrapper {
    let i: Int
    init(_ i: Int) { self.i = i }
    func transform(_ f: (Int) -> Int) -> Int { f(i) }
    func apply<B>(_ f: (Int) -> B) -> B { f(i) }
}


struct Object<A> {
    let a: A
    func apply<B>(_ f: @escaping (A) -> B) -> B { f(a) }
}
// Object<A>.init:  (A) -> Object<A>
// Object<A>.apply:       (Object<A>) -> ((A) -> B) -> B

// compose(Object<A>.init, Object<A>.apply):
//    (A) -> ((A) -> B) -> B
//
print("Compiled 'FP Basics' and ran")
//: [Next](@next)
