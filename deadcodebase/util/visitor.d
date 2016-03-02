module edit.visitor;
version (none):
struct Persist {};

import dccore.attr;
import std.conv;
import std.range;
import std.stdio;
import std.traits;

import test;
mixin registerUnittests;

mixin template VisitImpl(UDA)
{
	final void visit(T)(T i)
	{
		static if (isAggregateType!T)
		{
			visitAggrBegin(i);
			if (i is null)
				return;

			foreach(memberName; __traits(allMembers, T))
			{
				static if (memberName != "this")
				{
					alias mem = helper!(__traits(getMember, i, memberName));

					static if (!isSomeFunction!mem && hasAttribute!(mem, UDA))
					{
						//pragma (msg, "Checking " ~ T.stringof ~ "." ~ memberName);
						visitMember!T(i, memberName, __traits(getMember, i, memberName));
						//static if (isAggregateType!(typeof(__traits(getMember, i, memberName))))
						//{
						//    if (__traits(getMember, i, memberName) !is null)
						//    {
						//        __traits(getMember, i, memberName).accept(this);
						//    }
						//}
					}
				}
			}
			visitAggrEnd(i);
		}
	}
}

// Test visitor that dumps to stdout a hierarchy with field that have a Persist UDA set.
class TestVisitor
{
	int _indent = 0;
	final private void indent()
	{
		foreach (l; 0.._indent)
			std.stdio.write(" ");
	}

	final void visitAggrBegin(T)(T i)
	{
		indent();
		writeln(T.stringof, " {");
		_indent += 2;
	}

	final void visitAggrEnd(T)(T i)
	{
		_indent -= 2;
		indent();
		writeln("}");
	}

	final void visitMember(AggrType, T)(Visitor v, AggrType aggr, string memberName, T memberValue)
	{
		// writeln("Visiting " ~ T.stringof ~ " " ~ AggrType.stringof ~ "." ~ memberName ~ " = ", memberValue);
		indent();

		static if (isAggregateType!T)
		{
			if (memberValue !is null)
			{
				writeln("Visiting " ~ T.stringof ~ " " ~ memberName ~ " = ");
				memberValue.accept(v);
			}
			else
			{
				writeln("Visiting " ~ T.stringof ~ " " ~ memberName ~ " = NULL!", memberValue);
			}
		}
		else static if (isArray!T)
		{
			writeln("Visiting array of ", typeof(memberValue[0]).stringof);
		}
		else
		{
			writeln("Visiting " ~ T.stringof ~ " " ~ memberName ~ " = ", memberValue);
		}
	}
}

// Visitor handler that writes all fields that have the @Persist set.
class ObjectTreeTextWriter(OutRange)
{
	import std.conv;
	alias void delegate() DelayedVisit;
	DelayedVisit[] delayedVisits;
	OutRange output;

	this(OutRange r)
	{
		output = r;
	}

	final void visitAggrBegin(T)(T i)
	{
		// writeln(T.classinfo.name, " ", cast(void*)i);
		output.put(T.classinfo.name);
		output.put(' ');
		output.put(i.toHash().to!string);
		output.put('\n');
	}

	final void visitAggrEnd(T)(T i)
	{
		output.put(".\n");
		while (delayedVisits.length)
		{
			auto d = delayedVisits[$-1];
			delayedVisits.length = delayedVisits.length - 1;
			d();
		}
	}

	final void visitMember(AggrType, T)(Visitor v, AggrType aggr, string memberName, T memberValue) if (isAggregateType!T)
	{
		// TODO: handle struct inline since they are value types
		output.put(memberName);
		output.put(" O ");

		if (memberValue !is null)
		{
			// writeln(T.classinfo.name, " ", cast(void*)memberValue);
			output.put(T.classinfo.name);
			output.put(" ");
			output.put(memberValue.toHash().to!string);
			output.put("\n");
			assumeSafeAppend(delayedVisits);
			delayedVisits ~= () { memberValue.accept(v); };
		}
		else
		{
			output.put(T.classinfo.name);
			output.put(" 0\n");
		}
	}

