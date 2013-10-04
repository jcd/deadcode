module command;

import std.conv;
import std.exception;
import std.range : empty;
import std.string;
import std.variant;

// Type erasure base
class Command
{
	string name;
	string description;
	
	this(string name, string desc)
	{
		this.name = name;
		this.description = desc;	
	}

	bool canExecute(void* context, Variant data)
	{
		return true;
	}
	
	abstract void execute(void* context, Variant data);
	void undo(void* context, Variant data) { }

	string[] getCompletions(void* context, Variant data)
	{
		return null;
	}
}

// Command with no context available
class NoContextCommand : Command
{
	this(string name, string desc)
	{
		super(name, desc);
	}

	final override final bool canExecute(void* context, Variant data)
	{
		return canExecute(data);
	}

	bool canExecute(Variant data)
	{
		return true;
	}	

	final override void execute(void* context, Variant data)
	{
		return execute(data);
	}

	abstract void execute(Variant data);

	final override void undo(void* context, Variant data)
	{
		return undo(data);
	}
	
	void undo(Variant data) { }

	final override string[] getCompletions(void* context, Variant data)
	{
		return getCompletions(data);
	}

	string[] getCompletions(Variant data)
	{
		return null;
	}
}

class ContextCommand(Context) : Command
{
	this(string name, string desc)
	{
		super(name, desc);
	}

	final override final bool canExecute(void* context, Variant data)
	{
		// Runtime check of context
		Context* cast_context = cast(Context*) context;
		assert(cast_context !is null);
		return canExecute(*cast_context, data);
	}

	bool canExecute(Context context, Variant data)
	{
		return true;
	}

	final override final void execute(void* context, Variant data)
	{
		// Runtime check of context
		Context* cast_context = cast(Context*) context;
		assert(cast_context !is null);
		execute(*cast_context, data);
	}

	abstract void execute(Context context, Variant data);

	final override void undo(void* context, Variant data)
	{
		// Runtime check of context
		Context* cast_context = cast(Context*) context;
		assert(cast_context !is null);
		execute(*cast_context, data);
	}
	
	void undo(Context context, Variant data) {}

	final override string[] getCompletions(void* context, Variant data)
	{
		// Runtime check of context
		Context* cast_context = cast(Context*) context;
		assert(cast_context !is null);
		return getCompletions(*cast_context, data);
	}

	string[] getCompletions(Context context, Variant data)
	{
		return null;
	}
}

class DelegateCommand(Context) : ContextCommand!Context
{
	void delegate(Context context, Variant d) del;
	void delegate(Context context, Variant d) undoDel;

	this(string name, string desc, 
	     void delegate(Context context, Variant) del,
	     void delegate(Context context, Variant) undoDel = null)
	{
		super(name, desc);
		this.del = del;
		this.undoDel = undoDel;
	}
	
	override void execute(Context context, Variant data)
	{
		del(context, data);
	}

	override void undo(Context context, Variant data)
	{
		if (undoDel !is null)
			undoDel(context, data);
	}
}

class NoContextDelegateCommand : NoContextCommand
{
	void delegate(Variant d) del;
	void delegate(Variant d) undoDel;

	this(string name, string desc, void delegate(Variant) del, void delegate(Variant) undoDel = null)
	{
		super(name, desc);
		this.del = del;
		this.undoDel = undoDel;
	}
	
	override void execute(Variant data)
	{
		del(data);
	}

	override void undo(Variant data)
	{
		if (undoDel !is null)
			undoDel(data);
	}
}

// First way to do it
class CommandHello : NoContextCommand
{
	this()
	{
		super("test.hello", "Echo \"Hello\" to stdout");
	}
	
	override void execute(Variant data)
	{
		std.stdio.writeln("Hello");
	}
}

// Second way to do it
auto helloCommand()
{
	return new NoContextDelegateCommand("test.hello", "Echo \"Hello\" to stdout", 
	                           delegate (Variant data) { std.stdio.writeln("Hello"); });
}

	
class CommandManager
{
	// Runtime check that only one instance is created ie. not for use in singleton pattern.
	private static CommandManager _the; // assert only singleton
			
	this()
	{
		assert(_the is null);
		_the = this;
	}

	// name -> Command
	Command[string] commands;

	// TODO: Rename to create(..) when dmd supports overloading on parameter that is delegates with different params. Currently this method
	//       conflicts with the method below because of dmd issues.
	NoContextDelegateCommand createPlain(string name, string description, void delegate(Variant) del)
	{
		auto c = new NoContextDelegateCommand(name, description, del);
		add(c);
		return c;
	}
			
	DelegateCommand!Context create(Context)(string name, string description, void delegate(Context, Variant) del)
	{
		auto c = new DelegateCommand!Context(name, description, del);
		add(c);
		return c;
	}

	NoContextDelegateCommand createPlain(string name, string description, void delegate() del)
	{
		auto c = new NoContextDelegateCommand(name, description, (Variant ignore) { del(); });
		add(c);
		return c;
	}

	/*
	DelegateCommand create(string name, string description, void delegate() del)
	{
		auto c = new DelegateCommand(name, description, (Variant v) { del(); } );
		add(c);
		return c;
	}
*/
	/** Add a command
	 * 
	 * Params:
	 * command = Command to add
	 * name = if not null then set as the name of the command. Else command.name is used.
	 * description = if not null then set as the description of the command. Else command.description is used.
	 */
	void add(Command command, string name = null, string description = null)
	{
		if (name !is null)
			command.name = name;
		if (description !is null)
			command.description = description;
		enforceEx!Exception(!(command.name in commands), text("Trying to add existing command ", command.name));
		commands[command.name] = command;
	}

	/** Remove a command
	 */
	void remove(string commandName)
	{
		// TODO: commands.remove(commandName);
	}
		
	Command lookup(string commandName)
	{
		auto c = commandName in commands;
		if (c) return *c;
		return null;
	}
}

// TODO: fix	
/* API:
View	 		TextView  
RegionSet		RegionSet
Region			Region
Edit			N/A
Window 			Window
Settings		N/A

Base Classes:

EventListener
ApplicationCommand
WindowCommand
TextCommand
*/


	
/// Plugin:

// Application wide command. One instance for the application.
class ApplicationCommand : Command
{
	this(string name, string desc) { super(name, desc); }
}

// Window wide command. One instance per window.
class WindowCommand : Command
{
	this(string name, string desc) { super(name, desc); }
}

// Editor wide command. One instance per editor.
class EditorCommand : Command
{
	this(string name, string desc) { super(name, desc); }
}
