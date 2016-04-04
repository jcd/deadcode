module extensionapi.types;

public import std.variant;
public import dccore.commandparameter : CommandParameterDefinition;

/** Attribute to specify a shortcut for for a Command or command function

	In a module that has a  "mixin registerCommands":
	A class derived from class Command or a public function use the @Shortcut attribute to 
	set the default shortcut for the command.

	Example:
	@Shortcut("<ctrl> + h")                 // Shortcut that will prompt for missing command argument
	@Shortcut("<ctrl> + m", "Hello world")  // Shortcut that with the command argument set in advance
	class SayHelloCommand : Command
	{
		this() { super(createParams("")); }

		void run(Log log, string txt)
		{
			log.info(txt);
		}
	}

	Example:
	@Shortcut("<ctrl> + u")
	void textUppercase(Application app, string dummy)
	{
		app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
	}
*/
struct Shortcut
{
	string keySequence;
	string argument;
}

/** Attribute to specify a menut item for for a Command or command function

	In a module that has a  "mixin registerCommands":
	A class derived from class Command or a public function use the @MenuItem attribute to 
	set the default menu item for the command.

	Example:
	@MenuItem("Tools/Log text")              
	class SayHelloCommand : Command
	{
		this() { super(createParams("")); }

		void run(Log log, string txt)
		{
			log.info(txt);
		}
	}

	Example:
	@MenuItem("Tools/Log text")
	void textUppercase(Application app, string dummy)
	{
		app.currentBuffer.map!(std.uni.toUpper)(RegionQuery.selectionOrWord);
	}
*/
struct MenuItem
{
	string path;
    string argument;
}
