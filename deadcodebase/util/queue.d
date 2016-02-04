module util.queue;

import std.traits: hasIndirections;

import core.atomic;

synchronized class GrowableCircularQueue(T)
{
    private size_t _length;
    private size_t first, last;
    private T[] A = [T.init];

    this(T[] items...) pure nothrow @safe
    {
        foreach (x; items)
            push(x);
    }

    @property size_t length() const pure nothrow @safe @nogc
    {
        return _length;
    }

    @property bool empty() const pure nothrow @safe @nogc
    {
        return _length == 0;
    }

    @property T front() pure nothrow @safe @nogc
    {
        assert(length != 0);
        return A[first];
    }

    //; Returns true if queue was not empty
    bool clear() pure nothrow @safe @nogc
    {
        bool startedAsEmpty = empty;
        while (!empty)
            popFront();
        return !startedAsEmpty;
    }

    T opIndex(in size_t i) pure nothrow @safe @nogc
    {
        assert(i < length);
        return A[(first + i) & (A.length - 1)];
    }

    void push(T item) pure nothrow @safe
    {
        size_t l = last;
        if (length >= A.length)
        { // Double the queue.
            immutable oldALen = A.length;
            A.length *= 2;
            if (last < first)
            {
                A[oldALen .. oldALen + l + 1] = A[0 .. l + 1];
                static if (hasIndirections!T)
                    A[0 .. last + 1] = T.init; // Help for the GC.
                // core.atomic.atomicOp!"+="(last, oldALen);
                last = l + oldALen;
                l = last;
                //last += oldALen;
            }
        }
        last = (l + 1) & (A.length - 1);
        A[last] = item;
        _length = _length + 1;
    }

    T popFront() pure nothrow @safe @nogc
    {
        assert(length != 0);
        auto saved = A[first];
        static if (hasIndirections!T)
            A[first] = T.init; // Help for the GC.
        first = (first + 1) & (A.length - 1);
        _length = _length - 1;
        return saved;
    }

    alias popFront pop;
}

unittest
{
    auto q = new shared GrowableCircularQueue!int;
    q.push(10);
    q.push(20);
    q.push(30);
    assert(q.pop() == 10);
    assert(q.pop() == 20);
    assert(q.pop() == 30);
    assert(q.empty);

    uint count = 0;
    foreach (immutable i; 1 .. 1_000)
    {
        foreach (immutable j; 0 .. i)
            q.push(count++);
        foreach (immutable j; 0 .. i)
            q.pop();
    }
}



/**
* A lock-free single-reader, single-writer FIFO queue.
* https://github.com/MartinNowak/lock-free/blob/master/src/lock_free/rwqueue.d
*/
shared struct RWQueue(T, size_t capacity = roundPow2!(PAGE_SIZE / T.sizeof))
{
    static assert(capacity > 0, "Cannot have a capacity of 0.");
    static assert(roundPow2!capacity == capacity, "The capacity must be a power of 2");

    @property size_t length() shared const
    {
        return atomicLoad!(MemoryOrder.acq)(_wpos) - atomicLoad!(MemoryOrder.acq)(_rpos);
    }

    @property bool empty() shared const
    {
        return !length;
    }

    @property bool full() const
    {
        return length == capacity;
    }

    void pushBusyWait(T t)
    {
        while (full)
        {
            import core.thread;
            import core.time;
            Thread.sleep(dur!"msecs"(10));
        }
        push(t);
    }

    void push(shared(T) t)
    in { assert(!full); }
    body
    {
        immutable pos = atomicLoad!(MemoryOrder.acq)(_wpos);
        _data[pos & mask] = t;
        atomicStore!(MemoryOrder.rel)(_wpos, pos + 1);
    }

    shared(T) pop()
    in { assert(!empty); }
    body
    {
        immutable pos = atomicLoad!(MemoryOrder.acq)(_rpos);
        auto res = _data[pos & mask];
        atomicStore!(MemoryOrder.rel)(_rpos, pos + 1);
        return res;
    }

    //; Returns true if queue was not empty
    bool clear()
    {
        bool startedAsEmpty = empty;
        while (!empty)
            pop();
        return !startedAsEmpty;
    }

private:
    //    import std.algorithm; // move

    enum mask = capacity - 1;

    size_t _wpos;
    size_t _rpos;
    T[capacity] _data;
}

private:

enum PAGE_SIZE = 4096;

template roundPow2(size_t v)
{
    import core.bitop : bsr;
    enum roundPow2 = v ? cast(size_t)1 << bsr(v) : 0;
}

static assert(roundPow2!0 == 0);
static assert(roundPow2!3 == 2);
static assert(roundPow2!4 == 4);

version (unittest)
{
    import core.thread, std.concurrency;
    enum amount = 10_000;

    void push(T)(ref shared(RWQueue!T) queue)
    {
        foreach (i; 0 .. amount)
        {
            while (queue.full)
                Thread.yield();
            queue.push(cast(shared T)i);
        }
    }

    void pop(T)(ref shared(RWQueue!T) queue)
    {
        foreach (i; 0 .. amount)
        {
            while (queue.empty)
                Thread.yield();
            assert(queue.pop() == cast(shared T)i);
        }
    }
}

unittest
{
    shared(RWQueue!size_t) queue;
    auto t0 = new Thread({push(queue);}),
        t1 = new Thread({pop(queue);});
    t0.start(); t1.start();
    t0.join(); t1.join();
}

unittest
{
    static struct Data { size_t i; }
    shared(RWQueue!Data) queue;
    auto t0 = new Thread({push(queue);}),
        t1 = new Thread({pop(queue);});
    t0.start(); t1.start();
    t0.join(); t1.join();
}
