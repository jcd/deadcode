module extensionapi.command;

import dccore.attr : hasAttribute, getAttributes, isType, isNotType;
import extensionapi.common : Application, BufferView, TextEditor, MenuItem, Shortcut, Log, CompletionEntry, CommandParameter, CommandCall, Hints, Fiber;
import dccore.command;

import std.meta : anySatisfy, Filter, Replace, staticMap;
import std.traits : FieldNameTuple, isSomeFunction, Identity, ParameterIdentifierTuple, ParameterTypeTuple;

import poodinis : Autowire, DependencyContainer;
import poodinis.container : existingInstance;

private 
{
	static shared(DependencyContainer) g_CommandsContainer;
	@property shared(DependencyContainer) commandsContainer()
	{
		if (g_CommandsContainer is null)
			g_CommandsContainer = new DependencyContainer();
		return g_CommandsContainer;
	}
	
	struct WrappedCommandInfo
	{
		MenuItem menuItem;
		Shortcut[] shortcuts;
		Hints	hints;
	}

	static WrappedCommandInfo[TypeInfo] g_WrappedCommandInfo;
}


/** Attribute to specify a that a command should be run in a fiber

In a module that has a  "mixin registerCommands":
A class derived from class Command or a public function use the @InFiber attribute to force
the command to be run in a fiber.

Another way to force running in a fiber is by setting one of the first parameters of the 
command to be of type Fiber. This will run the command in a fiber at pass the fiber as
argument.

Example:
@InFiber
class SayHelloCommand : Command
{
	this() { super(createParams("")); }

	void run(Log log, string txt)
	{
		log.info(txt);
	}
}

Example:
@InFiber
void textUppercase(Application app, string dummy)
{
	app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
}

Example:
void textUppercase(Fiber fiber, Application app, string dummy)
{
	// The fiber parameter is automatically provided to the function 
	// and the command is run in that fiber.
	app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
}
*/
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
struct RegisterFunctionCommand(alias Func)
{
	alias Function = Func;
	alias FC = ExtensionCommandWrap!(Func, Command);
}

struct RegisterClassCommand(alias Cls)
{
	alias FC = ExtensionCommandWrap!(Cls, Cls);
}

class Foo {}

Exception[] initCommands(InitCommandFunc)(Application app, InitCommandFunc f)
{
	import std.range;

    Exception[] exceptions;

	commandsContainer.register!Application.existingInstance(app);
	commandsContainer.register!Log.existingInstance(dccore.log.log);

	Command[] commands = commandsContainer().resolveAll!Command;
	
	foreach (c; commands)
	{
		try
        {
			TypeInfo ti = typeid(c);
			WrappedCommandInfo* cmdInfo = ti in g_WrappedCommandInfo;
            f(c, cmdInfo.menuItem, cmdInfo.shortcuts, cmdInfo.hints);
        }
        catch (Exception e)
            exceptions ~= e;
	}

    return exceptions;
}

void finiCommands(Application app)
{
	Command[] commands = app.commandManager.commands.values;
	foreach (c; commands)
		c.onUnloaded();
}

// Wrapper for a function or a class derived from Command where it will
// automatically inject needed values to either the function or a .run method on the class instance
// when executed through e.g. the command manager.
class ExtensionCommandWrap(alias AttributeHolder, Base) : Base
{
	static if ( ! anySatisfy!(isType!Application, FieldNameTuple!Base) )
	{
		@Autowire
		Application app;
	}

	static if ( isSomeFunction!AttributeHolder )
		alias Func = AttributeHolder;
	else
		alias Func = run;
	
	static if (hasAttribute!(AttributeHolder, InFiber) || anySatisfy!(isType!Fiber, ParameterTypeTuple!Func))
		override bool mustRunInFiber() const pure nothrow @safe
		{
			return true;
		}

	static this()
	{
		alias WrappedType = ExtensionCommandWrap!(AttributeHolder, Base);
		commandsContainer.register!(Command, WrappedType)();

		WrappedCommandInfo info;

		static if (hasAttribute!(AttributeHolder,MenuItem))
			info.menuItem = getAttributes!(AttributeHolder, MenuItem)[0];

		static if (hasAttribute!(AttributeHolder, Shortcut))
			info.shortcuts = getAttributes!(AttributeHolder, Shortcut);

		static if (hasAttribute!(AttributeHolder, Hints))
			info.hints = getAttributes!(AttributeHolder, Hints)[0];
		
		TypeInfo wrappedTypeInfo = typeid(WrappedType);
		g_WrappedCommandInfo[wrappedTypeInfo] = info;
	}

