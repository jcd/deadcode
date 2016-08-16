module dccore.event;

import std.datetime : SysTime, Clock;
import std.typecons : Tuple, AliasSeq;
import std.variant;

version (unittest)
	import test;

alias EventType = ushort;

enum EventUsed
{
	no = 0,
	yes = 1
}

class Event
{
	enum invalidType = 0;
	EventType type = invalidType;
	SysTime timestamp;
    bool used = false;
	void function(Event) disposeFunc;
	debug string name; 

	final void dispose()
	{
		disposeFunc(this);
	}

	final void markUsed()
	{
		used = true;
	}

	final @property bool isValid() const pure @safe @nogc nothrow 
	{
		return type != invalidType;
	}

	@property bool allowCombine() pure @safe nothrow const
	{
		return false;
	}

	// Returns true if events could be combined and in that case
	// just use this event and dispose the argument event.
	bool combineIntoThis(Event e)
	{
		assert(0); // only allowed allowCombine has returned true and subclass has overridden this method
	}
}

class TimeoutEvent : Event
{
	this(bool _aborted, Variant data = Variant.init)
	{
		aborted = _aborted;
		userData = data;
	}
	bool aborted = false;
	Variant userData;
}

class QuitEvent : Event
{
}

struct EventDescription
{
	string system;
	string name;
}

alias I(alias T) = T;
alias I(T...) = T;

interface IEventRegistrant 
{
	@property string name() const pure nothrow @safe @nogc;
	void register(EventManager mgr);
}

template filterEventType(alias Mod)  
{
	template filterEventType(string member)  
	{
		import std.traits;
		static if (is ( I!(__traits(getMember, Mod, member)) ) )
		{
			alias mem = I!(__traits(getMember, Mod, member));
			static if (is(mem : Event) && !isAbstractClass!mem && ! is(mem == Event))
			{
				//static if (staticIndexOf!(Event, BaseClassesTuple!mem) != -1 && !isAbstractClass!mem)
				//static if (!isAbstractClass!mem)
				//{
					//pragma(msg, "Register2 event " ~ member);
					alias filterEventType = Tuple!(mem, member); // toLower(member[0..1]) ~ member[1..$];
					// return mem;
					//mem.staticType = mgr.register(EventDescription(system, eventName));
				//}
				//else
				//{
//					alias filterEventType = AliasSeq!();
	//			}
			}
			else
			{
				alias filterEventType = AliasSeq!();
			}
		}
		else
		{
			alias filterEventType = AliasSeq!();
		}
	}
}

// e.g. 
// MyClass -> myClass 
// DNAClass -> dnaClass
// dnaClass -> dnaClass
string identifierToFieldName(string cname)
{
	import std.string;
	import std.algorithm;
	auto i = munch(cname, "A-Z");
	if (cname.length == 0)
		return toLower(i); // all uppercase
	else if (i.length == 0)
		return cname;      // all lowercase 
	else if (i.length == 1)
		return toLower(i) ~ cname; // the MyClass case
	else
		return toLower(i[0..$-1]) ~ i[$-1] ~ cname; // the MYClass case
}

unittest
{
	Assert("", identifierToFieldName(""));
	Assert("a", identifierToFieldName("A"));
	Assert("a", identifierToFieldName("a"));
	Assert("myClass", identifierToFieldName("MyClass"));
	Assert("dnaClass", identifierToFieldName("DNAClass"));
	Assert("dnaClass", identifierToFieldName("dnaClass"));
	Assert("dna", identifierToFieldName("DNA"));
	enum foo = identifierToFieldName("MyClass");
	Assert("myClass", foo, "CTFE");
}

string identifierToEventFieldName(string cname)
{
	auto n = identifierToFieldName(cname);
	
	// strip "Event" suffix
	enum suffix = "Event";
	enum l = suffix.length;
	
	if (n.length > 5 && n[$-l..$] == suffix)
		return n[0..$-l];
	return n;
}

