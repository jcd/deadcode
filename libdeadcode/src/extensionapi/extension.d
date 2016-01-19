module extensionapi.extension;

import extensionapi.common;

private static Extension[] g_Extensions;

import std.traits;
import std.typetuple;

class Extension
{
	Application app;

	@property BufferView currentBuffer()
	{
		return app.currentBuffer;
	}

    @property BufferView buffer()
	{
		auto b = app.currentBuffer;
        if (b.name == "*CommandInput*")
            return app.previousBuffer;
        return b;
	}

	@property TextEditor currentTextEditor()
	{
		return app.getCurrentTextEditor();
	}

	@property string name() { return typeid(this).name; }
    @property string[] dependencies() { return null; }
	void init() { }
	void fini() { }
}

struct RegisterExtension(alias T)
{
	alias Type = T;
	static this()
	{
		g_Extensions ~= new T();
	}
}

Exception[] initExtensions(Application app)
{
	import std.array;
    import std.range;
    import std.algorithm;

    Exception[] exceptions;

    // Two step initialization of extensions because they might be depending on each other
    // and we have to ensure that initialization of one can rely on another valid extension.
	foreach (e; g_Extensions)
		e.app = app;

    foreach (e; g_Extensions)
    {
        try
            e.init(); // makeInstance(); // will call init() and make it initialized
        catch (Exception e)
            exceptions ~= e;
    }
/*
    string[] initializedExtensions;
    Extension[] remaining = null;
    foreach (e; g_Extensions)
    {
		if (!e.dependencies.empty)
        {
            remaining ~= e;
            continue;
        }
        initializedExtensions ~= e.name;
        try
            e.init(); // makeInstance(); // will call init() and make it initialized
        catch (Exception e)
            exceptions ~= e;
    }

    while (!remaining.empty)
    {
        bool someDone = false;
        foreach (i, e; remaining)
        {
            if (setIntersection(e.dependencies, initializedExtensions).array.length == e.dependencies.length)
            {
                try
                    e.init(); // makeInstance(); // will call init() and make it initialized
                catch (Exception e)
                    exceptions ~= e;
                someDone = true;
                initializedExtensions ~= e.name;
                assumeSafeAppend(remaining);
                remaining = remaining.length == (i + 1) ? remaining[0..$-1] : remaining[0..i] ~ remaining[i+1..$];
                break;
            }
        }

        if (!someDone)
        {
            import std.conv;
            string msg;
            foreach (e; remaining)
            {
                msg ~= text(e.name," missing ", e.dependencies);
            }
            assert(someDone, "Modules couldn't have their dependencies fulfilled: " ~ msg);
        }
    }
*/
    return exceptions;
}

void finiExtensions(Application app)
{
	foreach (e; g_Extensions)
	{
		e.fini();
	}
}

T getExtension(T)(string name)
{
	foreach (e; g_Extensions)
	{
		if (e.name == name)
		{
			T ce = cast(T) e;
			return ce;
		}
	}
	return null;
}

T getExtension(T)()
{
	foreach (e; g_Extensions)
	{
		if (typeid(e).name == typeid(T).name)
		{
			T ce = cast(T) e;
			return ce;
		}
	}
	return null;
}