	this()
	{
		enum getDefaultValue(U) = U.init;

		alias p1 = Filter!(isNotType!Application, ParameterTypeTuple!Func);
		alias p2 = Filter!(isNotType!TextEditor, p1);
		alias p3 = Filter!(isNotType!BufferView, p2);
		alias p4 = Filter!(isNotType!Fiber, p3);
        alias p5 = Filter!(isNotType!Log, p4);
		alias p6 = staticMap!(getDefaultValue, p5);

		enum names = [ParameterIdentifierTuple!Func];
		setCommandParameterDefinitions(createParams(names, p6));
	}
	
	private BufferView currentBuffer() { return app.getCurrentBuffer(); }
	private TextEditor currentTextEditor() { return app.getCurrentTextEditor(); }

	private auto call(alias F)(CommandParameter[] v)
	{
		enum count = Filter!(isType!BufferView, ParameterTypeTuple!F).length +
			Filter!(isType!TextEditor, ParameterTypeTuple!F).length +
			Filter!(isType!Application, ParameterTypeTuple!F).length +
			Filter!(isType!Fiber, ParameterTypeTuple!F).length +
            Filter!(isType!Log, ParameterTypeTuple!F).length;

		alias t1 = Replace!(BufferView, currentBuffer, ParameterTypeTuple!Func);
		alias t2 = Replace!(TextEditor, currentTextEditor, t1);
		alias t3 = Replace!(Application, app, t2);
		alias t4 = Replace!(Fiber, Fiber.getThis, t3);
		alias t5 = Replace!(Log, dccore.log.log, t4);
		alias preparedArgs = t5[0..count];

		enum missingArgCount = ParameterTypeTuple!F.length - count;
		// pragma(msg, "CommandFunction args: ", fullyQualifiedName!Func, ParameterTypeTuple!Func, missingArgCount);

        // Save current active buffer since current buffer may be changed by the command
        static if (Filter!(isType!BufferView, ParameterTypeTuple!F).length +
                   Filter!(isType!TextEditor, ParameterTypeTuple!F).length != 0)
        {
            auto bv = app.getCurrentBuffer();
            bv.beginUndoGroup();
            scope (exit) bv.endUndoGroup();
        }

        static if (missingArgCount == 0)
		{
			return F(preparedArgs);
		}
		else static if (missingArgCount == 1)
		{
			assert(v.length >= 1);
			alias a1 = ParameterTypeTuple!F[$-1];
			return F(preparedArgs, v[0].get!a1);
		}
		else static if (missingArgCount == 2)
		{
			assert(v.length >= 2);
			alias a2 = ParameterTypeTuple!F[$-1];
			alias a1 = ParameterTypeTuple!F[$-2];
			return F(preparedArgs, v[0].get!a1, v[1].get!a2);
		}
		else static if (missingArgCount == 3)
		{
			assert(v.length >= 3);
			alias a3 = ParameterTypeTuple!F[$-1];
			alias a2 = ParameterTypeTuple!F[$-2];
			alias a1 = ParameterTypeTuple!F[$-3];
			return F(preparedArgs, v[0].get!a1, v[1].get!a2, v[2].get!a3);
        }
        else static if (missingArgCount == 4)
        {
            assert(v.length >= 3);
            alias a4 = ParameterTypeTuple!F[$-1];
            alias a3 = ParameterTypeTuple!F[$-2];
            alias a2 = ParameterTypeTuple!F[$-3];
            alias a1 = ParameterTypeTuple!F[$-4];
            return F(preparedArgs, v[0].get!a1, v[1].get!a2, v[2].get!a3, v[2].get!a4);
        }
		else
		{
			pragma(msg, "Add support for more argments in CommandFunction. Only 4 supported now.");
		}
	}

	override void execute(CommandParameter[] v)
	{
		call!Func(v);
	}

	static if (__traits(hasMember, Base, "complete") && isSomeFunction!(Base.complete))
	{
		override CompletionEntry[] getCompletions(CommandParameter[] v)
		{
			return call!complete(v);
		}
	}
}

void registerCommandKeyBindings(Application app)
{
	Command[] commands = app.commandManager.commands.values;
	foreach (c; commands)
	{
		TypeInfo ti = typeid(c);
		TypeInfo_Class tic = cast(TypeInfo_Class) ti;
		string name = tic.name;
		WrappedCommandInfo* cmdInfo = ti in g_WrappedCommandInfo;
		if (cmdInfo !is null)
			app.addCommandShortcuts(c.name, cmdInfo.shortcuts);
	}
}