unittest
{
	Assert("", identifierToEventFieldName(""));
	Assert("event", identifierToEventFieldName("Event"));
	Assert("foo", identifierToEventFieldName("FooEvent"));
}

template registerEvents(string system, string modStr = __MODULE__)
{
	import std.traits;
	// pragma (msg, "registerEvents " ~ modStr);
	alias mod = I!(mixin(modStr));
	import std.meta;
	import std.string;
	import std.traits;

	alias EventTypes = staticMap!(filterEventType!mod, __traits(allMembers, mod));

	private string getEventTypesStructMembers(T...)()
	{
		size_t minSize = 0;
		size_t maxSize = 0;
		string eventTypesString = "";
		foreach (t; T)
		{
			auto sz =  __traits(classInstanceSize, t.Types[0]);
			minSize = sz < minSize ? sz : minSize;
			maxSize = sz > maxSize ? sz : maxSize;
			eventTypesString ~= t.fieldNames[0] ~ ", ";
		}

		import std.conv;
		string minSizeStr = minSize.to!string;
		string maxSizeStr = maxSize.to!string;

		string res = "struct " ~ system ~ "Events {\n";
		res ~= "  import std.experimental.allocator.building_blocks.free_list;\n";
		res ~= "  import std.experimental.allocator.gc_allocator;\n";
		res ~= "  import std.conv;\n";
		res ~= "  static FreeList!(GCAllocator, " ~ minSizeStr ~ ", " ~ maxSizeStr ~ ") _allocator;\n";
		res ~= "  alias EventTypes = AliasSeq!(" ~ eventTypesString ~ ");\n"; 
		res ~= "  static void dispose(Event e) { auto support = (cast(void*)e)[0 .. typeid(e).initializer().length]; destroy(e); _allocator.deallocate(support); }\n";
		string dispatchCode;
		foreach (t; T)
		{
			alias cls = t.Types[0];
			enum n = t.fieldNames[0];
			enum eventName = identifierToEventFieldName(n);
			res ~= "  static EventType " ~ eventName ~ ";\n";
			// res ~= "private static n[] _" ~ eventName ~ "Pool";
			res ~= "  static T create(T : " ~ n ~ ", Args...)(Args args) { void[] data = _allocator.allocate(typeid(T).initializer().length); auto e = emplace!(T)(data, args); debug e.name = \"" ~ n ~ "\"; e.type = " ~ eventName ~ "; e.disposeFunc = &dispose; return e; }\n";
			//res ~= "static EventType(T = " ~ n ~ ")() { return eventName; }";
			dispatchCode ~= "    } else if (t == " ~ eventName ~ ") {\n"
				"      static if (is(typeof(target.on" ~ n ~ ")))\n"
				"        return target.on" ~ n ~ "(cast(" ~ n ~ ")ev);\n"
				"      else\n"
				"        return EventUsed.no;\n";
		}
		res ~= "  static EventUsed dispatch(T)(T target, Event ev) {\n    auto t = ev.type;\n    if (false) {\n" ~ dispatchCode ~ "    } else return EventUsed.no;\n }\n";
		return res ~ "}\n";
	}

	// Generate fast lookup of event types for the system using e.g.
	// GUIEvents.onMouseOver
	// where system is GUI in this case.
	// pragma (msg, getEventTypesStructMembers!EventTypes);
	
	mixin(getEventTypesStructMembers!EventTypes);

	class EventRegistrant : IEventRegistrant
	{
		
		override @property string name() const pure nothrow @safe @nogc
		{
			return system; // mod.stringof;
		}

		override void register(EventManager mgr)
		{
			import std.conv;
			foreach (clsDesc; EventTypes)
			{
				alias cls = clsDesc.Types[0];
				enum n = clsDesc.fieldNames[0];
				enum eventName = identifierToEventFieldName(n); // toLower(n[0..1]) ~ n[1..$];
				//pragma(msg, "Register event " ~ system ~ ":" ~ eventName);
				EventType et = mgr.register(EventDescription(system, n));
				// cls.staticType = et;
				mixin(system ~ "Events." ~ eventName ~ " = et;");
			}
		}
	}

	shared static this ()
	{
		EventManager.addRegistrant(new EventRegistrant());
	}
}

