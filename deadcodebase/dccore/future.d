module dccore.future;

// static import core.thread;
import core.time;

struct FutureProgress
{
    size_t processed;
    size_t total;
    Duration duration;
}

// Used for promises that have no return value but are only there
// for side effects
struct VoidState
{
}

private class SharedState(T, bool Progress = false)
{
    bool _isValid;
	T _result;
	Exception _ex;
    static if (Progress)
        FutureProgress _progress;
    void delegate() _then;
}

class PromiseTmpl(T, bool Progress = false)
{
	SharedState!(T, Progress) _state;

	this()
	{
		_state = new SharedState!(T,Progress);
	}

	static if (Progress)
    {
        void setProgressCount(size_t processed, size_t total)
        {
            synchronized (_state)
            {
                _state._progress.processed = processed;
                _state._progress.total = total;
            }
        }
    }

	static if (is(Progress : FutureProgress))
    {
        void setProgressTime(Duration duration)
        {
            synchronized (_state)
            {
                _state._progress.duration = duration;
            }
        }
    }

    void setValue(T r)
	{
		synchronized (_state)
        {
            _state._isValid = true;
	    	_state._result = r;
            if (_state._then !is null)
                _state._then();
        }
	}

	void setException(Exception e)
	{
		synchronized (_state)
        {
            _state._isValid = true;
		    _state._ex = e;
            if (_state._then !is null)
                _state._then();
        }
	}

	FutureTmpl!(T, Progress) getFuture()
	{
		return new FutureTmpl!(T, Progress)(_state);
	}
}

alias Promise(T) = PromiseTmpl!(T, false);
alias ProgressingPromise(T) = PromiseTmpl!(T, true);
alias PromiseVoid = Promise!VoidState;
alias ProgressingPromiseVoid = ProgressingPromise!VoidState;

interface IFuture
{
	@property
	{
		bool isValid();
	}
}

class FutureTmpl(T, bool Progress = false) : IFuture
{
	private SharedState!(T,Progress) _state;

    // alias this = get;

	private this(SharedState!(T,Progress) s)
	{
		_state = s;
	}

	@property
	{
		bool isValid()
		{
            synchronized (_state)
                return _state._isValid;
		}
	}

	void wait()
	{
	}

    Future!U then(U)(U delegate(T) dlg)
    {
        auto p = new Promise!U();

        synchronized (_state)
        {
            if (_state._isValid)
            {
                // Promise already fulfilled -> just call the delegate immediately
                if (_state._ex is null)
                {
                    U u = dlg(_state._result);
                    p.setValue(u);
                }
                else
                {
                    throw _state._ex;
                }
            }
            else
            {
                // Promise not fulfilled yet
                _state._then = () {
                    if (_state._ex is null)
                    {
                        U u = dlg(_state._result);
                        p.setValue(u);
                    }
                    else
                    {
                        // Propagate the exception
                        p.setException(_state._ex);
                    }
                };
            }
        }

        return p.getFuture();
    }

    Future!VoidState then(void delegate(T) dlg)
    {
        auto p = new Promise!VoidState();

        synchronized (_state)
        {
            if (_state._isValid)
            {
                // Promise already fulfilled -> just call the delegate immediately
                if (_state._ex is null)
                {
                    dlg(_state._result);
                    p.setValue(VoidState());
                }
                else
                {
                    throw _state._ex;
                }
            }
            else
            {
                // Promise not fulfilled yet
                _state._then = () {
                    if (_state._ex is null)
                    {
                        dlg(_state._result);
                        p.setValue(VoidState());
                    }
                    else
                    {
                        // Propagate the exception
                        p.setException(_state._ex);
                    }
                };
            }
        }

        return p.getFuture();
    }

	static if (Progress)
    {
        FutureProgress getProgress()
        {
            synchronized (_state)
                return _state._progress;
        }
    }

	T get()
	{
        synchronized (_state)
        {
            assert(_state._isValid);
		    if (_state._ex is null)
			    return _state._result;
		    else
			    throw _state._ex;
        }
	}
}

alias Future(T) = FutureTmpl!(T, false);
alias ProgressingFuture(T) = FutureTmpl!(T, true);
alias FutureVoid = Future!VoidState;
alias ProgressingFutureVoid = ProgressingFuture!VoidState;

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
