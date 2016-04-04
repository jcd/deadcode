module dccore.command;

public import dccore.commandparameter;

import std.conv;
import std.exception;
import std.range : empty;
import std.string;
import std.typecons;
import util.string;

struct CompletionEntry
{
	string label;
	string data;
}

CompletionEntry[] toCompletionEntries(string[] strs)
{
	import std.algorithm;
	return std.array.array(strs.map!(a => CompletionEntry(a,a))());
}

enum Hints : ubyte
{
	off =	       0,
	completion  =  1,
	description =  2,
	all = ubyte.max,
}

import extensionapi.rpc;
mixin registerRPC;

@RPC
class Command
{
	private CommandParameterDefinitions _commandParamtersTemplate;
    static int sNextID = 1;
    int id;
	@property
	{
		string name() const
		{
			import std.algorithm;
			import std.range;
			import std.string;
			import std.uni;

			auto toks = this.classinfo.name.splitter('.').retro;

			string className = null;
			// class Name is assumed PascalCase ie. FooBarCommand and the Command postfix is stripped
			// The special case of extension.FunctionCommand!(xxxx).FunctionCommand
			// is for function commands and the xxx part is pulled out instead.
			if (toks.front == "ExtensionCommandWrap")
			{
				toks.popFront();
				auto idx = toks.front.lastIndexOf('(');
				if (idx == -1)
					className = "invalid-command-name:" ~ this.classinfo.name;
				else
				{
					auto idx2 = toks.front.lastIndexOf(',');
					className ~= toks.front[idx+1].toUpper;
					className ~= toks.front[idx+2..idx2];
				}
			}
			else
			{
				className = toks.front;
			}

			return classNameToCommandName(className.chomp("Command"));
		}

		static protected string classNameToCommandName(string className)
		{
			string cmdName;
			cmdName ~= className[0].toLower;
                        className = className[1..$];
			cmdName ~= className.munch("[a-z0-9_]");
			if (!className.empty)
			{
				cmdName ~= ".";
				cmdName ~= className.munch("A-Z").toLower;
				cmdName ~= className;
			}
			return cmdName;

			//string cmdName;
			//
			//while (!className.empty)
			//{
			//    if (!cmdName.empty)
			//        cmdName ~= ".";
			//    cmdName ~= className.munch("A-Z")[0].toLower;
			//    cmdName ~= className.munch("[a-z0-9_]");
			//}
			//return cmdName;
		}

		string description() const
		{
			return name;
		}

		string shortcut() const
		{
			return null;
		}

		int hints() const
		{
			return Hints.all;
		}

		bool mustRunInFiber() const pure nothrow @safe
		{
			return false;
		}
	}

	this(CommandParameterDefinitions paramsTemplate = null)
	{
        id = sNextID++;
		_commandParamtersTemplate = paramsTemplate;
	}

	void setCommandParameterDefinitions(CommandParameterDefinitions defs)
	{
		_commandParamtersTemplate = defs;
	}

	CommandParameterDefinitions getCommandParameterDefinitions()
	{
		return _commandParamtersTemplate;
	}

	/// Called once the command has been loaded e.g. on app startup
	void onLoaded()
	{
		// no-op
	}

	// Called just before unloading the command e.g. on app shutdown
	void onUnloaded()
	{
		// no-op
	}

	@RPC
    bool canExecute(CommandParameter[] data)
	{
		return true;
		//auto defs = getCommandParameterDefinitions();
		//CommandParameter[] params;
		//return defs is null || defs.setValues(params, data);
	}

	@RPC
    abstract void execute(CommandParameter[] data);

    bool executeWithMissingArguments(ref CommandParameter[] data) { return false; /* false => not handled by method */ }

	void undo(CommandParameter[] data) { }

    int getCompletionSessionID() { return -1; /* no session support */ }
    bool beginCompletionSession(int sessionID) { return false; }
    void endCompletionSession() {}

    CompletionEntry[] getCompletions(string input)
	{
		CommandParameter[] ps;
		auto defs = getCommandParameterDefinitions();
		if (defs is null)
			return null;
		defs.parseValues(ps, input);
		return getCompletions(ps);
	}

	CompletionEntry[] getCompletions(CommandParameter[] data)
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

	void delegate(CommandParameter[] d) executeDel;
	void delegate(CommandParameter[] d) undoDel;
	CompletionEntry[] delegate (CommandParameter[] d) completeDel;

	this(string nameIn, string descIn, CommandParameterDefinitions paramDefs,
		 void delegate(CommandParameter[]) executeDel, void delegate(CommandParameter[]) undoDel = null)
	{
		super(paramDefs);
		_name = nameIn;
		_description = descIn;
		this.executeDel = executeDel;
		this.undoDel = undoDel;
	}

	final override void execute(CommandParameter[] data)
	{
		executeDel(data);
	}

	final override void undo(CommandParameter[] data)
	{
		if (undoDel !is null)
			undoDel(data);
	}

	override CompletionEntry[] getCompletions(CommandParameter[] data)
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

	this()
	{
		super(null);
	}

	override void execute(CommandParameter[] data)
	{
        import std.stdio;
		version (linux)
            writeln("Hello");
	}
}

// Second way to do it
auto helloCommand()
{
    static import std.stdio;
	return new DelegateCommand("test.hello", "Echo \"Hello\" to stdout",
							   null,
	                           delegate (CommandParameter[] data) { std.stdio.writeln("Hello"); });
}


//@Command("edit.cursorDown", "Moves cursor count lines down");
//void cursorDown(int count = 1)
//{
//
//}

