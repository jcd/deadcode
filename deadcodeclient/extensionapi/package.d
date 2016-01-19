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

Exception[] init(ref BasicCommand[] cmds)
{
    return initCommands((dccore.command.Command c) {
        BasicCommand bc = cast(BasicCommand)c;
        if (bc !is null)
            cmds ~= bc;
    });
}

void fini(Application app)
{
    finiCommands();
}

template registerCommandsRPC(string Mod = __MODULE__)
{
    mixin registerCommands!Mod;
    mixin rpcClient;
}