/*
struct Type
{
	size_t id;
	ushort index;
}

struct TypeManager
{
	ushort[size_t] idToIndex;
	Type[] types;

	void InitType(TypeInfo_Class c)
	{
		auto entry = c.toHash() in idToIndex;
		if (entry is null)
		{
			types ~= Type(c.toHash(), types.length);
			idToIndex[c.toHash()] = types.length - 1;
		}
	}
}

ushort TypeIndex(T)()
{
	auto idx = TypeManager.idToIndex[typeid(T).toHash()];
	return idx;
}

shared static this ()
{
	import std.stdio;
	writeln("All classes");
	foreach (m; ModuleInfo)
	{
		auto clss = m.localClasses;
		foreach (cls; clss)
		{
			writeln("  " ~ cls.name ~ " ", cls.toHash());
		}
	}
}
*/

// Core events are in this module itself ie. TimeoutEvent and QuitEvent
mixin registerEvents!"Core";

class EventManager
{
	@property const(EventDescription)[] eventDescriptions()
	{
		return _eventDescriptions;
	}
	
	this()
	{
		auto ed = register(EventDescription("Builtin", "Invalid"));
		assert(ed == Event.invalidType);
	}

	static void addRegistrant(IEventRegistrant r)
	{
		_eventRegistrants ~= r;
	}

	void activateRegistrants()
	{
		foreach (r; _eventRegistrants)
		{
			r.register(this);
		}
	}

	void activateRegistrantBySystemName(string systemName)
	{
		foreach (r; _eventRegistrants)
		{
			if (r.name == systemName)
			{
				r.register(this);
				break;
			}
		}
	}

	EventType register(EventDescription d)
	{
		import std.exception;
		import std.stdio;
		writeln("Event register " ~ d.system ~ "." ~ d.name);
		enforce(_eventDescriptions.length < EventType.max);
		_eventDescriptions ~= d;
		return cast(EventType) (_eventDescriptions.length - 1);
	}

	EventType lookup(string name)
	{
		foreach (i, d; _eventDescriptions)
			if (d.name == name)
				return cast(EventType)i;
		return Event.invalidType;
	}
	
	EventDescription[] _eventDescriptions;
	static IEventRegistrant[] _eventRegistrants;
}

alias EventOutputRange = MainEventSource.OutputRange;

/** Contains event sources and lets you listen or wait for events using
	an input range interface.

	All threads can put() events to this source. A specific implementation
	of this abstract class should poll OS for events and this base class will
	take care of waking up the main thread when Events are put from other threads.

	Examples of a class deriving from this class could be 
	SDLMainEventSource or GLFWMainEventSource.
*/
abstract class MainEventSource
{
	import core.thread;
	import core.time;
	import std.exception : enforce;

	this() 
	{
		_timeout = Duration.max;
		_ownerThreadID = Thread.getThis().id;
		_ownerQueue = new typeof(_ownerQueue)(256);
		_isListening = true;
		_currentEvent = null;
		_eventBuffer = null; // Single event for peeking for events to combine
	}

	final @property Duration timeout() const pure nothrow @system @nogc   
	{
		return _timeout;
	}

	final @property void timeout(Duration d)  
	{
		enforce(!d.isNegative);
		_timeout = d;
	}

	final @property bool stopped() @nogc nothrow @safe const 
	{
		return !_isListening;
	}

	final @property void timeout(double d)  
	{
		long nanoSecs = cast(long) (d * 1_000_000_000);
		timeout = dur!"nsecs"(nanoSecs);
	}

	// Stop getting events into the internal event queue and simply let anyone empty the
	// internal event queue if they want.
	void stop() 
	{
		_isListening = false;
	}

