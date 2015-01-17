module core.future;

// static import core.thread;

private class SharedState(T)
{
	bool _isValid;
	T _result;
	Exception _ex;
}

class Promise(T)
{
	SharedState!T _state;
	
	this()
	{
		_state = new SharedState!T;
	}
	
	void setValue(T r)
	{
		_state._isValid = true;
		_state._result = r;
	}
	
	void setException(Exception e)
	{
		_state._isValid = true;
		_state._ex = e;	
	}

	Future!T getFuture()
	{
		return new Future!T(_state);
	}
}

interface IFuture 
{
	@property
	{
		bool isValid();
	}
}

class Future(T) : IFuture
{
	private SharedState!T _state;

	private this(SharedState!T s)
	{
		_state = s;
	}
	
	@property
	{
		bool isValid()
		{
			return _state._isValid;
		}
	}

	void wait()
	{
	}

	T get()
	{
		assert(_state._isValid);
		if (_state._ex is null)
			return _state._result;
		else 
			throw _state._ex;
	}
}
/*
class Fiber : core.thread.Fiber
{
	private Future _future;

	@property 
	{
		bool hasFuture() const pure nothrow @safe
		{
			return _future !is null;
		}
		
		bool isFutureValid() 
		{
			return _future.isValid;
		}
	}

	this(void function() fn, size_t sz = PAGESIZE * 4)
	{
		super(fn, sz);
	}	

	this(void delegate() dg, size_t sz = PAGESIZE * 4)
	{
		super(dg, sz);
	}

	void waitFor(IFuture f)
	{
		if (!f.isValid)
		{
			_f = f;
			yield();
		}
	}
}
*/