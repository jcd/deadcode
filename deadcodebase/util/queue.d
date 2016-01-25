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