	final bool nextWillBlock()
	{
		bool result = false;
		if (!stopped && _currentEvent is null && _eventBuffer is null && ownerQueue.empty && _threadQueue.empty)
		{
			size_t idx;
			Event res = nextTimeoutEvent(idx);
			if (res !is null)
			{
				auto dt = res.timestamp - Clock.currTime;
				result = dt > dur!"hnsecs"(0);
			}
			else
			{
				_currentEvent = poll(dur!"hnsecs"(0));
				result = _currentEvent is null;
			}
		}
		return result;
	}

	final @property bool empty() 
	{
		enforce(Thread.getThis().id == _ownerThreadID);
		return _currentEvent is null && stopped;
	}
		
	final @property Event front() 
	{
		enforce(Thread.getThis().id == _ownerThreadID);
		if (_currentEvent is null)
		{
			Event next = _eventBuffer;
			_eventBuffer = null;

			if (next is null)
				next = _front(false);
			
			immutable allowCombine = next.allowCombine;

			while (allowCombine && !nextWillBlock())
			{
				// _currentEvent may have beem set by nextWillBlock
				_eventBuffer = _currentEvent is null ? _front(false) : _currentEvent;
				_currentEvent = null;
				if (next.combineIntoThis(_eventBuffer))
				{
					_eventBuffer.dispose();
					_eventBuffer = null;
				}
				else
				{
					break;
				}
			}

			_currentEvent = next;
		}
		return _currentEvent;
	}

	final void popFront() 
	{
		enforce(Thread.getThis().id == _ownerThreadID);
		assert(_currentEvent !is null);
		_currentEvent = null;
	}

	final bool putAsOwnerThreadIfRoom(Event ev) @nogc
	{
		if (stopped)
			return false; 

		// assert(Thread.getThis().id == _ownerThreadID);
		_ownerQueue.enqueueIfRoom(ev);
		return true;
	}

	// owning thread will take over ownership of event
	final bool put(Event ev) 
	{
		if (stopped)
			return false; 

		if (Thread.getThis().id == _ownerThreadID)
		{
			ownerQueue.enqueue(ev);
		}
		else
		{
			_threadQueue.pushBusyWait(cast(shared)ev);
			signalEventQueuedByOtherThread();
		}
		return true;
	}

	struct OutputRange
	{
		private shared(MainEventSource) _eventSource;
		
		private MainEventSource eventSource() @nogc { return cast(MainEventSource) _eventSource; }

		bool put(Event ev)
		{
			return eventSource.put(ev);
		}

		bool putAsOwnerThreadIfRoom(Event ev) @nogc
		{
			return eventSource.putAsOwnerThreadIfRoom(ev);
		}

		shared(TimeoutEvent) scheduleTimeoutNow(Variant userData = Variant.init)
		{
			return scheduleTimeout(dur!"hnsecs"(0), userData);
		}

		shared(TimeoutEvent) scheduleTimeout(Duration dt, Variant userData = Variant.init)
		{
			return eventSource.scheduleTimeout(dt, userData);
		}

		bool abortTimeout(shared(TimeoutEvent) scheduledTimeoutEvent) 
		{
			return eventSource.abortTimeout(scheduledTimeoutEvent);
		}
	}

	@property OutputRange sink()
	{
		return OutputRange(cast(shared)this);
	}

	// Thread safe
	final shared(TimeoutEvent) scheduleTimeoutNow(Variant userData = Variant.init)
	{
		return scheduleTimeout(dur!"hnsecs"(0), userData);
	}
	
	// Thread safe
	final shared(TimeoutEvent) scheduleTimeout(Duration dt, Variant userData = Variant.init)
	{
		auto e = CoreEvents.create!TimeoutEvent(false);
		e.timestamp = Clock.currTime + dt;
		e.userData = userData;

		if (Thread.getThis().id == _ownerThreadID)
		{
			pendingTimeouts ~= cast(shared) e;
		}
		else
		{
			put(e);
		}
		return cast(shared) e;
	}