	final void visitMember(AggrType, T)(Visitor v, AggrType aggr, string memberName, T[] memberValue)
	{
		output.put(memberName);
		static if (isAggregateType!T)
		{
			output.put(" O");
			assumeSafeAppend(delayedVisits);
		}
		else
		{
			output.put(" P");
		}
		output.put("[");
		output.put(memberValue.length.to!string);
		output.put("] ");

		output.put(T.stringof);
		output.put("\n");

		foreach (item; memberValue)
		{
			static if (isAggregateType!T)
			{
				output.put(item.toHash().to!string);
				delayedVisits ~= () { item.accept(v); };
			}
			else
			{
				output.put(item.to!string);
			}
			output.put("\n");
		}
	}

	final void visitMember(AggrType, T)(Visitor v, AggrType aggr, string memberName, T memberValue) if ( ! isAggregateType!T && !isArray!T )
	{
		output.put(memberName);
		output.put(" P ");
		output.put(T.stringof);
		output.put(" ");
		output.put(memberValue.to!string);
		output.put("\n");
		// writeln("Visiting " ~ T.stringof ~ " " ~ memberName ~ " = ", memberValue);
	}
}

class Reflector2
{
	abstract @property string className() pure const nothrow @safe;

	T get(T)(Object o, string key)
	{
		auto typeInfo = typeid(T);

	}

	void set(T)(Object o, T v, string key)
	{
		auto typeInfo = typeid(T);

	}
}

class Reflector
{
	abstract @property string className() pure const nothrow @safe;

	abstract void set(Object o, string v, string key);
	abstract void set(Object o, int v, string key);
	abstract void set(Object o, uint v, string key);
	abstract void set(Object o, float v, string key);
	abstract void set(Object o, double v, string key);
	abstract void set(Object o, Object v, string key);

	abstract void set(Object o, string[] v, string key);
	abstract void set(Object o, int[] v, string key);
	abstract void set(Object o, uint[] v, string key);
	abstract void set(Object o, float[] v, string key);
	abstract void set(Object o, double[] v, string key);
	abstract void set(Object o, Object[] v, string key);

	abstract string get(Object o, string key);
	abstract int get(Object o, string key);
	abstract uint get(Object o, string key);
	abstract float get(Object o, string key);
	abstract double get(Object o, string key);
	abstract Object get(Object o, string key);

	abstract string[] get(Object o, string key);
	abstract int[] get(Object o, string key);
	abstract uint[] get(Object o, string key);
	abstract float[] get(Object o, string key);
	abstract double[] get(Object o, string key);
	abstract Object[] get(Object o, string key);
}

class ReflectorImpl(T) : Reflector
{
	import std.string;

	override @property string className() pure const nothrow @safe { return T.classinfo.name; }

	override void set(Object o, string v, string key) { setImpl(o, v, key); }
	override void set(Object o, int v, string key) { setImpl(o, v, key); }
	override void set(Object o, uint v, string key) { setImpl(o, v, key); }
	override void set(Object o, float v, string key) { setImpl(o, v, key); }
	override void set(Object o, double v, string key) { setImpl(o, v, key); }
	override void set(Object o, Object v, string key)
	{
		T obj = cast(T)o;
		foreach(memberName; __traits(allMembers, T))
		{
			//pragma(msg, memberName);
			static if (memberName != "this" && is(typeof(__traits(getMember, obj, memberName)) == class) )
			{
				if (memberName == key)
				{
					__traits(getMember, obj, memberName) = cast(typeof(__traits(getMember, obj, memberName))) v;
					return;
				}
			}
		}
		throw new Exception(format("Cannot set reflected non-existing field '%s' for class '%s'", key, T.stringof));
	}

	override void set(Object o, string[] v, string key) { setImpl(o, v, key); }
	override void set(Object o, int[] v, string key) { setImpl(o, v, key); }
	override void set(Object o, uint[] v, string key) { setImpl(o, v, key); }
	override void set(Object o, float[] v, string key) { setImpl(o, v, key); }
	override void set(Object o, double[] v, string key) { setImpl(o, v, key); }
	override void set(Object o, Object[] v, string key)
	{
		T obj = cast(T)o;
		foreach(memberName; __traits(allMembers, T))
		{
			//pragma(msg, memberName);
			static if (memberName != "this" && is(isArray!(typeof(__traits(getMember, obj, memberName)))) && is(typeof(__traits(getMember, obj, memberName)) == class) )
			{
				if (memberName == key)
				{
					typeof(__traits(getMember, obj, memberName)) res;
					res.reserve(v.length);
					foreach (item; v)
					{
						res ~= cast(typeof(__traits(getMember, obj, memberName)[0])) item;
					}
					__traits(getMember, obj, memberName) = res;
					return;
				}
			}
		}
		throw new Exception(format("Cannot set reflected non-existing field[] '%s' for class '%s'", key, T.stringof));
	}

