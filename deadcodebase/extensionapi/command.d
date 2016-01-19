module extensionapi.command;

import dccore.attr : hasAttribute, getAttributes, isType, isNotType;
import extensionapi.common : Application, BufferView, TextEditor, MenuItem, Shortcut, Log, CompletionEntry, CommandParameter, CommandCall, Hints, Fiber;
import dccore.command;

import std.meta : anySatisfy, Filter, Replace, staticMap;
import std.traits : isSomeFunction, ParameterIdentifierTuple, ParameterTypeTuple;

private static BasicCommand[] g_Commands;


/** Attribute to specify a short for for a Command or command function

A class derived from class BasicCommand or a function with the @RegisterCommand attribute
use the @Shortcut attribute to set the default shortcut for the command.

Example:
@Shortcut("<ctrl> + h")                 // Shortcut that will prompt for missing command argument
@Shortcut("<ctrl> + m", "Hello world")  // Shortcut that with the command argument set in advance
class SayHelloCommand : BasicCommand
{
this() { super(createParams("")); }

void run(string txt)
{
std.stdio.writeln(txt);
}
}

Example:
@RegisterCommand!textUppercase
@Shortcut("<ctrl> + u")
void textUppercase(Application app, string dummy)
{
app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
}
*/


//enum isMenuItem(alias T) = is(typeof(T) == MenuItem);
// alias hasMenuItemAttribute(alias what) = anySatisfy!(isMenuItem, __traits(getAttributes, what));
// enum hasMenuItemAttribute(what) = false;
//enum getMenuItemAttribute(alias what) = Filter!(isMenuItem, __traits(getAttributes, what))[0];

struct InFiber
{
}

/** Attribute to Register a free function as a Command

This will create a new FunctionCommand!Func that wraps the function. The Command.execute will
inspect the function parameter types and extract values of those types at runtime from the
Command.execute arguments. Then it will call the free function with the arguments.

In case the free function needs context information such as active BufferView instance or Application instance
it can get that by setting the first parameter to the type of context it needs. Supported contexts are:

* BufferView  = the active buffer view currently having keyboard focus or null
* Application = the application instance
* Widget      = the widget that currently has focus
* Context     = A struct with all of the above.
*/
struct RegisterCommand(alias Func)
{
	alias Function = Func;
	static this()
	{
		new FunctionCommand!Func;
	}
}

/// Command to wrap a function. Use RegisterCommand!Func and not this directly.
class FunctionCommand(alias Func) : BasicCommand
{
	static this()
	{
		g_Commands ~= new FunctionCommand!Func;
	}

	// TODO: parse Func params and set here
	this()
	{
		alias p1 = Filter!(isNotType!Application, ParameterTypeTuple!Func);
		alias p2 = Filter!(isNotType!TextEditor, p1);
		alias p3 = Filter!(isNotType!BufferView, p2);
		alias p4 = Filter!(isNotType!Fiber, p3);
        alias p5 = Filter!(isNotType!Log, p4);
		alias p6 = staticMap!(getDefaultValue, p5);

		enum names = [ParameterIdentifierTuple!Func];
		setCommandParameterDefinitions(createParams(names, p6));
	}

	static if (hasAttribute!(Func,MenuItem))
		override @property MenuItem menuItem() const pure nothrow @safe
		{
			return getAttributes!(Func,MenuItem)[0];
		}

	static if (hasAttribute!(Func, Shortcut))
		override @property Shortcut[] shortcuts() const pure nothrow @safe
		{
			return getAttributes!(Func,Shortcut);
		}

	static if (hasAttribute!(Func, InFiber) || anySatisfy!(isType!Fiber, ParameterTypeTuple!Func))
		override bool mustRunInFiber() const pure nothrow @safe
		{
			return true;
		}