	// Thread safe
    final bool abortTimeout(shared(TimeoutEvent) scheduledTimeoutEvent) 
    {
		if (Thread.getThis().id == _ownerThreadID)
		{
			return abortTimeoutInOwnerThread(scheduledTimeoutEvent);
		}
		else
		{
			// Tell main thread to abort the timeout
			scheduledTimeoutEvent.aborted = true;
			_threadQueue.pushBusyWait(scheduledTimeoutEvent);
			signalEventQueuedByOtherThread();
			return true;
		}
    }

protected:
	// A timeout should always put a TimeoutEvent on the queue
	abstract Event poll(Duration timeout_);

	// Called by other threads that just called put(event) on 
	// us in order to wake us up and handle the event.
	abstract void signalEventQueuedByOtherThread();

	// non shared access to the owner queue because it is only owner thread that access it
	final @property Queue!Event ownerQueue()
	{
		return cast(Queue!Event) _ownerQueue;
	}

private:
	import dccore.container;
	import util.queue;


	// non shared access to the owner queue because it is only owner thread that access it
	@property ref shared(TimeoutEvent)[] pendingTimeouts()
	{
		return cast(shared(TimeoutEvent)[]) _pendingTimeouts;
	}

    final bool abortTimeoutInOwnerThread(shared(TimeoutEvent) scheduledTimeoutEvent)
	{
		for (size_t i = _pendingTimeouts.length; i > 0; --i)
		{
			size_t idx = i - 1;

			// Comparing addresses of TimeoutEvents since comparing shared ones doesn't work
			if (cast(TimeoutEvent)_pendingTimeouts[idx] == cast(TimeoutEvent)scheduledTimeoutEvent)
			{
				(cast(TimeoutEvent) scheduledTimeoutEvent).dispose();
					// Remove from list.
				if (_pendingTimeouts.length > 1)
					_pendingTimeouts[idx] = _pendingTimeouts[$-1];
				_pendingTimeouts.length -= 1;
				assumeSafeAppend(pendingTimeouts);
				return true;
			}
		}
		return false;
	}

	final Event _front(bool isRetry)
	{
		if (!ownerQueue.empty)
			return ownerQueue.dequeue();

		while (!_threadQueue.empty)
		{
			auto e = _threadQueue.pop();
			if (e.type == CoreEvents.timeout)
			{
				//import std.stdio;
				//writeln(cast(Event)e, " ", e.type, " ", CoreEvents.timeout);
				//stdout.flush();
				auto toe = cast(shared(TimeoutEvent)) e; 
				assert(toe !is null);
				if (toe.aborted)
				{
					abortTimeoutInOwnerThread(toe);
				}
				else
				{
					// Just put this TimeoutEvent in the timeout array
					// Ok to cast shared away here because at this point this
					// thread owns this event.
					auto ts = (cast(Event)e).timestamp;
					if (ts <= Clock.currTime)
						return cast(Event) e;
				
					pendingTimeouts ~= cast(shared(TimeoutEvent))e;
				}
				isRetry = false;
			}
			else
			{
				return cast(Event) e; // cast away shared and take ownership
			}
		}

		// Handle timeout event queue
		size_t idx;
		Event res = nextTimeoutEvent(idx);

		Duration nextTimeout = _timeout;
		if (res !is null)
		{
			auto dt = res.timestamp - Clock.currTime;
			if (dt <= dur!"hnsecs"(0))
			{
				// Got a timeout
				if (_pendingTimeouts.length > 1)
					_pendingTimeouts[idx] = _pendingTimeouts[$-1];
				_pendingTimeouts.length = _pendingTimeouts.length - 1;
				assumeSafeAppend(_pendingTimeouts);
				return res;
			}

			if (dt < nextTimeout)
				nextTimeout = dt;
		}

		if (stopped)
			return null;
		
		// In case of a retry there should always be an even in a queue since
		// the poll has returned. 
		assert(!isRetry);
		
		res = poll(nextTimeout);
		if (res !is null)
		{
			res.timestamp = Clock.currTime;

			return res;
		}

		// second chance to handle events posted from other threads
		// or timeout events ready after the poll timeout
		return _front(true); 
	}

