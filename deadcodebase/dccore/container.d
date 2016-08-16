module dccore.container;

import test;
mixin registerUnittests;

class Stack(T)
{
	T[] _stack;

	void push(T v)
	{
		assumeSafeAppend(_stack);
		_stack ~= v;
	}

	@property bool empty() const pure nothrow @safe
	{
		return _stack.length == 0;
	}

	@property T top()
	{
		return _stack[$-1];
	}

	// Locate item in stack and remove it from stack
	bool remove(T item)
	{
		foreach (i, v; _stack)
		{
			if (v == item)
			{
				assumeSafeAppend(_stack);
				if (i != _stack.length - 1)
					_stack[i..$-1] = _stack[i+1..$];
				_stack.length = _stack.length - 1;
				return true;
			}
		}
		return false;
	}

	unittest
	{
		Stack!int s = new Stack!int;
		s.push(1);
		s.push(2);
		s.push(3);
		s.remove(2);
		assert(s.pop() == 3);
		assert(s.pop() == 1);
	}

	// Locate item in stack and remove it from stack even if there multiple times
	bool removeAll(T item)
	{
		bool removedSome = false;
		while (remove(item)) { removedSome = true;}
		return removedSome;
	}

	T pop()
	{
		assumeSafeAppend(_stack);
		auto v = _stack[$-1];
		_stack.length = _stack.length - 1;
		return v;
	}
}

unittest
{
	Stack!int s = new Stack!int;
	s.push(1);
	s.push(2);
	s.push(3);
	assert(s.pop() == 3);
	assert(s.pop() == 2);
	assert(s.pop() == 1);
	assert(s.empty);

	s.push(1);
	s.push(2);
	Stack!int s2 = s;

	assert(s2.pop() == 2);
	s2.push(4);
	assert(s.pop() == 4);
}



class Queue(T)
{
	// Implementation use this array as a circular buffer
	T[] _queue; // Ths queu 
	size_t _begin;
	size_t _end;

	this(size_t reserveSize = 8)
	{
		if (reserveSize == 0)
			reserveSize = 2; // do not allow 0 size queue

		// capacity might be more that we try to reserve
		_queue.length = _queue.reserve(reserveSize);
	}

	void enqueueIfRoom(T v) @nogc
	{
		auto newEnd = _end+1;
		if (newEnd == _begin || (newEnd == _queue.length && _begin == 0))
			return; // no room... would allocate

		assert(_end < _queue.length);
		_queue[_end++] = v;

		if (_end == _queue.length)
		{
			// Wrap around because there is room at the start of the array
			_end = 0;
		}
	}

	void enqueue(T v)
	{
		assert(_end < _queue.length);
		_queue[_end++] = v;
		
		if (_end == _queue.length)
		{
			// is the queue full?
			if (_begin == 0)
			{
				// extend the queue. Since we know that 
				// capacity is reached we can simply 
				_queue.length++;
				_queue.length = _queue.capacity;
			}
			else
			{
				// Wrap around because there is room at the start of the array
				_end = 0;
			}
		}
		else if (_end == _begin)
		{
			// out of room
			T[] newQueue;
			// capacity might be more that we try to reserve
			newQueue.length = newQueue.reserve(_queue.length * 2);
			auto endSize = _queue.length - _begin;
			newQueue[0.._end] = _queue[0.._end];
			newQueue[$-endSize..$] = _queue[$-endSize..$];
			_begin = newQueue.length - endSize;
			_queue = newQueue;
			assert(_begin >= 0);
		}
	}

	@property bool empty() const pure nothrow @safe
	{
		return _begin == _end;
	}

	@property T front()
	{
		return _queue[_begin];
	}

	void popFront()
	{
		dequeue();
	}

	// Locate item in queue and remove it from queue
	//bool remove(T item)
	//{
	//    // 
	//    foreach (i, v; _queue)
	//    {
	//        if (v == item)
	//        {
	//            assumeSafeAppend(_queue);
	//            if (i != _queue.length - 1)
	//                _queue[i..$-1] = _queue[i+1..$];
	//            _queue.length = _queue.length - 1;
	//            return true;
	//        }
	//    }
	//    return false;
	//}


	// Locate item in stack and remove it from queue even if there multiple times
	//bool removeAll(T item)
	//{
	//    bool removedSome = false;
	//    while (remove(item)) { removedSome = true;}
	//    return removedSome;
	//}

	T dequeue()
	{
		assert(_begin != _end);
		T v = _queue[_begin++]; 
		_queue[_begin-1] = T.init;
		if (_begin == _queue.length)
		{
			// We need to wrap the _begin marker to the end of the _queue
			_begin = 0;
		}
		return v;
	}
}

version (unittest)
{
	import std.stdio;
	import std.algorithm;
	void chk(T)(T q, size_t b, size_t e)
	{
		version (verboseunittest)
			writeln(q._queue.capacity, " ", q._queue.length, " ", q._begin, " ", q._end);
		assert(q._begin == b);
		assert(q._end == e);		
	}

	void chk(T)(T q, size_t cap, size_t len, size_t b, size_t e)
	{
		version (verboseunittest)
			writeln(q._queue.capacity, " ", q._queue.length, " ", q._begin, " ", q._end);
		assert(q._queue.capacity == cap);
		assert(q._queue.length == len);
		assert(q._begin == b);
		assert(q._end == e);		
	}
}

struct T { string n; }


@T("queue and dequeue until empty")
unittest
{
	//      b
	//      e  
	// | | | |
	Queue!int s = new Queue!int(2);
	s.enqueue(1);
	s.enqueue(2);
	assert(s.dequeue() == 1);
	assert(s.dequeue() == 2);
	s.chk(2,2);
	assert(equal(s, [1][0..0]));
}

@T("will resize when exceeding buffer length")
unittest
{
	//  b    
	//       e 
	// |1|2|3| | | | | 
	Queue!int s = new Queue!int(2);
	s.chk(3,3,0,0);
	s.enqueue(1);
	s.enqueue(2);
	s.enqueue(3);
	s.chk(7,7,0,3);
	assert(equal(s, [1,2,3]));
}

@T("head will wrap")
unittest
{
	//    b  
	// e      
	// | |2|3|
	Queue!int s = new Queue!int(2);
	s.enqueue(1);
	s.enqueue(2);
	assert(s.dequeue() == 1);
	s.enqueue(3);
	s.chk(1,0);
	assert(equal(s, [2,3]));
}

@T("will resize when exceeding buffer size in the middle")
unittest
{
	//            b
	//   e
	// |4| | | | |2|3| 
	Queue!int s = new Queue!int(2);
	s.enqueue(1);
	s.enqueue(2);
	assert(s.dequeue() == 1);
	s.enqueue(3);
	s.enqueue(4);
	s.chk(7,7,5,1);
	assert(equal(s, [2,3,4]));
}

@T("tail will wrap")
unittest
{
	//  b   
	//   e  
	// |4| | |
	Queue!int s = new Queue!int(2);
	s.enqueue(1);
	s.enqueue(2);
	assert(s.dequeue() == 1);
	assert(s.dequeue() == 2);
	s.enqueue(3);
	s.enqueue(4);
	assert(s.dequeue() == 3);
	s.chk(3,3,0,1);
	assert(equal(s, [4]));
}