	override string get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override int get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override uint get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override float get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override double get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override Object get(Object o, string key)
	{
		T obj = cast(T)o;
		foreach(memberName; __traits(allMembers, T))
		{
			static if (memberName != "this" && is(typeof(__traits(getMember, obj, memberName)) == class) )
			{
				if (memberName == key)
				{
					return __traits(getMember, obj, memberName);
				}
			}
		}
		throw new Exception(format("Cannot get non-existing reflected field '%s' for class '%s'", key, T.stringof));
	}

	override string[] get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override int[] get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override uint[] get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override float[] get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override double[] get(Object o, string key) { return getImpl!(typeof(return))(o, key); }
	override Object[] get(Object o, string key)
	{
		T obj = cast(T)o;
		foreach(memberName; __traits(allMembers, T))
		{
			static if (memberName != "this" && is(isArray!(typeof(__traits(getMember, obj, memberName)))) && is(typeof(__traits(getMember, obj, memberName)) == class) )
			{
				if (memberName == key)
				{
					Object[] res;
					res.reserve(__traits(getMember, obj, memberName).length);
					foreach (item; __traits(getMember, obj, memberName))
					{
						res ~= item;
					}
					return res;
				}
			}
		}
		throw new Exception(format("Cannot get non-existing reflected field[] '%s' for class '%s'", key, T.stringof));
	}

	private void setImpl(V)(Object o, V v, string key)
	{
		T obj = cast(T)o;
		foreach(memberName; __traits(allMembers, T))
		{
			//pragma(msg, memberName);
			static if (memberName != "this" && is(typeof(__traits(getMember, obj, memberName)) == V) )
			{
				if (memberName == key)
				{
					__traits(getMember, obj, memberName) = v;
					return;
				}
			}
		}
		throw new Exception(format("Cannot set reflected non-existing field '%s' for class '%s'", key, T.stringof));
	}

	private V getImpl(V)(Object o, string key)
	{
		T obj = cast(T)o;
		foreach(memberName; __traits(allMembers, T))
		{
			static if (memberName != "this" && is(typeof(__traits(getMember, obj, memberName)) == V) )
			{
				if (memberName == key)
				{
					return __traits(getMember, obj, memberName);
				}
			}
		}
		throw new Exception(format("Cannot get non-existing reflected field '%s' for class '%s'", key, T.stringof));
	}
}

static
{
	private Reflector[string] reflectors;

	void reflectClass(T)(T t = null)
	{
		reflectors[T.classinfo.name] = new ReflectorImpl!T();
	}

	Reflector getReflector(string r)
	{
		return reflectors.get(r, null);
	}
}

mixin template Reflect()
{
	static this()
	{
		reflectClass!(typeof(this))();
	}
	void accept(Visitor v) { v.visit(this); }
}

struct ReflectClass(T) if ( is( T == class ) )
{
	static this()
	{
		reflectClass!T();
	}
}

// Visitor handler that writes all fields that have the @Persist set.
class ObjectTreeTextReader(InputRange)
{
	InputRange input;
	Object[size_t] objectMap;

	struct RefPatchInfo
	{
		Object obj;
		string field;
		size_t id;    // the field is an ObjectX
		size_t[] ids; // the field is an ObjectX[]
	}

	RefPatchInfo[] postPatching;

	this(InputRange r)
	{
		input = r;
	}

	Object read()
	{
		import std.algorithm;
		auto lines = input.splitter('\n');
		while (!lines.empty)
		{
			if (lines.front.empty)
			{
				lines.popFront;
				continue;
			}
			readObject(lines);
		}

		size_t[size_t] patchedIDs; // a set
		foreach (pi; postPatching)
		{
			if (pi.id == 0)
			{
				patch(pi.obj, pi.field, pi.ids);
				foreach (i; pi.ids)
					patchedIDs[i] = i;
			}
			else
			{
				patch(pi.obj, pi.field, pi.id);
				patchedIDs[pi.id] = pi.id;
			}
		}

		foreach (p; patchedIDs)
		{
			objectMap.remove(p);
		}

		return objectMap.length ? objectMap[objectMap.keys[0]] : null;
	}