	final Event nextTimeoutEvent(ref size_t idxOut)
	{
		idxOut = 0;
		Event res = null;
		foreach (i, e; _pendingTimeouts)
		{
			auto ev = cast(Event)e;
			if (res is null || res.timestamp > e.timestamp)
			{
				res = ev;
				idxOut = i;
			}
		}
		return res;
	}

	shared(TimeoutEvent)[] _pendingTimeouts;

	Event _currentEvent;
	Event _eventBuffer;
	
	Duration _timeout;
	bool _isListening;
	ThreadID _ownerThreadID;	
	Queue!Event _ownerQueue;    // Events put from the owner queue
	shared RWQueue!Event _threadQueue; // Event put from other threads
}

version (unittest)
{
	import test;
	import std.algorithm;
	import std.array;
	import std.concurrency;
	import std.range;
	import std.stdio;

	abstract class EvBase : Event
	{
		int source = 0;
	}

	class Ev1a : EvBase {  } // Directly put from owner thread
	class Ev1b : EvBase {  } // Put through poll by owner thread
	class Ev2 : EvBase {   }  // Put by other thread

	struct Fixture
	{
		class ES : MainEventSource
		{
			this() 
			{
				_globalTid = thisTid;
				_mainTid = spawn(&mainSource, thisTid);
				_otherTid = spawn(&otherSource, thisTid, cast(shared)this);
			}

			@property Tid mainTid() { return cast(Tid)_mainTid; }
			@property Tid globalTid() { return cast(Tid)_globalTid; }
			@property Tid otherTid() { return cast(Tid)_otherTid; }

			void fakeMainEvent(Event e)
			{
				mainTid.send(cast(immutable(EvBase))e);
			}

			void fakeOtherEvent(Event e)
			{
				otherTid.send(cast(immutable(EvBase))e);
			}

			override void stop()
			{
				super.stop();
				mainTid.send(true);
				otherTid.send(true);

				// Get all signals not collected
				while (receiveTimeout(Duration.zero,
							   (bool sig) {
							   }
							   )) {}
			}

			override Event poll(Duration timeout_)
			{
				import core.time;
				Event pollEvent = null;

				bool gotSome = 
					receiveTimeout(timeout_,
						(immutable(Event) ev) { 
							pollEvent = cast(EvBase)ev;
							pollEvent.source = 1;
						},
						(bool sig) {
						}
						);
				
				return pollEvent;
			}

			override void signalEventQueuedByOtherThread()
			{
				globalTid.send(true);
			}

			bool woken;
			Tid _globalTid;
			Tid _mainTid;
			Tid _otherTid;
		}

		static void mainSource(Tid mainThreadTid)
		{
			// fake something like SDL_Poll here
			bool run = true;
			while (run)
			{
				receive((immutable(Event) ev)
							  {
								  mainThreadTid.send(ev);
							  },
						(bool sig) {
							run  = false;
						});
			}
		}

		static void otherSource(Tid mainThreadTid, shared(ES) es)
		{
			ES es2 = cast(ES)es;
			// fake something like libasync here
			bool run = true;
			while (run)
			{
				receive((immutable(Event) e) {
						auto ev = cast(EvBase)e;
						ev.source = 2;
						es2.sink.put(ev);
					},
					(bool sig) {
						run  = false;
					});
			}
		}
	}

EventManager mgr;
shared static this()
{
	mgr = new EventManager();
	mgr.activateRegistrantBySystemName("Core");
}

}

// Empty source works
unittest
{
	auto fes = new Fixture.ES();
	fes.stop();
	Assert(fes.empty);
}

// Timeout source works
unittest
{
	auto fes = new Fixture.ES();
	fes.timeout = 0.0;
	Assert(!fes.empty);
	auto e = fes.front;
	Assert(cast(TimeoutEvent)e !is null);
	fes.stop();
}

