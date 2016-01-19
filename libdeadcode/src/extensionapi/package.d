module extensionapi;

public import extensionapi.common;  // from deadcodebase.deadcodebase.extensionapi.command
public import extensionapi.command; // from deadcodebase.deadcodebase.extensionapi.command
public import extensionapi.extension;
public import extensionapi.widget;
public import extensionapi.registerctextensions;
public import extensionapi.binding;

Exception[] init(Application app)
{
    auto exs = initExtensions(app);
    exs ~= initCommands((Command c) {
        BasicCommand bc = cast(BasicCommand)c;
        if (bc !is null)
        {
            bc.app = app; // Todo: fix cast
            bc.init();
            app.addCommand(bc);
            app.addMenuItem(bc.name, bc.menuItem);
            app.addCommandShortcuts(bc.name, bc.shortcuts);
        }
    });
    exs ~= initWidgets(app);
    return exs;
}

void fini(Application app)
{
    finiExtensions(app);
    finiCommands();
    finiWidgets(app);
}

template registerCommandsRPC(string Mod = __MODULE__)
{
    // Mirroring the same template in deadcodeclient/extensionapi/package.d
    // Just a dummy here since RPC registration doesn't make sense in the editor itself
    // only in client executables using RPC to communicate with the editor.
}
