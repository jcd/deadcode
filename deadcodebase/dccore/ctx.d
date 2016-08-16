module dccore.ctx;

Ctx ctx; // Singleton

// Attribute to set on class to allow it to be auto created by Ctx
enum CtxAutoCreate = 1;

struct Ctx
{	
	void set(MgrType)(MgrType mgr)
	{
		MgrType oldMgr = null;
		auto typeInfo = typeid(MgrType); 
		auto m = typeInfo in _managers;
		if (m !is null)
		{
			_managers[typeInfo] = ManagerEntry(mgr, m.subscribers);
			m.publish(cast(MgrType)m.manager, mgr);
		}
		else
		{
			_managers[typeInfo] = ManagerEntry(mgr);
			ensureManagerEntryExists!MgrType();
		}
	}

	void clear(MgrType)()
	{
		set(null);
		_managers.remove(typeid(MgrType));
	}

	MgrType query(MgrType)()
	{
		auto m = typeid(MgrType) in _managers;
		if (m !is null)
			return cast(MgrType)m.manager;
		return null;
	}

	MgrType get(MgrType)()
	{
		import std.traits;
		auto m = query!MgrType();
		static if ( hasUDA!(MgrType, CtxAutoCreate) )
		{
			if (m is null)
			{
				set(new MgrType());
				m = query!MgrType();
			}
		}
		assert(m !is null);
		return m;
	}

	MgrType subscribe(MgrType)(void delegate(MgrType oldMgr, MgrType newMgr) dg)
	{		
		import std.traits;
		auto m = ensureManagerEntryExists!MgrType;
		static if ( hasUDA!(MgrType, CtxAutoCreate) )
		{
			if (m.manager is null)
			{
				set(new MgrType());
				m = typeid(MgrType) in _managers;
			}
		}
		m.subscribers ~= new TypedSubscriber!MgrType(dg);
		return cast(MgrType)m.manager;
	}

	MgrType unsubscribe(MgrType)(void delegate(MgrType oldMgr, MgrType newMgr) dg)
	{
		auto m = typeid(MgrType) in _managers;
		assert(m !is null, "Cannot unsubscribe to unknown manager in  Ctx");
		if (m !is null)
		{
			m.subscribers = m.subscribers.remove(a => a.hasDelegate(dg.ptr, dg.funcptr));
			return cast(MgrType)m.manager;
		}
		return null;
	}

private:
	ManagerEntry* ensureManagerEntryExists(MgrType)()
	{
		auto typeInfo = typeid(MgrType);
		auto m = typeInfo in _managers;
		if (m !is null)
			return m;
	
		_managers[typeInfo] = ManagerEntry(null);
		return typeInfo in _managers;
	}

	interface Subscriber
	{
		bool hasDelegate(void* closurePtr, void* functionPtr);
		void publish(Object oldMgr, Object newMgr);
	}

	class TypedSubscriber(T) : Subscriber
	{
		alias Type = T;
		alias Dlg = void delegate(T oldMgr, T newMgr);
		Dlg dlg;

		this(Dlg d)
		{
			dlg = d;
		}

		bool hasDelegate(void* closurePtr, void* functionPtr)
		{
			return dlg.ptr == closurePtr && dlg.funcptr == functionPtr;
		}

		void publish(Object oldm, Object newm) 
		{
			T o = cast(T)oldm;
			T n = cast(T)newm;
			dlg(o, n);
		};
	}

	struct ManagerEntry
	{
		Object manager;
		Subscriber[] subscribers;
		void publish(Object oldm, Object newm) 
		{
			foreach (s; subscribers)
				s.publish(oldm, newm);
		}
	}

	ManagerEntry[TypeInfo_Class] _managers;
}

struct CtxVar(MgrType, bool withSignal = true)
{
	static if (withSignal)
	{
		import dccore.signals;
		mixin Signal!(MgrType, MgrType) onCtxVarChanged;
	}

	MgrType _cached;
	alias cachedCtxVar this;
	
	@property MgrType cachedCtxVar() 
	{
		return getAndPrimeCacheIfNeeded();
	}

	private MgrType getAndPrimeCacheIfNeeded()
	{
		if (_cached is null)
		{
			_cached = ctx.subscribe((MgrType oldMgr, MgrType newMgr) {
				_cached = newMgr;
				static if (withSignal)
					onCtxVarChanged.emit(oldMgr, newMgr);
			});
		}
		return _cached;
	}
}


unittest 
{
	class MyMgr
	{
		int gotSignalCount = 0;
	}

	CtxVar!MyMgr var1;
	CtxVar!MyMgr var1b;
	CtxVar!(MyMgr, true) var1c;
	var1c.onCtxVarChanged.connectTo((MyMgr oldLog, MyMgr newLog) {
		newLog.gotSignalCount++;
	});
	assert(var1.cachedCtxVar is null);
	assert(var1b.cachedCtxVar is null);
	assert(var1c.cachedCtxVar is null);

	ctx.set(new MyMgr());
	
	CtxVar!MyMgr var2;
	assert(var2.cachedCtxVar !is null);
	assert(var1.cachedCtxVar !is null);
	assert(var1b.cachedCtxVar !is null);
	assert(var1c.cachedCtxVar !is null);
	assert(ctx.get!MyMgr().gotSignalCount == 1);
}