    /*
	@property BufferView currentBuffer()
	{
    return app.currentBuffer;
	}

	@property TextEditor currentTextEditor()
	{
    return app.getCurrentTextEditor();
	}
    */
	override void execute(CommandParameter[] v)
	{
		enum count = Filter!(isType!BufferView, ParameterTypeTuple!Func).length +
			Filter!(isType!TextEditor, ParameterTypeTuple!Func).length +
			Filter!(isType!Application, ParameterTypeTuple!Func).length +
			Filter!(isType!Fiber, ParameterTypeTuple!Func).length +
            Filter!(isType!Log, ParameterTypeTuple!Func).length;

		alias t1 = Replace!(BufferView, currentBuffer, ParameterTypeTuple!Func);
		alias t2 = Replace!(TextEditor, currentTextEditor, t1);
		alias t3 = Replace!(Application, app, t2);
		alias t4 = Replace!(Fiber, Fiber.getThis, t3);
		alias t5 = Replace!(Log, currentLog, t4);
		alias preparedArgs = t5[0..count];

		enum missingArgCount = ParameterTypeTuple!Func.length - count;
		// pragma(msg, "CommandFunction args: ", fullyQualifiedName!Func, ParameterTypeTuple!Func, missingArgCount);

        // Save current active buffer since current buffer may be changed by the command
        static if (Filter!(isType!BufferView, ParameterTypeTuple!Func).length +
                   Filter!(isType!TextEditor, ParameterTypeTuple!Func).length != 0)
        {
            auto bv = currentBuffer;
            bv.beginUndoGroup();
            scope (exit) bv.endUndoGroup();
        }

        static if (missingArgCount == 0)
		{
			Func(preparedArgs);
		}
		else static if (missingArgCount == 1)
		{
			assert(v.length >= 1);
			alias a1 = ParameterTypeTuple!Func[$-1];
			Func(preparedArgs, v[0].get!a1);
		}
		else static if (missingArgCount == 2)
		{
			assert(v.length >= 2);
			alias a2 = ParameterTypeTuple!Func[$-1];
			alias a1 = ParameterTypeTuple!Func[$-2];
			Func(preparedArgs, v[0].get!a1, v[1].get!a2);
		}
		else static if (missingArgCount == 3)
		{
			assert(v.length >= 3);
			alias a3 = ParameterTypeTuple!Func[$-1];
			alias a2 = ParameterTypeTuple!Func[$-2];
			alias a1 = ParameterTypeTuple!Func[$-3];
			Func(preparedArgs, v[0].get!a1, v[1].get!a2, v[2].get!a3);
        }
        else static if (missingArgCount == 4)
        {
            assert(v.length >= 3);
            alias a4 = ParameterTypeTuple!Func[$-1];
            alias a3 = ParameterTypeTuple!Func[$-2];
            alias a2 = ParameterTypeTuple!Func[$-3];
            alias a1 = ParameterTypeTuple!Func[$-4];
            Func(preparedArgs, v[0].get!a1, v[1].get!a2, v[2].get!a3, v[2].get!a4);
        }
		else
		{
			pragma(msg, "Add support for more argments in CommandFunction. Only 4 supported now.");
		}
	}
}

Exception[] initCommands(InitCommandFunc)(InitCommandFunc f)
{
	import std.range;

    Exception[] exceptions;

	foreach (c; g_Commands)
	{
		try
        {
            f(c);
        }
        catch (Exception e)
            exceptions ~= e;
	}

    return exceptions;
}


void finiCommands()
{
	foreach (c; g_Commands)
		c.fini();
}

class BasicCommand : Command
{
	Application app;

	@property MenuItem menuItem() const pure nothrow @safe
	{
		return MenuItem();
	}

	@property Shortcut[] shortcuts() const pure nothrow @safe
	{
		return null;
	}

	@property BufferView currentBuffer()
	{
		return app.getCurrentBuffer();
	}

    @property BufferView buffer()
	{
		auto b = currentBuffer;
        if (b.name == "*CommandInput*")
            return app.previousBuffer;
        return b;
	}

	@property Log currentLog()
    {
        return app.log;
    }

	@property TextEditor currentTextEditor()
	{
		return app.getCurrentTextEditor();
	}

	protected final T getWidget(T)(string name)
	{
		return cast(T)app.getWidget(name);
	}

	override void execute(CommandParameter[] v)
	{
		assert(0);
	}

	void init()
	{
		// no-op
	}

	void fini()
	{
		// no-op
	}

	void onStart()
	{
		// no-op
	}

	void onStop()
	{
		// no-op
	}
}

