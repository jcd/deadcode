module core.command;

import std.conv;
import std.exception;
import std.range : empty;
import std.string;
import std.variant;

class Command
{
	@property
	{
		string name() const
		{
			return chomp(this.classinfo.name, "Command");
		}
		
		string description() const
		{
			return name;
		}

		string shortcut() const
		{ 
			return null; 
		}
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
	private string _name;
	private string _description;
	
	override @property string name() const { return _name; }
	override @property string description() const { return _description; }

	void delegate(Variant d) executeDel;
	void delegate(Variant d) undoDel;
	string[] delegate (Variant d) completeDel;

	this(string nameIn, string descIn, void delegate(Variant) executeDel, void delegate(Variant) undoDel = null)
	{
		_name = nameIn;
		_description = descIn;
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
	override @property const
	{
		string name() { return "test.hello"; }
		string description() { return "Echo \"Hello\" to stdout"; }
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
	void add(Command command)
	{
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
/*
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
class EditCommand : Command
{
	this(string name, string desc) { super(name, desc); }
}

*/
