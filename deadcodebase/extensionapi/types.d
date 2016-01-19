module extensionapi.types;

public import std.variant;
public import dccore.commandparameter : CommandParameterDefinition;

struct Shortcut
{
	string keySequence;
	string argument;
}

struct MenuItem
{
	string path;
    string argument;
}
