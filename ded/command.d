module command;

import std.conv;
import std.exception;
import std.range : empty;
import std.variant;
import std.string;

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
}

class DelegateCommand : Command
{
	void delegate(Variant d) del;
	
	this(string name, string desc, void delegate(Variant) del)
	{
		super(name, desc);
		this.del = del;
	}
	
	void execute(Variant data)
	{
		del(data);
	}
}

// First way to do it
class CommandHello : Command
{
	this()
	{
		super("test.hello", "Echo \"Hello\" to stdout");
	}
	
	void execute(Variant data)
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
	static CommandManager _the;
	static @property CommandManager singleton()
	{					
		if (_the is null)
		{
			_the = new CommandManager();
			import editorcommands;
			editorcommands.register();
		}
		return _the;
	}
			
	// name -> Command
	Command[string] commands;

	DelegateCommand create(string name, string description, void delegate(Variant) del)
	{
		auto c = new DelegateCommand(name, description, del);
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
