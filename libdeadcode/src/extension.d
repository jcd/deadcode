module extension;

import core.attr;

public import controls.menu;
public import controls.texteditor;
public import core.bufferview;
public import core.command;
public import core.commandparameter;
public import guiapplication;
public import gui.widget;
public import gui.window;
public import math.region;
public import std.variant;

private static IBasicExtension[] g_Extensions;
private static BasicCommand[] g_Commands;
private static TypeInfo_Class[] g_Widgets;
private static IBasicWidget[] g_BasicWidgets;

import std.traits;
import std.typetuple;

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
		void textUppercase(GUIApplication app, string dummy) 
{
			app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
		}
*/
struct Shortcut
{
	string keySequence;
	string argument;
}

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
		alias p1 = Filter!(isNotType!GUIApplication, ParameterTypeTuple!Func);
		alias p2 = Filter!(isNotType!TextEditor, p1);
		alias p3 = Filter!(isNotType!BufferView, p2);
		alias p4 = staticMap!(getDefaultValue, p3);

		enum names = [ParameterIdentifierTuple!Func];
		setCommandParameterDefinitions(createParams(names, p4));
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

	static if (hasAttribute!(Func, InFiber))
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
			Filter!(isType!GUIApplication, ParameterTypeTuple!Func).length;

		alias t1 = Replace!(BufferView, currentBuffer, ParameterTypeTuple!Func);
		alias t2 = Replace!(TextEditor, currentTextEditor, t1);
		alias t3 = Replace!(GUIApplication, app, t2);
		alias preparedArgs = t3[0..count];

		enum missingArgCount = ParameterTypeTuple!Func.length - count;
		// pragma(msg, "CommandFunction args: ", fullyQualifiedName!Func, ParameterTypeTuple!Func, missingArgCount);
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
			alias a1 = ParameterTypeTuple!Func[$-1];
			alias a2 = ParameterTypeTuple!Func[$-2];
			Func(preparedArgs, v[0].get!a1, v[1].get!a2);
		}
		else static if (missingArgCount == 3)
		{
			assert(v.length >= 3);
			alias a1 = ParameterTypeTuple!Func[$-1];
			alias a2 = ParameterTypeTuple!Func[$-2];
			alias a3 = ParameterTypeTuple!Func[$-3];
			Func(preparedArgs, v[0].get!a1, v[1].get!a2, v[2].get!a3);
		}
		else
		{
			pragma(msg, "Add support for more argments in CommandFunction. Only 3 supported now.");
		}
	}
}

void init(GUIApplication app)
{
	import std.range;
	
	foreach (e; g_Extensions)
	{
		e.app = app;
		e.init();
	}

	foreach (c; g_Commands)
	{
		c.app = app;
		c.init();
		app.commandManager.add(c);
		if (!c.menuItem.path.empty)
			app.menu.addTreeItem(c.menuItem.path, c.name);
		
		import std.stdio;
		//writeln(c.name);
		foreach (sc; c.shortcuts)
		{
			if (sc.argument is null)
				app.editorBehavior.keyBindings.setKeyBinding(sc.keySequence, c.name);
			else
				app.editorBehavior.keyBindings.setKeyBinding(sc.keySequence, c.name, sc.argument);
		}
	}

	foreach (wi; g_Widgets)
	{
		auto w = cast(IBasicWidget)(wi.create());
		g_BasicWidgets ~= w;
		w.app = app;
		app.guiRoot.activeWindow.register(w);
		w.parent = app.guiRoot.activeWindow;
		w.init();
	}
}

