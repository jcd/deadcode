module gui.resources.generic;

import dccore.path;


import gui.locations;
import gui.resource;

import io.iomanager;

import util.jsonx;

import std.array;

import std.variant;

/** Persisting of objects

	Different fields needs to be persisted in different situations.
	A class implementing the IPersister interface is used to persist
	in one of these situations. A class or struct implementing the persist()
	method or tagging its fields can tell the IPersister about features
	of its fields and on that basis the IPersister can determine how to handle
	the field.

	In general the order of getting and setting must be the same. Some persisters
	does not mandate this though.

	Example:
	---
struct Foo
{
	int cachedData;
	string persistMe;

	void persist(IPersister p)
	{
		p.set("The-persisted-me", persistMe);
	}
}

struct Bar
{
	int cachedData;
	@persist string persistMe;
}

auto foo = new Foo;
auto bar = new Bar;
auto persister = new VariantPersister(); // will persist into a variant
persister.set("foo", foo);
persister.set("bar", bar);

auto fooGet = new Foo;
persister.get("foo", fooGet);
assert(foo.persistMe ==  fooGet.persistMe);

auto barGet = new Bar;
persister.get("bar", barGet);
assert(bar.persistMe ==  barGet.persistMe);
---
*/
//interface IPersister
//{
//    void set(T)(string name, T value);
//    void get(T)(string name, T value);
//}
//
//class VariantPersister : IPersister
//{
//    private Variant data;
//
//    this(Variant v)
//    {
//        data = v;
//    }
//
//    void set(T)(string name, T value)
//    {
//        data[name] = v;
//    }
//
//    void get(T)(string name, T value)
//    {
//    }
//}


class GenericResource : Resource!GenericResource
{
	private static ClassInfo[string] typeNameToHelperMap;

	bool includeHeader = true;

	interface IHelper
	{
		string getClassInfoName();
		void setData(Object o);
		void serialize(Appender!string output);
		void deserialize(string str);
	}

	static class Helper(T) : IHelper
	{
		static this()
		{
			string name = T.classinfo.name;
			ClassInfo ci = (Helper!T).classinfo;
			typeNameToHelperMap[name] = ci;
		}

		T data;

		this ()
		{
		}

		this(T d)
		{
			data = d;
		}

		void setData(Object o)
		{
			data = cast(T) o;
		}

		string getClassInfoName()
		{
			return data.classinfo.name;
		}

		void serialize(Appender!string output)
		{
			output ~= jsonEncode(data);
		}

		void deserialize(string str)
		{
			data = jsonDecode!T(str);
		}
	}

	IHelper[] helpers;
	int[string] index;

//	Variant data;
	//alias data this;

	T get(T)(string key = null)
	{
		if (key is null)
			return get!T(0);

		auto idx = key in index;
		if (idx is null)
			return null;

		return get!T(*idx);
	}

	T get(T)(int idx)
	{
		if (helpers.length <= idx)
			return null;

		auto helper = cast(Helper!T)(helpers[idx]);

		if (helper is null)
			return null;

		return helper.data;
	}

	void set(T)(T value)
	{
		if (helpers.empty)
			helpers ~= new Helper!T(value);
		else
			helpers[0] = new Helper!T(value);
	}

	int set(T)(T value, string key)
	{
		assert(key !in index);
		helpers ~= new Helper!T(value);
		auto idx = helpers.length - 1;
		index[key] = idx;
		return idx;
	}

	int add(T)(T value, string key = null)
	{
		auto idx = helpers.length - 1;
		if (key !is null)
		{
			if (key in index)
				return -1;
			index[key] = cast(int)idx;
		}
		helpers ~= new Helper!T(value);
		return cast(int)idx;
	}

    void clear()
    {
        helpers.length = 0;
        index = typeof(index).init;
    }

	void serialize(Appender!string output)
	{
		import std.conv;
		import std.string;

		output ~= "Deadcode 1\n";
		output ~= "json 1\n";

		if (includeHeader)
		{
			string headerOutput; // = appender!string();
			auto dataOutput = appender!string();
			auto offset = dataOutput.data().length;

			string[] keys;
			keys.length = helpers.length;
			foreach(k,v; index)
				keys[v] = k;

			foreach (i, helper; helpers)
			{
				headerOutput ~= keys[i] is null ? "" : keys[i];
				headerOutput ~= ",";
				headerOutput ~= helper.getClassInfoName();
				headerOutput ~= ",";
				headerOutput ~= text(offset);

				if (i)
					dataOutput ~= "\n";

				helper.serialize(dataOutput);

				headerOutput ~= ",";
				headerOutput ~= text(dataOutput.data().length - offset);
				headerOutput ~= "\n";

				offset = dataOutput.data().length;
			}

			output ~= format("%s,%s\n", helpers.length, helpers.length);
			output ~= headerOutput;
			output ~= dataOutput.data();
		}
		else
		{
			throw new Exception("Not supported yet");
            //foreach (helper; helpers)
            //{
            //    helper.serialize(output);
            //    output ~= "\n";
            //}
		}
	}

