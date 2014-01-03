module core.command;

import std.conv;
import std.exception;
import std.range : empty;
import std.string;
import std.variant;

class Command
{
	string name;
	string description;
	
	this(string name, string desc)
	{
		this.name = name;
		this.description = desc;	
	}

	bool canExecute(Variant data)
	{
		return true;
	}
	
	abstract void execute(Variant data);
	void undo(Variant data) { }

	string[] getCompletions(Variant data)
	{
		return null;
	}
}

class DelegateCommand : Command
{
	void delegate(Variant d) executeDel;
	void delegate(Variant d) undoDel;
	string[] delegate (Variant d) completeDel;

	this(string name, string desc, void delegate(Variant) executeDel, void delegate(Variant) undoDel = null)
	{
		super(name, desc);
		this.executeDel = executeDel;
		this.undoDel = undoDel;
	}
	
	final override void execute(Variant data)
	{
		executeDel(data);
	}

	final override void undo(Variant data)
	{
		if (undoDel !is null)
			undoDel(data);
	}

	override string[] getCompletions(Variant data)
	{
		if (completeDel !is null)
			return completeDel(data);
		return null;
	}
}

// First way to do it
class CommandHello : Command
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
	return new DelegateCommand("test.hello", "Echo \"Hello\" to stdout", 
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
	DelegateCommand create(string name, string description, void delegate(Variant) executeDel, void delegate(Variant) undoDel = null)
	{
		auto c = new DelegateCommand(name, description, executeDel, undoDel);
		add(c);
		return c;
	}
			
/*	DelegateCommand create(string name, string description, void delegate() del)
	{
		return create(name, description, del, null);
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
/*
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
*/