// Local put works
unittest
{
	auto fes = new Fixture.ES();
	auto e = new Ev1a;
	fes.put(e);
	Assert(!fes.empty);
	AssertRangesEqual(only(e), fes.take(1).array);
	fes.stop();
}

// Main thread put works with poll
unittest
{
	auto fes = new Fixture.ES();
	auto e = new Ev1b;
	Assert(!fes.empty);
	fes.fakeMainEvent(e);
	auto arr = fes.take(1).array;
	fes.stop();
	AssertRangesEqual(only(e), arr);
	Assert((cast(EvBase)arr[0]).source == 1);
}

// Main thread put works with poll multi
unittest
{
	auto fes = new Fixture.ES();
	auto e = new Ev1b;
	Assert(!fes.empty);
	fes.fakeMainEvent(e);
	fes.fakeMainEvent(e);
	fes.fakeMainEvent(e);
	auto arr = fes.take(3).array;
	fes.stop();
	AssertRangesEqual(only(e,e,e), arr);
	Assert((cast(EvBase)arr[0]).source == 1);
}

// Other thread put works with poll
unittest
{
	auto fes = new Fixture.ES();
	auto e = new Ev2;
	assert(!fes.empty);
	fes.fakeOtherEvent(e);
	auto arr = fes.take(1).array;
	fes.stop();
	AssertRangesEqual(only(e), arr);
	Assert((cast(EvBase)arr[0]).source == 2);
}

// Other thread put works with poll multi
unittest
{
	auto fes = new Fixture.ES();
	auto e = new Ev2;
	Assert(!fes.empty);
	fes.fakeOtherEvent(e);
	fes.fakeOtherEvent(e);
	fes.fakeOtherEvent(e);
	auto arr = fes.take(3).array;
	fes.stop();
	AssertRangesEqual(only(e,e,e), arr);
	Assert((cast(EvBase)arr[0]).source == 2);
}

// Mixed thread put works with poll multi
unittest
{
	import std.algorithm;
	auto fes = new Fixture.ES();
	auto e1a = new Ev1a;
	auto e1b = new Ev1b;
	auto e2 = new Ev2;
	Assert(!fes.empty);
	fes.fakeOtherEvent(e2);
	fes.fakeMainEvent(e1b);
	fes.fakeOtherEvent(e2);
	fes.put(e1a);
	fes.fakeMainEvent(e1b);
	fes.fakeOtherEvent(e2);
	auto arr = fes.take(6).array.sort!("a.toHash() < b.toHash()");
	fes.stop();

	// First all put events, then all main thread events, then other thread events
	AssertRangesEqual(only(e1a,e1b,e1b,e2,e2,e2).array.sort!("a.toHash() < b.toHash()") , arr);
}

// Timeout work
unittest
{
	auto fes = new Fixture.ES();
	auto e = new Ev2;
	Assert(!fes.empty);
	import std.variant;
	import core.time;

	auto timeoutEv = fes.scheduleTimeout(dur!"msecs"(100), Variant(42));
	auto arr = fes.take(1).array;
	fes.stop();
	Assert( (cast(TimeoutEvent)timeoutEv).userData.get!int, 42, "scheduleTimeout");
	//AssertRangesEqual(only(cast(TimeoutEvent)timeoutEv), arr);
}

unittest
{
	import std.algorithm;
	static bool cmp(EventDescription a, EventDescription b)
	{
		return a.system < b.system || ( a.system == b.system && a.name < b.name); 
	}

	auto expectedNames = ["Ev1a", "Ev1b", "Ev2", "QuitEvent", "TimeoutEvent"]; 

	AssertRangesEqual(expectedNames, 
				mgr.eventDescriptions.dup.remove!(a => a.name == "Invalid").sort!cmp.array.map!(a=>a.name));

	Assert(CoreEvents.ev2, mgr.lookup("Ev2")); 
}	