	void deserialize(string str)
	{
		import std.string;

		if (includeHeader)
		{
			// First read headers to get a map of the file.

		}

		// First line describes the type to deserialize
		// This can be used to lookup type deserializer helper
		import std.algorithm;

		auto result = str.splitter("\n");
		if (result.empty)
			throw new Exception("Error deserializing type of GenericResource");

		string magic = result.front.chomp;
		result.popFront();
		auto contentType = result.front.chomp;
		result.popFront();

		if (magic[0..8] != "Deadcode")
		{
			readObject(magic, contentType);
			return;
		}

		import std.format;
		int objectCount;
		int indexCount;

		string data = result.front.chomp;
		if (std.format.formattedRead(data, "%s,%s", &objectCount, &indexCount) != 2)
			throw new Exception("Cannot read index entry " ~ data);
		result.popFront();

		assert(objectCount == indexCount); // FIX: For now this need to be true

		struct Header
		{
			int offset;
			int length;
			string typeName;
			string key;
		}

		int i = 0;
		string[] typeNames;
		while(indexCount--)
		{
			string key;
			string typeName;
			int offset;
			int length;
			data = result.front.chomp;
			if (std.format.formattedRead(data, "%s,%s,%s,%s", &key, &typeName, &offset, &length) != 4)
				throw new Exception("Cannot read index entry " ~ data);
			result.popFront();
			index[key] = i++;
			typeNames ~= typeName;
		}

        // TODO: Fix or change
        //int j = 0;
        //while (objectCount--)
        //{
        //    readObject(typeNames[j++], result.front);
        //    result.popFront();
        //}
		int j = 0;
		while (objectCount--)
		{
            import std.array;
			readObject(typeNames[j++], join(result));
            break;
		}
	}

	void readObject(string typeName, string objectData)
	{
		// Object helperObj = Object.factory("gui.resources.generic.GenericResource.Helper!(" ~ typeName ~ ").Helper");
		auto ci = typeName in typeNameToHelperMap;
		if (ci is null)
			throw new Exception("Error deserializing unknown type name " ~ typeName);

		Object helperObj = ci.create();
		if (helperObj is null)
			throw new Exception("Error deserializing unknown helper type " ~ typeName);

		auto helper = cast(IHelper) helperObj;
		if (helper is null)
			throw new Exception("Error deserializing unknown type " ~ typeName);

		helper.deserialize(objectData);
		helpers ~= helper;
	}
}



class GenericResourceManager : ResourceManager!GenericResource
{
	static GenericResourceManager create(IOManager ioManager)
	{
		auto fm = new GenericResourceManager;
		auto fp = new GenericResourceJsonSerializer;
		fm.ioManager = ioManager;
		fm.addSerializer(fp);
		return fm;
	}

	GenericResource create(T)(string name)
	{
		auto f = declare(name);
		return f;
	}

	GenericResource create(T)(string name, T value)
	{
		import util.jsonx;
		auto f = declare(name);
		f.data = value;
		return f;
	}

    override bool unload(Handle h)
    {
        ResourceState* rs = h in _resourcesByHandle;
        if (rs !is null)
        {
            rs.resource.helpers = null;
            rs.resource.index = null;
        }
        return super.unload(h);
    }
}

class GenericResourceJsonSerializer : ResourceSerializer!GenericResource
{
	override bool canRead() pure const nothrow { return true; }
	override bool canWrite() pure const nothrow { return true; }

	override bool canHandle(URI uri)
	{
		return true;
	}

	override void serialize(GenericResource res, Appender!string output)
	{
		// double dispatch
		res.serialize(output);
	}

	override void deserialize(GenericResource res, string str)
	{
		// res.data = jsonDecode(str);
		res.deserialize(str);
		res.manager.onResourceLoaded(res, this);
	}

	// Get the fields from data by either:
	// * Calling value.persist(GenericResource, true)
	// * Inspecting the fields of T and only get the ones marked with @persistant
	//T get(T)(T value)
	//{
	//    static if (__traits(compiles, value.persist( value, true)))
	//        value.persist(data, value, true);
	//    else
	//        ;
	//
	//}
	//
	//// Set the data field by either:
	//// * Calling value.persist(GenericResource, false)
	//// * Inspecting the fields of T and only set the ones marked with @persistant
	//void set(T)(T value)
	//{
	//    static if (__traits(compiles, value.persist(data, value, false)))
	//        value.persist(data, value, false);
	//    else
	//        ;
	//}
}


unittest
{
	//FontManager m = new FontManager;
	//auto p = new JsonFontSerializer;
	//m.addSerializer(p);
	//
	//import test;
	//auto r = m.declare();
	//AssertIs(m.get(r.handle), r, "Resource from declare same as resource gotten by handle from manager");
}
