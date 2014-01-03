module animation.mutator;

import std.stdio;
import std.traits;
import std.string;

class MutateException : Exception
{
	this(string msg)
	{
		super(msg);
	}
}


template countIt(T...)
{
	static if (T.length == 1)
		enum countIt = 1;
	else
		enum countIt = 1 + countIt!(T[1..$]);
}

template countOverloads(C, string name)
{
	enum countOverloads = countIt!(__traits(getOverloads, C, name));
}

/*
template isWritableProperty(C, Funcs...)
{
	static if (Funcs.length == 0)
		enum isWritableProperty = false;
	else
		enum isWritableProperty = (isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && 
		                           (ParameterIdentifierTuple!(Funcs[0]).length == 1) || (functionAttributes!(Funcs[0]) & FunctionAttribute.ref_))
			|| isWritableProperty!(C, Funcs[1..$]);
}
*/

template isWritableProperty(C, Funcs...)
{
	static if (Funcs.length == 0)
		enum isWritableProperty = false;
	else static if (Funcs.length == 1)
		enum isWritableProperty = (isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && 
		                           (ParameterIdentifierTuple!(Funcs[0]).length == 1) || (functionAttributes!(Funcs[0]) & FunctionAttribute.ref_));
	else static if (Funcs.length == 2)
		enum isWritableProperty = 
			(isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && 
				(ParameterIdentifierTuple!(Funcs[0]).length == 1) || (functionAttributes!(Funcs[0]) & FunctionAttribute.ref_)) ||
			(isCallable!(Funcs[1]) && (functionAttributes!(Funcs[1]) & FunctionAttribute.property) && 
				(ParameterIdentifierTuple!(Funcs[1]).length == 1) || (functionAttributes!(Funcs[1]) & FunctionAttribute.ref_));
	else static if (Funcs.length == 3)
		enum isWritableProperty = 
			(isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && 
			 (ParameterIdentifierTuple!(Funcs[0]).length == 1) || (functionAttributes!(Funcs[0]) & FunctionAttribute.ref_)) ||
			(isCallable!(Funcs[1]) && (functionAttributes!(Funcs[1]) & FunctionAttribute.property) && 
			 (ParameterIdentifierTuple!(Funcs[1]).length == 1) || (functionAttributes!(Funcs[1]) & FunctionAttribute.ref_)) ||
			(isCallable!(Funcs[2]) && (functionAttributes!(Funcs[2]) & FunctionAttribute.property) && 
			 (ParameterIdentifierTuple!(Funcs[2]).length == 1) || (functionAttributes!(Funcs[2]) & FunctionAttribute.ref_));
	else static if (Funcs.length == 4)
		enum isWritableProperty = 
			(isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && 
			 (ParameterIdentifierTuple!(Funcs[0]).length == 1) || (functionAttributes!(Funcs[0]) & FunctionAttribute.ref_)) ||
			(isCallable!(Funcs[1]) && (functionAttributes!(Funcs[1]) & FunctionAttribute.property) && 
			 (ParameterIdentifierTuple!(Funcs[1]).length == 1) || (functionAttributes!(Funcs[1]) & FunctionAttribute.ref_)) ||
			(isCallable!(Funcs[2]) && (functionAttributes!(Funcs[2]) & FunctionAttribute.property) && 
			 (ParameterIdentifierTuple!(Funcs[2]).length == 1) || (functionAttributes!(Funcs[2]) & FunctionAttribute.ref_)) ||
			(isCallable!(Funcs[3]) && (functionAttributes!(Funcs[3]) & FunctionAttribute.property) && 
			 (ParameterIdentifierTuple!(Funcs[3]).length == 1) || (functionAttributes!(Funcs[3]) & FunctionAttribute.ref_));
}

template isWritableProperty(C, string name)
{
	enum isWritableProperty = isWritableProperty!(C, __traits(getOverloads, C, name));
}

template isLValueProperty(C, Funcs...)
{
	static if (Funcs.length == 0)
		enum isLValueProperty = false;
	else
		enum isLValueProperty = (isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && 
		                           ParameterIdentifierTuple!(Funcs[0]).length == 0 && functionAttributes!(Funcs[0]) & FunctionAttribute.ref_)
			|| isLValueProperty!(C, Funcs[1..$]);
}

template isLValueProperty(C, string name)
{
	enum isLValueProperty = isLValueProperty!(C, __traits(getOverloads, C, name));
}

template isWritableNonProperty(C, string name)
{
	static if (hasMember!(C, name))
		enum isWritableNonProperty = !isCallable!(mixin("C." ~ name)); // && __traits(isPOD, typeof(mixin("C." ~ name)) );
	else
		enum isWritableNonProperty = false;
}
/*
template isReadableProperty(C, Funcs...) 
{
	// TODO: fix when type tuple slicing works again in dmd	
	static if (Funcs.length == 0)
		enum isReadableProperty = false;
	else
		enum isReadableProperty = (isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[0]).length == 0) || isReadableProperty!(C, Funcs[1..$]);
}
*/