enum getDefaultValue(T) = T.init;

class BasicCommandWrap(T) : T
{
	final override @property
	{
		static if (hasAttribute!(T,MenuItem))
			MenuItem menuItem() const pure nothrow @safe
			{
				return getAttributes!(T,MenuItem)[0];
			}

		static if (hasAttribute!(T, Shortcut))
			Shortcut[] shortcuts() const pure nothrow @safe
			{
				return getAttributes!(T,Shortcut);
			}

		string name() const
		{
			import std.algorithm;
			import std.range;
			import std.string;
			import std.uni;

			// class Name is assumed PascalCase ie. FooBarCommand and the Command postfix is stripped
			auto toks = T.classinfo.name.splitter('.').retro;
			string className = toks.front.chomp("Command");
			return classNameToCommandName(className);
		}

		static if (hasAttribute!(T, Hints))
			int hints() const
			{
				int result = Hints.off;
				foreach (h; getAttributes!(T, Hints))
					result = result & h;
				return result;
			}
	}

	static this()
	{
		g_Commands ~= new BasicCommandWrap!T;
	}

	this()
	{
		setCommandParameterDefinitions(createParams([ ParameterIdentifierTuple!run ], staticMap!(getDefaultValue, ParameterTypeTuple!run)));
	}

	override void execute(CommandParameter[] v)
	{
		alias Func = run;
		enum parameterCount = ParameterTypeTuple!Func.length;

		//alias convertedArgs = staticMap!(convertToType!(v,Func), Iota!(0, parameterCount));
		//Func(convertedArgs);

		static if (parameterCount == 0)
		{
			Func();
		}
		else static if (parameterCount == 1)
		{
			assert(v.length >= 1);
			alias a1 = ParameterTypeTuple!Func[$-1];
			Func(v[0].get!a1);
		}
		else static if (parameterCount == 2)
		{
			assert(v.length >= 2);
			alias a1 = ParameterTypeTuple!Func[$-2];
			alias a2 = ParameterTypeTuple!Func[$-1];
			Func(v[0].get!a1, v[1].get!a2);
		}
		else static if (parameterCount == 3)
		{
			assert(v.length >= 3);
			alias a1 = ParameterTypeTuple!Func[$-3];
			alias a2 = ParameterTypeTuple!Func[$-2];
			alias a3 = ParameterTypeTuple!Func[$-1];
			Func(v[0].get!a1, v[1].get!a2, v[2].get!a3);
		}
		else
		{
			pragma(msg, "Add support for more argments in Command extension. Only 3 supported now.");
		}
	}

	static if (__traits(hasMember, T, "complete") &&  isSomeFunction!(T.complete))
	{
		override CompletionEntry[] getCompletions(CommandParameter[] v)
		{
			alias Func = complete;
			enum parameterCount = ParameterTypeTuple!Func.length;

			//alias convertedArgs = staticMap!(convertToType!(v,Func), Iota!(0, parameterCount));
			//Func(convertedArgs);

			static if (parameterCount == 0)
			{
				return Func();
			}
			else static if (parameterCount == 1)
			{
				assert(v.length >= 1);
				alias a1 = ParameterTypeTuple!Func[$-1];
				return Func(v[0].get!a1);
			}
			else static if (parameterCount == 2)
			{
				assert(v.length >= 2);
				alias a1 = ParameterTypeTuple!Func[$-2];
				alias a2 = ParameterTypeTuple!Func[$-1];
				return Func(v[0].get!a1, v[1].get!a2);
			}
			else static if (parameterCount == 3)
			{
				assert(v.length >= 3);
				alias a1 = ParameterTypeTuple!Func[$-3];
				alias a2 = ParameterTypeTuple!Func[$-2];
				alias a3 = ParameterTypeTuple!Func[$-1];
				return Func(v[0].get!a1, v[1].get!a2, v[2].get!a3);
			}
			else
			{
				pragma(msg, "Add support for more argments in Command extension completion. Only 3 supported now.");
			}
		}
	}
}

void registerCommandKeyBindings(Application app)
{
	foreach (c; g_Commands)
        app.addCommandShortcuts(c.name, c.shortcuts);
}
