module extension;

public import core.bufferview;
public import core.command;
public import core.commandparameter;
public import guiapplication;
public import gui.widget;
public import controls.texteditor;
public import std.variant;

private static IBasicExtension[] g_Extensions;
private static IBasicCommand[] g_Commands;
private static TypeInfo_Class[] g_Widgets;

void init(GUIApplication app)
{
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
	}
	foreach (wi; g_Widgets)
	{
		auto w = cast(IBasicWidget)(wi.create());
		w.app = app;
		app.guiRoot.activeWindow.register(w);
		w.parent = app.guiRoot.activeWindow;
		w.init();
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
}

class IBasicCommand : Command
{
	GUIApplication app;
	
	this(CommandParameterDefinitions paramsDefs)
	{
		super(paramsDefs);
	}

	abstract void init();
	abstract void onStart();
	abstract void onStop();
}

class BasicCommand(T) : IBasicCommand
{
	static this()
	{
		g_Commands ~= new T;
	}

	this()
	{
		super(null); // TODO: figure out a nice way to initialize param defs
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
	
	override void onStart()
	{
		// no-op		
	}

	override void onStop()
	{
		// no-op		
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

	override void onStart()
	{
		// no-op		
	}

	override void onStop()
	{
		// no-op		
	}
}

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