class CommandManager
{
	// Runtime check that only one instance is created ie. not for use in singleton pattern.
	private static CommandManager _the; // assert only singleton
    private int _nextCompletionSessionID = 1;
    private Command[int] _completionSessions;

    this()
	{
		assert(_the is null);
		_the = this;
	}

	// name -> Command
	Command[string] commands;

	// TODO: Rename to create(..) when dmd supports overloading on parameter that is delegates with different params. Currently this method
	//       conflicts with the method below because of dmd issues.
	DelegateCommand create(string name, string description, CommandParameterDefinitions paramDefs,
						   void delegate(CommandParameter[]) executeDel,
						   void delegate(CommandParameter[]) undoDel = null)
	{
		auto c = new DelegateCommand(name, description, paramDefs, executeDel, undoDel);
		add(c);
		return c;
	}

	//DelegateCommand create(T)(string name ,string description, void delegate(Nullable!T) executeDel, void delegate(Nullable!T) undeDel = null) if ( ! is(T == class ))
	//{
	//    create(name, description,
	//           (Variant v) {
	//                auto d = v.peek!(Nullable!T);
	//                if (d is null)
	//           },
	//           undoDel is null ? null : (Variant) { });
	//}

	//DelegateCommand create(T)(string name ,string description, void delegate(T) executeDel, void delegate(T) undeDel = null) if ( is(T == class ))
	//{
	//    static assert(0);
	//}


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
		enforceEx!Exception(!(command.name in commands), text("Trying to add existing command ", command.name, " ", command.classinfo.name));
		commands[command.name] = command;
	}

	/** Remove a command
	 */
	void remove(string commandName)
	{
		commands.remove(commandName);
	}

    void remove(bool delegate(string, Command) pred)
	{
        // TODO: Do smarter
        bool doCheck = true;
        while (doCheck)
        {
            doCheck = false;
            foreach (k; commands.byKey)
            {
                if (pred(k, commands[k]))
                {
                    commands.remove(k);
                    doCheck = true;
                    break;
                }
            }
        }
	}

	void execute(CommandCall c)
	{
		auto cmd = lookup(c.name);
		execute(cmd, c.arguments);
	}

	void execute(string cmdName, CommandParameter[] args = null)
	{
		auto cmd = lookup(cmdName);
		execute(cmd, args);
	}

	void execute(T)(string cmd, T arg1)
	{
        execute(cmd, [ CommandParameter(arg1) ]);
    }

	void execute(Command cmd, CommandParameter[] args)
	{
		// TODO: handle fibers
		if (cmd !is null && cmd.canExecute(args))
		{
			import core.thread;
			if (cmd.mustRunInFiber)
				new Fiber( () { cmd.execute(args); } ).call();
			else
				cmd.execute(args);
		}
	}

    void parseArgumentsAndExecute(string cmdName, string argsString)
    {
        auto cmd = lookup(cmdName);
        if (cmd is null)
            return; // TODO: error handling

        CommandParameter[] args;
        auto defs = cmd.getCommandParameterDefinitions();
        if (defs !is null)
            defs.parseValues(args, argsString);
        execute(cmd, args);
    }

    CommandParameter[] parseCommandArguments(string cmdName, string argsString)
    {
        auto cmd = lookup(cmdName);
        if (cmd is null)
            return null;

        CommandParameter[] args;
        auto defs = cmd.getCommandParameterDefinitions();
        if (defs !is null)
            defs.parseValues(args, argsString);
        return args;
    }

    bool executeWithMissingArguments(Command cmd, ref CommandParameter[] args)
    {
		// TODO: handle fibers
		if (cmd !is null)
		{
			import core.thread;
			if (cmd.mustRunInFiber)
            {
				new Fiber( () { cmd.executeWithMissingArguments(args); } ).call(); // TODO: handle return value
            }
			else
            {
				return cmd.executeWithMissingArguments(args);
            }
		}
        return false;
    }

	Command lookup(string commandName)
	{
		auto c = commandName in commands;
		if (c) return *c;
		return null;
	}

	Command[] lookupFuzzyOld(string searchString)
	{
		Command[] result;
		size_t len = searchString.length;
		foreach (key, cmd; commands)
		{
			if (key.startsWith(searchString))
				result ~= cmd;
		}
		return result;
	}

	Command[] lookupFuzzy(string searchString, bool includeEmptySearch = false)
    {
        import std.algorithm;
        import std.array;
        import util.string;

        return commands
            .byKeyValue
            .map!(a => tuple(a.key.rank(searchString), a.value))
            .filter!(a => a[0] > 0.0 || includeEmptySearch)
            .array
            .sort!((a,b) => a[0] > b[0])
            .map!(a => a[1])
            .array;

/*
		static struct SortEntry
        {
            double rank;
            Command cmd;
        }
commands.
        SortEntry[] entries;
		foreach (key, cmd; commands)
		{
            auto r = key.rank(searchString);
            if (r != 0.0)
                entries ~= SortEntry(r, cmd);
        }

        Command[] result;
        return entries
            .map!(a => a.cmd)
            .array();
        */
    }

    int beginCompletionSession(string cmdName)
    {
        auto cmd = lookup(cmdName);
        if (cmd is null)
            return -1;

        if (cmd.beginCompletionSession(_nextCompletionSessionID++))
        {
            _completionSessions[_nextCompletionSessionID-1] = cmd;
            return _nextCompletionSessionID-1;
        }
        return -1; // cmd disallowed the session
    }

    bool endCompletionSession(int sessionID)
    {
        if (auto s = sessionID in _completionSessions)
        {
            s.endCompletionSession();
            _completionSessions.remove(sessionID);
            return true;
        }
        return false;
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
