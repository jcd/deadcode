module extensionapi;

public import extensionapi.command; // from deadcodebase.deadcodebase.extensionapi.command
public import extensionapi.registerctextensions;
//public import extensionapi.rpcapi;
public import extensionapi.rpc;
public import extensionapi.rpcclient : rpcClient;
static import dccore.command;

struct CommandShortcuts
{
    string commandName;
    Shortcut[] shortcuts;
}

struct CommandMenuItem
{
    string commandName;
    MenuItem menuItem;
}

Exception[] init(Application app, ref Command[] cmds)
{
    return initCommands(app, (dccore.command.Command c, MenuItem menuItem, Shortcut[] shortcuts, Hints hints) {
		cmds ~= c;
    });
}

void fini(Application app)
{
    finiCommands(app);
}

template registerCommandsRPC(string Mod = __MODULE__)
{
    mixin registerCommands!Mod;
    mixin rpcClient;
}