	private void patch(Object obj, string field, size_t id)
	{
		Reflector reflector = getReflector(obj.classinfo.name);
		Object fieldObj = objectMap.get(id, null);
		if (fieldObj is null)
			assert(0, "Field Object is null for field");
		reflector.set(obj, fieldObj, field);
	}

	private void patch(Object obj, string field, size_t[] ids)
	{
		Reflector reflector = getReflector(obj.classinfo.name);
		Object[] fieldObjs;
		fieldObjs.reserve(ids.length);
		foreach (id; ids)
		{
			Object fieldObj = objectMap.get(id, null);
			if (fieldObj is null)
				assert(0, "Field Object[] is null for field");
			fieldObjs ~= fieldObj;
		}
		reflector.set(obj, fieldObjs, field);
	}

	private void readObject(R)(ref R lines)
	{
		import std.string;
		import std.algorithm;


		auto typeAndID = lines.front.splitter(' ');
		string type = typeAndID.front;
		typeAndID.popFront;
		string ID = typeAndID.front;

		size_t id = ID.to!size_t();
		Object obj = Object.factory(type);
		objectMap[id] = obj;

		Reflector reflector = getReflector(type);

		lines.popFront;
		while (!lines.empty)
		{
			string line = lines.front;
			lines.popFront;
			if (line == ".")
				return;

			// Need to register a "reader" per class to handle derived types created by the factory above?
			auto toks = line.splitter(' ');
			string name = toks.front;
			toks.popFront;
			string fieldOrRef = toks.front;
			toks.popFront;
			string fieldType = toks.front;
			toks.popFront;

			if (fieldOrRef == "O")
			{
				string value = toks.front;
				size_t fieldObjID = value.to!size_t;
				if (fieldObjID != 0)
					postPatching ~= RefPatchInfo(obj, name, fieldObjID);
			}
			else if (fieldOrRef == "P")
			{
				string value = toks.front;
				switch (fieldType)
				{
					case "string":
						reflector.set(obj, value, name);
						break;
					case "int":
						reflector.set(obj, value.to!int, name);
						break;
					case "uint":
						reflector.set(obj, value.to!uint, name);
						break;
					case "float":
						reflector.set(obj, value.to!float, name);
						break;
					case "double":
						reflector.set(obj, value.to!double, name);
						break;
					default:
						assert(0, text("No such type '%s'", type));
						//break;
				}
			}
			else if (fieldOrRef[0..2] == "O[")
			{
				size_t num = fieldOrRef[2..$-1].to!size_t;
				readObjectArray(lines.takeExactly(num), obj, name);
				lines.popFrontN(num);
			}
			else if (fieldOrRef[0..2] == "P[")
			{
				size_t num = fieldOrRef[2..$-1].to!size_t;
				switch (fieldType)
				{
					case "string":
						reflector.set(obj, readPrimitiveArray!string(lines.takeExactly(num)), name);
						break;
					case "int":
						reflector.set(obj, readPrimitiveArray!int(lines.takeExactly(num)), name);
						break;
					case "uint":
						reflector.set(obj, readPrimitiveArray!uint(lines.takeExactly(num)), name);
						break;
					case "float":
						reflector.set(obj, readPrimitiveArray!float(lines.takeExactly(num)), name);
						break;
					case "double":
						reflector.set(obj, readPrimitiveArray!double(lines.takeExactly(num)), name);
						break;
					default:
						assert(0, text("No such type[] '%s'", type));
						//break;
				}
				lines.popFrontN(num);
			}
			else
			{
				assert(0, "Unknown field type");
			}
		}
	}

	private void readObjectArray(R)(R lines, Object obj, string name)
	{
		size_t[] r;
		r.reserve(lines.length);

		foreach (line; lines)
		{
			r ~= line.to!size_t;
		}
		postPatching ~= RefPatchInfo(obj, name, 0, r);
	}

	private ElementType[] readPrimitiveArray(ElementType, R)(R lines)
	{
		ElementType[] r;
		r.reserve(lines.length);

		foreach (line; lines)
			r ~= line.to!ElementType;
		return r;
	}

}

class StdoutRange
{
	void put(E)(E e)
	{
		import std.stdio;
		write(e);
	}
}

class Visitor
{
	mixin VisitImpl!Persist;
	import std.array;

	private TestVisitor testVisitor;
	private ObjectTreeTextWriter!StdoutRange testSerializeVisitor;
	private ObjectTreeTextWriter!(RefAppender!string) testSerializeVisitor2;

