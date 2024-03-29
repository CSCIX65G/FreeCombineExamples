### Functional Programming

* [Why Functional Programming Matters](https://www.cs.kent.ac.uk/people/staff/dat/miranda/whyfp90.pdf)

### Applied Functional Type Theory

* Sergei Winitzki's talk: [What I learned about functional programming while writing a book about it](https://youtu.be/T5oB8PZQNvY)

* [The Science of Functional Programming, Sergei Winitzki](https://leanpub.com/sofp) Sergei Winitzki's AMAZING book. From the book's description:

> After reading this book, you will understand everything in FP. Prove that your application's business logic satisfies the laws for free Tambara profunctor lens over a holographic co-product monoidal category (whatever that means), and implement the necessary code in Scala? Will be no problem for you.

*_ NB This statement is true._* :)

Seriously, the idea of adding parametricity to compositionality as a fundamental organizing principle in software engineering is critical to putting the discipline on a strong, usable theoretical foundation.  

* [Programming Design by Calculation, J.N. Oliviera](https://www4.di.uminho.pt/~jno/ps/pdbc.pdf)   Another text explicitly discussing compositionality and parametricity.

> ... the book invites software designers to raise standards and adopt mature development techniques found in other engineering disciplines, which (as a rule) are rooted on a sound mathematical basis. Compositionality and parametricity are central to the whole discipline, granting scalability from school desk exercises to large problems in an industry setting.

and 

> It is commonplace to say that today’s programmers write poorly concurrent code. This is actually worse: they still write poorly structured sequential code because they were not trained in the art of compositionality early enough in their background. And so they find it hard to design a piece of software in terms of collaborative, small units, each doing its own job. Let alone other forms of composition in which such components operate concurrently, in a parallel way.

* [Interesting post on Monads in Swift](https://broomburgo.github.io/fun-ios/post/why-monads/)

### CSP

* [Communicating Haskell Processes](http://twistedsquare.com/thesis.pdf)
### Swift Atomics

* [Tutorial on Memory Ordering](http://www.ai.mit.edu/projects/aries/papers/consistency/computer_29_12_dec1996_p66.pdf)
* [C++ Memory Ordering](https://en.cppreference.com/w/cpp/atomic/memory_order)
* [Memory Ordering in Modern Microprocessors, Part I](https://www.linuxjournal.com/article/8211)
* [Memory Ordering in Modern Microprocessors, Part II](https://www.linuxjournal.com/article/8211)

### Swift Concurrency

* [SE-296 Async/Await](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)
* [SE-298 AsyncSequence](https://github.com/apple/swift-evolution/blob/main/proposals/0298-asyncsequence.md)
* [SE-300 Continuations, Unsafe and Checked](https://github.com/apple/swift-evolution/blob/main/proposals/0300-continuation.md)
* [SE-302 Sendable](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
* [SE-314 AsyncStream](https://github.com/apple/swift-evolution/blob/main/proposals/0314-async-stream.md)

### Coroutines vs Fibers as Concurrency Constructs

* [Wikipedia article on Fibers](https://en.wikipedia.org/wiki/Fiber_(computer_science))
* [Discussion on Swift Evolution](https://forums.swift.org/t/why-stackless-async-await-for-swift/52785/7)
* [Fibers Under the Magnifying Glass](https://www.open-std.org/JTC1/SC22/WG21/docs/papers/2018/p1364r0.pdf)
* [Response to Fibers Under the Magnifying Glass](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0866r0.pdf)
* [Response to the Response to Fibers Under the Magnifying Glass](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p1520r0.pdf)
* [Stackless Python](https://en.wikipedia.org/wiki/Stackless_Python)
* [Wikipedia article on Green (Stackful) Threads in Java](https://en.wikipedia.org/wiki/Green_threads)

### Readings on Concurrency in other languages

* [Sources for a lot of the design Swift Concurrency](https://forums.swift.org/t/concurrency-designs-from-other-communities/32389/16) From the thread:

    * [Discussion of implementation of concurrency in many languages](https://trio.discourse.group/c/structured-concurrency/7)
    * [Concurrency in Clojure](https://www.clojure.org/about/concurrent_programming)
    * [Concurrency in Rust](https://www.infoq.com/presentations/rust-2019/)
    * [Concurrency in Java (Project Loom)](https://cr.openjdk.java.net/~rpressler/loom/loom/sol1_part1.html)
    * [Concurrency in Dart](https://www.youtube.com/watch?v=vl_AaCgudcY)
    * [Concurrency in Go vs Concurrency in C#](https://medium.com/@alexyakunin/go-vs-c-part-1-goroutines-vs-async-await-ac909c651c11)
    * [Cool diagram showing some diffs](https://forums.swift.org/t/concurrency-designs-from-other-communities/32389/23)
    * [What color is your function](https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/)
    * [Function color is a myth](https://lukasa.co.uk/2016/07/The_Function_Colour_Myth/)
    * [Declarative Concurrency](https://www.cse.iitk.ac.in/users/satyadev/fall12/declarative-concurrency.html)
    * [The Research Language Koka](https://github.com/koka-lang/koka) with [Algebraic Effects](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/08/algeff-tr-2016-v2.pdf)

### "Structured Concurrency" in Trio

* [Notes on structured concurrency](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/) the original post that sparked Apple's approach of structured concurrency, in particular the idea that Task lifetimes should be organized hierarchically.
* [Timeouts and Cancellation for Humans](https://vorpus.org/blog/timeouts-and-cancellation-for-humans/) - influential on Apple's thinking

### Swift _Structured_ Concurrency (SSC) Proposals

* [SE-304 Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#proposed-solution) The original structured concurrency proposal from Apple and the solution they propose 

> If child tasks did not have bounded duration and so could arbitrarily outlast their parents, the behavior of tasks under these features would not be easily comprehensible.
> In this proposal, the way to create child tasks is only within a TaskGroup, however there will be a follow-up proposal that enables creation of child tasks in any asynchronous context.

* [SE-306 Actors](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
* [SE-317 async let](https://github.com/apple/swift-evolution/blob/main/proposals/0317-async-let.md)

### Swift NIO and Structured Concurrency

* [Guidelines on NIO](https://github.com/swift-server/guides/blob/main/docs/concurrency-adoption-guidelines.md).  The official guidelines that implementors of server-side code are supposed to consider.
* [NIO Roadmap](https://forums.swift.org/t/future-of-swift-nio-in-light-of-concurrency-roadmap/41633/4).  Basically NIO needs custom executors to build its own version of a ThreadPool.
* [NIO Roadmap part 2](https://forums.swift.org/t/future-of-swift-nio-in-light-of-concurrency-roadmap/41633/11).  Basically NIO can't use async/await and this is true of all I/O bound processes.  (I'm thinking UI)

### Theory of Coroutines

* [Haskell's Coroutine Module](https://hackage.haskell.org/package/monad-coroutine-0.9.2/docs/Control-Monad-Coroutine.html)
* [Explanation of Coroutines in Haskell](https://www.schoolofhaskell.com/school/to-infinity-and-beyond/pick-of-the-week/coroutines-for-streaming)
* [Co: a dsl for coroutines](https://abhinavsarkar.net/posts/implementing-co-1/) From the link:

> Coroutine implementations often come with support for Channels for inter-coroutine communication. One coroutine can send a message over a channel, and another coroutine can receive the message from the same channel. Coroutines and channels together are an implementation of Communicating Sequential Processes (CSP)@5, a formal language for describing patterns of interaction in concurrent systems.

* [Communicating Sequential Processes](https://en.wikipedia.org/wiki/Communicating_sequential_processes) From the link:

> CSP message-passing fundamentally involves a rendezvous between the processes involved in sending and receiving the message, i.e. the sender cannot transmit a message until the receiver is ready to accept it. In contrast, message-passing in actor systems is fundamentally asynchronous, i.e. message transmission and reception do not have to happen at the same time, and senders may transmit messages before receivers are ready to accept them. These approaches may also be considered duals of each other, in the sense that rendezvous-based systems can be used to construct buffered communications that behave as asynchronous messaging systems, while asynchronous systems can be used to construct rendezvous-style communications by using a message/acknowledgement protocol to synchronize senders and receivers.

NB FreeCombine takes the message/acknowledgement protocol approach as primitive and builds out from there.  Differences between `StateTask` in FreeCombine and `actor` in Swift Concurrency:

1. `StateTask` allows `oneway` sends as well as synchronized sends
2. `StateTask` allows backpressure
3. `actor` has syntactical support in the language

* [PI Calculus](https://en.wikipedia.org/wiki/Π-calculus)

* [The Producer/Consumer pattern in Java](https://www.baeldung.com/java-producer-consumer-problem))

### Theory of Streams

* [A Brief History of Streams](https://shonan.nii.ac.jp/archives/seminar/136/wp-content/uploads/sites/172/2018/09/a-brief-history-of-streams.pdf) - see especially page 21 comparing push and pull strategies
* [History of Haskell](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/07/history.pdf) - see in particular Section 7.1 on Stream and Continuation-based I/O
* [Oleg Kiselyov's Stream Page](https://okmij.org/ftp/Streams.html)
* [Stream Fusion: From Lists to Streams to Nothing At All](https://github.com/bitemyapp/papers/blob/master/Stream%20Fusion:%20From%20Lists%20to%20Streams%20to%20Nothing%20At%20All.pdf)

> RVS - The equivalent to stream fusion under FreeCombine is to `@inline` everything possible.

* [All Things Flow: A History of Streams](https://okmij.org/ftp/Computation/streams-hapoc2021.pdf)
* [Exploiting Vector Instructions with Generalized Stream Fusion](https://cacm.acm.org/magazines/2017/5/216312-exploiting-vector-instructions-with-generalized-stream-fusion/fulltext)
* [Functional Stream Libraries and Fusion: What's Next?](https://okmij.org/ftp/meta-programming/shonan-streams.pdf)
* [Ziria - A DSL for wireless systems programming](http://ace.cs.ohio.edu/~gstewart/papers/ziria/ziria.pdf)
* [Streaming Programs w/o Laziness: A Short Primer](https://www.tweag.io/blog/2017-07-27-streaming-programs/)
* [Streaming with Linear Types](https://www.tweag.io/blog/2018-06-21-linear-streams/)

### Theory of State

* [Lazy Functional State Threads](https://github.com/bitemyapp/papers/blob/master/Lazy%20Functional%20State%20Threads.pdf) - the original paper on the ST monad

### Generalized Functional Concurrency

* [Functional Pearls: A Poor Man's Concurrency Monad](https://github.com/bitemyapp/papers/blob/master/A%20Poor%20Man's%20Concurrency%20Monad.pdf)
* [Cheap (But Functional) Threads](https://github.com/bitemyapp/papers/blob/master/Cheap%20(But%20Functional)%20Threads.pdf)
* [Combining Events and Threads ...](https://github.com/bitemyapp/papers/blob/master/Combining%20Events%20and%20Threads%20for%20Scalable%20Network%20Services:%20Implementation%20and%20Evaluation%20of%20Monadic%2C%20Application-Level%20Concurrency%20Primitives.pdf)
* [Compiling with Continuations, Continued](https://github.com/bitemyapp/papers/blob/master/Compiling%20with%20Continuations%2C%20Continued.pdf)
* [Functional Reactive Programming from First Principles](https://github.com/bitemyapp/papers/blob/master/Functional%20Reactive%20Programming%20from%20First%20Principles.pdf)
* [Functional Reactive Programming, Continued](https://github.com/bitemyapp/papers/blob/master/Functional%20Reactive%20Programming%2C%20Continued.pdf)
* [Higher-order Functional Reactive Programming without Spacetime Leaks](https://github.com/bitemyapp/papers/blob/master/Higher-Order%20Functional%20Reactive%20Programming%20without%20Spacetime%20Leaks.pdf)
* [Push-Pull Functional Reactive Programming](http://conal.net/papers/push-pull-frp/push-pull-frp.pdf)

> While FRP has simple, pure, and composable semantics, its efficient implementation has not been so simple. In particular, past implementations have used demand-driven (pull) sampling of reactive behaviors, in contrast to the data-driven (push) evaluation typically used for reactive systems, such as GUIs. There are at least two strong reasons for choosing pull over push for FRP:
> • Behaviors may change continuously, so the usual tactic of idling until the next input change (and then computing consequences) doesn’t apply.
> • Pull-based evaluation fits well with the common functional programming style of recursive traversal with parameters (time, in this case). Push-based evaluation appears at first to be an inherently imperative technique.

* [Stream Fusion on Haskell Unicode Strings](https://github.com/bitemyapp/papers/blob/master/Stream%20Fusion%20on%20Haskell%20Unicode%20Strings.pdf)

### Stream Libraries

* [Akka Streams](https://qconnewyork.com/ny2015/system/files/presentation-slides/AkkaStreamsQconNY.pdf) - important for the idea of dynamic push/pull mode.  See especially starting on page 29.
* Conversation on Combine and Async/Await 
    * [Part 1](https://iosdevelopers.slack.com/archives/C0AET0JQ5/p1623102144192300)
    * [Part 2](https://iosdevelopers.slack.com/archives/C0AET0JQ5/p1623177619245300?thread_ts=1623102144.192300&cid=C0AET0JQ5)

### Odds and Ends

* [Y Combinator Discussion of FRP](https://news.ycombinator.com/item?id=32448772)

> As someone who had to maintain two applications written entirely using the FRP Paradigm (Rx in Kotlin/Swift with a heavy focus on FRP principles), I am fascinated the idea but I absolutely hated the experience. Writing behaviour flows can end in beautiful blocks of easy to understand operations. However, as these get more complex and you need to combine multiple data streams, logic is scattered all over a module.

> RVS - Does creating a REPL to go from CPS-style back to direct-style help to unify the two styles?

* [The Crusty Talk](https://devstreaming-cdn.apple.com/videos/wwdc/2015/408509vyudbqvts/408/408_protocoloriented_programming_in_swift.pdf)
* [Resource Acquisition is Initialization](https://en.wikipedia.org/wiki/Resource_acquisition_is_initialization)
* [EventLoopFuture](https://github.com/apple/swift-nio/blob/e2c7fa4d4bda7cb7f4150b6a0bd69be2a54ef8c4/Sources/NIOCore/EventLoopFuture.swift#L385)
* [EventLoopPromise](https://github.com/apple/swift-nio/blob/e2c7fa4d4bda7cb7f4150b6a0bd69be2a54ef8c4/Sources/NIOCore/EventLoopFuture.swift#L159)
* [Leaking an EventLoopPromise is an Error](https://github.com/apple/swift-nio/blob/e2c7fa4d4bda7cb7f4150b6a0bd69be2a54ef8c4/Sources/NIOCore/EventLoopFuture.swift#L428)
* [Actor-isolation and Executors](https://github.com/apple/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md)
* [Strema a functional language targeting the JSVM](https://gilmi.gitlab.io/strema/)
* [Lazy Functional StateThreads](https://www.microsoft.com/en-us/research/wp-content/uploads/1994/06/lazy-functional-state-threads.pdf)
* [RankN Types in Haskell (i.e What's used in the ST Monad)](http://sleepomeno.github.io/blog/2014/02/12/Explaining-Haskell-RankNTypes-for-all/))
* [Lock Free Data Structures in Java](https://www.baeldung.com/lock-free-programming)
* [Linear Types Make Performance More Predictable](https://www.tweag.io/blog/2017-03-13-linear-types/)

> Linear types can make fusion predictable and guaranteed. Fusion is crucial to writing programs that are both modular and high-performance. But a common criticism, one that we’ve seen born out in practice, is that it’s often hard to know for sure whether the compiler seized the opportunity to fuse intermediate data structures to reduce allocations, or not. This is still future work, but we’re excited about the possibilities: since fusion leans heavily on inlining, and since linear functions are always safe to inline without duplicating work because they only use their argument once, it should be possible with a few extra tricks to get guaranteed fusion.

> RVS: Stream fusion should not be required in FreeCombine bc Swift optimization should be able to take advantage of annotated inlining.  FreeCombine needs to make more aggressive use of `@inlinable`.

* [Retrofitting Linear Types](https://github.com/tweag/linear-types/releases/download/v1.0/hlt.pdf)
* [Retrofitting Linear Types v2](https://github.com/tweag/linear-types/releases/download/v2.0/hlt.pdf)
* [Linear Types Blog Entries on Tweag](https://www.tweag.io/blog/tags/linear-types)
* [Linear Haskell](https://www.tweag.io/blog/2021-02-10-linear-base/)

* [Pi Calculus](https://en.wikipedia.org/wiki/Π-calculus)

> The asynchronous π-calculus allows only outputs with no suffix, i.e. output atoms of the form  ̅x<y>, yielding a smaller calculus. However, any process in the original calculus can be represented by the smaller asynchronous π-calculus using an extra channel to simulate explicit acknowledgement from the receiving process. Since a continuation-free output can model a message-in-transit, this fragment shows that the original π-calculus, which is intuitively based on synchronous communication, has an expressive asynchronous communication model inside its syntax. However, the nondeterministic choice operator defined above cannot be expressed in this way, as an unguarded choice would be converted into a guarded one; this fact has been used to demonstrate that the asynchronous calculus is strictly less expressive than the synchronous one (with the choice operator).
