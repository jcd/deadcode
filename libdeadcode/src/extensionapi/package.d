module extensionapi;

public import extensionapi.common;  // from deadcodebase.deadcodebase.extensionapi.command
public import extensionapi.command; // from deadcodebase.deadcodebase.extensionapi.command
public import extensionapi.extension;
public import extensionapi.widget;
public import extensionapi.registerctextensions;
public import extensionapi.binding;
public import poodinis : Autowire;

Exception[] init(Application app)
{
    auto exs = initExtensions(app);
    exs ~= initCommands(app, (Command c, MenuItem menuItem, Shortcut[] shortcuts, Hints hints) {
        c.onLoaded();
        app.addCommand(c);
        app.addMenuItem(c.name, menuItem);
        app.addCommandShortcuts(c.name, shortcuts);
		// TODO: handle hints
    });
    exs ~= initWidgets(app);
    return exs;
}

void fini(Application app)
{
    finiExtensions(app);
    finiCommands(app);
    finiWidgets(app);
}

template registerCommandsRPC(string Mod = __MODULE__)
{
    // Mirroring the same template in deadcodeclient/extensionapi/package.d
    // Just a dummy here since RPC registration doesn't make sense in the editor itself
    // only in client executables using RPC to communicate with the editor.
}