// TODO: fix when type tuple slicing works again in dmd	
/*
enum isReadableProperty(C, Funcs...) = 
	(isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[0]).length == 0) || 
	(Funcs.length >= 2 ? (isCallable!(Funcs[1]) && (functionAttributes!(Funcs[1]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[1]).length == 0) : false) ||
	(Funcs.length >= 3 ? (isCallable!(Funcs[2]) && (functionAttributes!(Funcs[2]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[2]).length == 0) : false) ||
	(Funcs.length >= 4 ? (isCallable!(Funcs[3]) && (functionAttributes!(Funcs[3]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[3]).length == 0) : false);
*/

template isReadableProperty(C, Funcs...) 
{
	static if (Funcs.length == 0)
		enum isReadableProperty = false;
	else static if (Funcs.length == 1)
		enum isReadableProperty = (isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[0]).length == 0);
	else static if (Funcs.length == 2)
		enum isReadableProperty = (isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[0]).length == 0) || 
			(isCallable!(Funcs[1]) && (functionAttributes!(Funcs[1]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[1]).length == 0);
	else static if (Funcs.length == 3)
		enum isReadableProperty = (isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[0]).length == 0) || 
			(isCallable!(Funcs[1]) && (functionAttributes!(Funcs[1]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[1]).length == 0) ||
			(isCallable!(Funcs[2]) && (functionAttributes!(Funcs[2]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[2]).length == 0);
	else static if (Funcs.length == 3)
		enum isReadableProperty = (isCallable!(Funcs[0]) && (functionAttributes!(Funcs[0]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[0]).length == 0) || 
			(isCallable!(Funcs[1]) && (functionAttributes!(Funcs[1]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[1]).length == 0) ||
			(isCallable!(Funcs[2]) && (functionAttributes!(Funcs[2]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[2]).length == 0) ||
			(isCallable!(Funcs[3]) && (functionAttributes!(Funcs[3]) & FunctionAttribute.property) && ParameterIdentifierTuple!(Funcs[3]).length == 0);
}

template isReadableProperty(C, string name)
{
	static if (hasMember!(C, name))
		enum isReadableProperty = isReadableProperty!(C, __traits(getOverloads, C, name));
	else	
		enum isReadableProperty = false;
}

template isReadableNonProperty(C, string name)
{
	static if (hasMember!(C, name))
		enum isReadableNonProperty = !isCallable!(mixin("C." ~ name)); //  && __traits(isPOD, typeof(mixin("C." ~ name)) );
	else
		enum isReadableNonProperty = false;
}

template isMemberReadableHelper(C, string member)
{
	enum isMemberReadableHelper = isReadableProperty!(C, member) || isReadableNonProperty!(C, member);
}

template isMemberReadable(C, string path)
{
	enum fields = std.array.split(path, ".");
	static if (fields.length == 1)
		enum isMemberReadable = isMemberReadableHelper!(C, fields[0]);
	else
		enum isMemberReadable = isMemberReadableHelper!(C, fields[0]) && isMemberReadable!(typeof(mixin("C."~fields[0])), std.array.join(fields[1..$], "."));
}


template isMemberWritableHelper(C, string member)
{
	enum isMemberWritableHelper = isWritableProperty!(C, member) || isWritableNonProperty!(C, member);
}

template isMemberLValueHelper(C, string member)
{
	enum isMemberLValueHelper = isLValueProperty!(C, member) || isWritableNonProperty!(C, member);
}

template isMemberWritable(C, string path)
{
	enum fields = std.array.split(path, ".");
	static if (fields.length == 1)
		enum isMemberWritable = isMemberWritableHelper!(C, fields[0]);
	else
		enum isMemberWritable = isMemberLValueHelper!(C, fields[0]) && isMemberWritable!(typeof(mixin("C."~fields[0])), std.array.join(fields[1..$], "."));
}
/*
unittest 
{
	return;
	class A {
		int bar;
		@property int bara() { return 1; }
	}

	class D {
		A food;
		void foo(float) {}
		@property void foo(int) {} 
		@property void foo() {}
		@property A foo1() { return food;}
		@property void foo1(A a) { }
	}

	enum doHaveOne1 = isWritableProperty!(D, "foo");	
	enum doHaveOne2 = isReadableProperty!(D, "foo");	
	std.stdio.writeln(isMemberReadable!(D, "foo1.bar"), " ", isMemberWritable!(D, "foo1.bar"));
}
*/
class Mutator 
{
}

class DirectFieldMutator(string field, OwnerType) : Mutator
{
	OwnerType owner;
	mixin("alias typeof(OwnerType." ~ field ~ ")  FieldType;");

	this(ref OwnerType owner)
	{
		this.owner = owner;
	}

	@property FieldType value()
	{
		static if (isMemberReadable!(OwnerType, field))
			return mixin("owner." ~ field);
		else
			throw new MutateException(format("Field '%s' not readable", field)); // runtime error
	}

	void opAssign(FieldType value)
	{
		// Ignore op assign if field is readonly
		enum fun = "owner." ~ field;
		static if ( isMemberWritable!(OwnerType, field))
			mixin("owner." ~ field ~ " = value;");
		else
			throw new MutateException(format("Field '%s' not modifiable using =", field)); // runtime error
	}

	void opOpAssign(string op)(FieldType value)
	{
		enum opopassign = "owner." ~ field ~ " " ~ op ~ "= value;";
		enum opassign_opbinary = "owner." ~ field ~ " = owner." ~ field ~ " " ~ op ~ " value;";
		static if (__traits(compiles, mixin(opopassign)))
			mixin(opopassign); // if op= is present on value
		else static if (isMemberReadable!(OwnerType, field) && isMemberWritable!(OwnerType, field))
			mixin(opassign_opbinary);
		else
			throw new MutateException(format("Field '%s' not modifiable using %s=", field, op)); // runtime error
	}
}

auto mutator(alias field, OwnerType)(ref OwnerType s)
{
	return new DirectFieldMutator!(field, OwnerType)(s);
}
/*
unittest
{
	return;
	import std.stdio;
	import std.string;

	void Assert(T)(string desc, T result, T expected)
	{
		writeln(leftJustify(desc, 25), ": ", result, " == ", expected, " ", result == expected ? "OK" : "FAILED");
	}

	struct MyStruct 
	{ 
		int field1; 

		@property int theField1()
		{
			return field1;
		}

		@property void theField1(int v)
		{
			field1 = v;
		}

		@property int theField1ReadOnly()
		{
			return field1;
		}

		@property void theField1writeOnly(int v)
		{
			field1 = v;
		}
	}

	MyStruct s = { 42 };

	Assert("Struct base ", s.field1, 42);

	{
		auto sm = mutator!"field1"(s);
		sm = 43;
		Assert("Struct field '=' ", s.field1, 43);
		sm += 1;
		Assert("Struct field '+=' ", s.field1, 44);
	}

	{
		auto smproprw = mutator!"theField1"(s);
		smproprw = 45;
		Assert("Struct rw property '=' ", s.field1, 45);
		smproprw += 1;
		Assert("Struct rw property '+=' ", s.field1, 46);
	}

	{
		auto smpropro = mutator!"theField1ReadOnly"(s);
		smpropro = 123;
		Assert("Struct ro property '=' ", s.field1, 46);
		smpropro += 1;
		Assert("Struct ro property '+=' ", s.field1, 46);
	}

	auto smpropro = mutator!"theField1"(s);
	auto smpropwo = mutator!"theField1"(s);

	writeln(s.field1);

	class MyClass { int field1; MyStruct field2; }

	MyClass c = new MyClass();
	c.field1 = 42;
	c.field2 = MyStruct(100);

	auto cm = mutator!"field1"(c);
	auto cm2 = mutator!"field2"(c);
	auto cm3 = mutator!"field2.field1"(c);

	cm = 80;
	cm2 = MyStruct(200);

	writeln(c.field1);
	writeln(c.field2);
	cm3 = 1000;
	writeln(c.field2);
	cm3 += 1;
	writeln(c.field2);
	writeln(cm3.value);
	//assert(s.field1 == 43);
	//assert(c.field1 == 44);
}
*/
class ClassReflection
{
	string name;
	string[string] fields;
}

class DirectObjectMutator(ObjType) : Mutator
{
	mixin("alias ObjType Type;");
	Type object;

	static this()
	{
		// Since the type "Type" is mutated and possibly at runtime we
		// need to record reflection info for it here.
		
	}
	
	this(ref Type object)
	{
		this.object = object;
	}

	// Compile time fetch of field mutator
	// e.g. myMutateObj.foobar = 32;
	//
	auto opDispatch(string fieldName)()
	{
		return mutator!fieldName(this);
	}

	// Runtime fetch of field mutator
	// e.g. myMutateObj.getFieldMutator("foobar") = 32;
	//
	@property auto getFieldMutator(string fieldName)
	{
		return mutator!(this, fieldName);
	}

	void opAssign(FieldType value)
	{
		// Ignore op assign if field is readonly
		enum fun = "owner." ~ field;
		static if ( isMemberWritable!(OwnerType, field))
			mixin("owner." ~ field ~ " = value;");
		else
			throw new MutateException(format("Field '%s' not modifiable using =", field)); // runtime error
	}

	void opOpAssign(string op)(FieldType value)
	{
		enum opopassign = "owner." ~ field ~ " " ~ op ~ "= value;";
		enum opassign_opbinary = "owner." ~ field ~ " = owner." ~ field ~ " " ~ op ~ " value;";
		static if (__traits(compiles, mixin(opopassign)))
			mixin(opopassign); // if op= is present on value
		else static if (isMemberReadable!(OwnerType, field) && isMemberWritable!(OwnerType, field))
			mixin(opassign_opbinary);
		else
			throw new MutateException(format("Field '%s' not modifiable using %s=", field, op)); // runtime error
	}
}

auto mutator(Type)(ref Type s)
{
	return new DirectObjectMutator!OwnerType(s);
}
