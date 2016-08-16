module extensionapi.command;

import dccore.attr : hasAttribute, getAttributes, isType, isNotType;
import extensionapi.common : Application, BufferView, TextEditor, MenuItem, Shortcut, Log, CompletionEntry, CommandParameter, CommandCall, Hints, Fiber;
import dccore.command;

import std.meta : AliasSeq, anySatisfy, Filter, Replace, staticIndexOf, staticMap;
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

	alias InjectedTypes = AliasSeq!(Application, TextEditor, BufferView, Fiber, Log);
	alias InjectedObjects = AliasSeq!(app, currentTextEditor, currentBuffer, Fiber.getThis, dccore.log.log);

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
		 
		alias p1 = Filter!(isNotType!InjectedTypes, ParameterTypeTuple!Func);
		alias p2 = staticMap!(getDefaultValue, p1);

		enum names = [ParameterIdentifierTuple!Func];
		setCommandParameterDefinitions(createParams(names, p2));
	}
	
	private BufferView currentBuffer() { return app.getCurrentBuffer(); }
	private TextEditor currentTextEditor() { return app.getCurrentTextEditor(); }

	private auto call(alias F)(CommandParameter[] v)
	{
		enum count = Filter!(isType!InjectedTypes, ParameterTypeTuple!F).length;
		enum nonInjectedArgsCount = ParameterTypeTuple!F.length - count;
		
		template _replaceWithObject(T)
		{
			enum idx = staticIndexOf!(T, InjectedTypes);
			static if (idx == -1)
			{
				alias _replaceWithObject =  T; // Just put something there. It will not be used.
			}
			else
			{
				alias _replaceWithObject =  InjectedObjects[idx];
			}
		}

		alias t5 = staticMap!(_replaceWithObject, ParameterTypeTuple!F);
		alias injectedArgs = t5[0..count];

        // Save current active buffer since current buffer may be changed by the command
        static if ( anySatisfy!(isType!(BufferView, TextEditor), ParameterTypeTuple!F) )
        {
            auto bv = app.getCurrentBuffer();
            bv.beginUndoGroup();
            scope (exit) bv.endUndoGroup();
        }

		alias parameterType(int idx) = ParameterTypeTuple!F[$-nonInjectedArgsCount+idx];

		static string _setupArgs(int count)
		{
			import std.conv;
			string res;
			string delim = ",";
			foreach (i; 0..count)
			{
				res ~= delim ~ "v[" ~ i.to!string ~ "].get!(parameterType!" ~ i.to!string ~ ")";
				delim = ",";
			}
			return res;
		}

		assert(v.length >= nonInjectedArgsCount);

		// Mixin magic to simply provide injected args and use v[0].get!parameterType!0 etc. for the rest or the args
		mixin("return F(injectedArgs" ~ _setupArgs(nonInjectedArgsCount) ~ ");");
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
