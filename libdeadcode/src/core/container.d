module core.container;

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
