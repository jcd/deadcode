module extension;

public import controls.menu;
public import controls.texteditor;
public import core.bufferview;
public import core.command;
public import core.commandparameter;
public import guiapplication;
public import gui.widget;
public import math.region;
public import std.variant;

private static IBasicExtension[] g_Extensions;
private static IBasicCommand[] g_Commands;
private static TypeInfo_Class[] g_Widgets;
private static IBasicWidget[] g_BasicWidgets;

import std.typetuple;

struct Shortcut
{
	this(string seq)
	{
		keySequence = seq;
	}

	this(string seq, string arg )
	{
		keySequence = seq;
		argument = arg;
	}
	
	string keySequence;
//	CommandParameter[] parameters;
	string argument;
}

//enum isShortcut(alias T) = is(typeof(T) == Shortcut);
//
//alias hasShortcutAttribute(alias what) = anySatisfy!(isShortcut, __traits(getAttributes, what));
//enum getShortcutAttributes(alias what) = [ Filter!(isShortcut, __traits(getAttributes, what)) ];

template isAttribute(AttrType)
{
	template isAttribute(alias T)
	{
		enum isAttribute = is(typeof(T) == AttrType);
	}
}

alias hasAttribute(alias what, AttrType) = anySatisfy!(isAttribute!AttrType, __traits(getAttributes, what));
enum getAttributes(alias what, AttrType) = [ Filter!(isAttribute!AttrType, __traits(getAttributes, what)) ];

struct RegisterCommand(alias Func)
{
	static this()
	{
		new FunctionCommand!Func;
	}
}

class FunctionCommand(alias Func) : IBasicCommand {

	static this()
	{
		g_Commands ~= new FunctionCommand!Func;
	}

	// TODO: parse Func params and set here
	this()
	{
		super(createParams(""));
	}

	static if (hasMenuItemAttribute!Func)
		override @property MenuItem menuItem() const pure nothrow @safe 
		{
			return getMenuItemAttribute!Func;
		}

	static if (hasAttribute!(Func, Shortcut))
		override @property Shortcut[] shortcuts() const pure nothrow @safe
		{
			return getAttributes!(Func,Shortcut);
		}

	override void execute(CommandParameter[] v)
	{
		// TODO: convert v to actual param types
		Func(app, v[0].get!string);
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

enum WidgetLocation
{
	top,
	left,
	right,
	bottom
}

struct PreferredWidgetLocation
{
	string parent; // name of parent or null if window
	WidgetLocation location;
}

class IBasicWidget : Widget
{
	GUIApplication app;
	this() nothrow {}
	abstract void init();
	abstract void fini();
	abstract void onStart();
	abstract void onStop();
	abstract @property PreferredWidgetLocation preferredLocation();
}

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

	override @property PreferredWidgetLocation preferredLocation()
	{
		return PreferredWidgetLocation(null, WidgetLocation.bottom);
	}

	Data loadSessionData(Data)()
	{
		auto r = app.loadOrCreate("extensions/widgets/" ~ T.classinfo.name);
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
		auto r = app.loadOrCreate("extensions/widgets/" ~ T.classinfo.name);
		if (data !is null)
			r.set(data);
		r.save();
	}
}

class IBasicCommand : Command
{
	GUIApplication app;
	
	this(CommandParameterDefinitions paramsDefs)
	{
		super(paramsDefs);
	}

	@property MenuItem menuItem() const pure nothrow @safe
	{
		return MenuItem();
	}

	@property Shortcut[] shortcuts() const pure nothrow @safe
	{
		return null;
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

class BasicCommand(T) : IBasicCommand
{
	static if (hasMenuItemAttribute!T)
	override @property MenuItem menuItem() const pure nothrow @safe 
	{
		return getMenuItemAttribute!T;
	}
	
	static if (hasAttribute!(T, Shortcut))
	override @property Shortcut[] shortcuts() const pure nothrow @safe
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

	@property BufferView currentBuffer()
	{
		return app.currentBuffer;
	}

	@property TextEditor currentTextEditor()
	{
		return app.getCurrentTextEditor();
	}

	IBasicWidget getBasicWidget(string name)
	{
		auto w = app.guiRoot.activeWindow.getWidget(name);
		return cast(IBasicWidget)(w);
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