	final void setHandler(H)(H h)
	{
		testVisitor = null;
		testSerializeVisitor = null;
		static if (is(H : TestVisitor) )
			testVisitor = h;
		else static if (is(H : ObjectTreeTextWriter!StdoutRange))
			testSerializeVisitor = h;
		else static if (is(H : ObjectTreeTextWriter!(RefAppender!string)))
			testSerializeVisitor2 = h;
		else
			assert(0);
	}

	final void visitAggrBegin(T)(T i)
	{
		if (testVisitor !is null)
			testVisitor.visitAggrBegin(i);
		else if (testSerializeVisitor !is null)
			testSerializeVisitor.visitAggrBegin(i);
		else if (testSerializeVisitor2 !is null)
			testSerializeVisitor2.visitAggrBegin(i);
		else
			assert(0);
	}

	final void visitAggrEnd(T)(T i)
	{
		if (testVisitor !is null)
			testVisitor.visitAggrEnd(i);
		else if (testSerializeVisitor !is null)
			testSerializeVisitor.visitAggrEnd(i);
		else if (testSerializeVisitor2 !is null)
			testSerializeVisitor2.visitAggrEnd(i);
		else
			assert(0);
	}

	final void visitMember(AggrType, T)(AggrType aggr, string memberName, T memberValue)
	{
		if (testVisitor !is null)
			testVisitor.visitMember(this, aggr, memberName, memberValue);
		else if (testSerializeVisitor !is null)
			testSerializeVisitor.visitMember(this, aggr, memberName, memberValue);
		else if (testSerializeVisitor2 !is null)
			testSerializeVisitor2.visitMember(this, aggr, memberName, memberValue);
		else
			assert(0);
	}
}

//mixin template Visitable()
//{
//    void accept(TestVisitor v) { v.visit(this); }
//    void accept(TestSerializeVisitor v) { v.visit(this); }
//}

version (unittest)
{
	class Base
	{
		mixin Reflect;

		int id;

		@Persist int persisted;

		int notPersisted;

		@Persist Base persistedChild;
		Base notPersistedChild;

		@Persist int[] persistedArr;
	}

	class Derived : Base
	{
		//mixin Visitable;

		@Persist int persistedDerived;

		int notPersistedDerived;

		@Persist Base persistedChildThroughBase;

		override void accept(Visitor v) { v.visit(this); }
	}

	ReflectClass!Derived x;
}

unittest
{
	import std.stdio;
	writeln("Begin visiting");
	auto b = new Base();
	b.id = 1;
	auto c2 = new Derived();
	c2.id = 2;
	c2.persisted = 31;
	c2.persistedDerived = 32;

	auto d = new Derived();
	d.id = 3;
	d.persisted = 41;
	d.persistedDerived = 42;
	d.persistedChild = b;
	d.persistedChildThroughBase = c2;
	d.persistedArr = [1,2,3,4,5];

	auto visitor = new Visitor();
	visitor.setHandler(new TestVisitor());
	d.accept(visitor);

	visitor.setHandler(new ObjectTreeTextWriter!StdoutRange(new StdoutRange));
	d.accept(visitor);
	// v.visit(d);

	import std.array;
	string data;
	RefAppender!string output = appender(&data);
	visitor.setHandler(new ObjectTreeTextWriter!(RefAppender!string)(output));
	d.accept(visitor);
	auto extra = new Derived();
	extra.accept(visitor);

	import std.stdio;
	writeln("String version");
	writeln(output.data);
	auto reader = new ObjectTreeTextReader!string(output.data);
	writeln("Reading...");
	auto readObj = cast(Base) reader.read();

	visitor.setHandler(new TestVisitor());
	readObj.accept(visitor);

	writeln("Done visiting ", reader.objectMap.keys);

	auto dd = new Derived();
	dd.id = 4;
    Object bb = dd;
	writeln("XXX1 ", bb.classinfo.name);
	writeln("XXX2 ", bb.tupleof);
	writeln("XXX3 ", (new Derived()).tupleof);

	/*
	class A
	{
		void func(T)(T v)
		{
			writeln("A::func ", v);
		}
	}

	class B : A
	{
		override void func(T)(T v)
		{
			writeln("B::func ", v);
		}
	}

	B bb = new B;
	bb.func(42);
	A aa = bb;
	aa.func(42);
	aa.func("Fda");
	*/
}