void fini(GUIApplication app)
{
	foreach (e; g_Extensions)
	{
		e.fini();
	}
	foreach (c; g_Commands)
	{
		c.fini();
	}
	foreach (w; g_BasicWidgets)
	{
		w.fini();
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

/// The preferred location of a widget
struct PreferredLocation
{
	string widgetName;          /// Name of widget that the subject should be relative to or null if window
	RelativeLocation location;  /// The location relative to the names widget
}

/**	
	
*/
class IBasicWidget : Widget
{
	GUIApplication app;
	this() nothrow {}
	abstract void init();
	abstract void fini();
	abstract void onStart();
	abstract void onStop();
	abstract @property PreferredLocation preferredLocation();
}

/** Widget to derive from when extending editor with a new widget type
	
*/
class BasicWidget(T) : IBasicWidget
{
	static this()
	{
		//auto w = new T;
		//T.widgetID = w.id;
		g_Widgets ~= T.classinfo;
	}

	IBasicWidget getBasicWidget(string name)
	{
		auto w = app.guiRoot.activeWindow.getWidget(name);
		return cast(IBasicWidget)(w);
	}

	override void init()
	{
		// no-op
	}

	override void fini()
	{
		// no-op
	}

	override void onStart()
	{
		// no-op		
	}

	override void onStop()
	{
		// no-op
	}

	override @property PreferredLocation preferredLocation()
	{
		return PreferredLocation(null, RelativeLocation.bottomOf);
	}

	Data loadSessionData(Data)()
	{
		auto r = app.get("extensions/widgets/" ~ T.classinfo.name);
		if (r is null)
			return null;
		auto data = r.get!Data();
		if (data is null)
		{
			data = new Data();
			r.set(data);
		}
		return data;
	}

	// If data is null then the data returned by loadSessionData will be saved
	void saveSessionData(Data)(Data data = null)
	{
		auto r = app.get("extensions/widgets/" ~ T.classinfo.name);
		if (r is null)
			return;
		if (data !is null)
			r.set(data);
		r.save();
	}
}

class BasicCommand : Command
{
	GUIApplication app;
	
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
		return app.currentBuffer;
	}

	@property TextEditor currentTextEditor()
	{
		return app.getCurrentTextEditor();
	}

	protected final IBasicWidget getBasicWidget(string name)
	{
		auto w = app.guiRoot.activeWindow.getWidget(name);
		return cast(IBasicWidget)(w);
	}	
	
	protected final T getWidget(T)(string name)
	{
		return cast(T)getBasicWidget(name);
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
/*
class BasicCommand(T) : BasicCommand
{
	static if (hasAttribute!(T,MenuItem))
	final override @property MenuItem menuItem() const pure nothrow @safe 
	{
		return getAttributes!(T,MenuItem)[0];
	}
	
	static if (hasAttribute!(T, Shortcut))
	final override @property Shortcut[] shortcuts() const pure nothrow @safe
	{
		return getAttributes!(T,Shortcut);
	}

	static this()
	{
		g_Commands ~= new T;
	}

	this(CommandParameterDefinitions paramsDefs)
	{
		super(paramsDefs);
	}
}
*/
/*
template Iota(size_t i, size_t n)
{
	static if (n == 0) { alias TypeTuple!() Iota; }
	else { alias TypeTuple!(i, Iota!(i + 1, n - 1)) Iota; }
}

template convertToType(alias VarArray, alias Func)
{
	alias convertToType(int i) = VarArray[i].get!(ParameterTypeTuple!(Func)[i]);
}
*/


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

class IBasicExtension
{
	GUIApplication app;
	
	@property BufferView currentBuffer()
	{
		return app.currentBuffer;
	}

	@property TextEditor currentTextEditor()
	{
		return app.getCurrentTextEditor();
	}

	abstract @property string name();
	abstract void init();
	abstract void fini();
	abstract void onStart();
	abstract void onStop();
}

class BasicExtension(T) : IBasicExtension
{
	static this()
	{
		g_Extensions ~= new T;
	}

	//override void ()
	//{
	//    // no-op		
	//}
	
	override void init()
	{
		// no-op
	}
	
	override void fini()
	{
		// no-op
	}

	override void onStart()
	{
		// no-op		
	}

	override void onStop()
	{
		// no-op		
	}
}

version (NO)
unittest
{
import application;
import core.command;

// Default exposed as 'test'. No shortcut hint
class TestEditTextCommand : Command
{	
	override @property string description() const { return "alalal does this"; }
	override @property string name() const { return "alalal.flflf"; }
	override @property string shortcut() const { return "<ctrl> + c"; }

	//override void canExecute(BufferView buf, Widget widget, Variant data)
	//{
	//    return true;		
	//}

	override void execute(Variant data)
	{
		
	}
}

/*
class TestExtension : Extension!TestExtension
{
	override void onStart()
	{
		
		//app.commandManager.create("test.helloworld", "Insert hello world into active text buffer",
		//        (Variant data) { 	
		//            auto b = app.currentBuffer;
		//            if (b is null)
		//                return;
		//            b.insert("Hello World");
		//        }
		//    );
		//
		//// Example 2: Expose a new command to callback to this extension
		//app.commandManager.create("test.callback", "Callback to the TestExtension.callback()",
		//                          (Variant data) { 	callback(); });
		//
		//app.setCommandKeyBindingHint("test.callback", "<ctrl> + <alt> + c");
	
		// Example 3: Call a command 
		import core.command;
		Command cmd = app.commandManager.lookup("edit.insert");
		cmd.execute("Hello again!");
		// or app.commandManager.execute("edit.insert", "Hello again!");

		app.currentBuffer.insert("Hello again");

	}

	// Example 1: Expose a new command called myCommand
	//			  All public methods of an extensions are commands
	void myCommand(Variant data)
	{
		auto b = app.currentBuffer;
		if (b is null)
			return;
		b.insert("Hello World");
	}

	// Example 2: Expose a new command called test.helloworld
	//            Use another name for the command than the method name.
	//			  Also give a suggested key binding
	@Command("test.helloWorld", "<ctrl> + <alt> + c")
	void myCommand(Variant data)
	{
	}

	override void onStop()
	{
		// app.commandManager.destroy("test.helloworld");
		app.addMessage("Goodbye and have a jolly good day!");
	}
}
*/
}



