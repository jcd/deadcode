module extensions.editor;

import extensions;
mixin registerCommands;

import std.algorithm;
import std.format;
import std.string;

string helpText = q"{ Help
------

<ctrl> + p             : show command console
<ctrl> + ,             : open file in dub project
<ctrl> + x, <ctrl> + f : open file
}";

@MenuItem("Help")
@Shortcut("<ctrl> + x <ctrl> + h")
void help(GUIApplication app)
{
    enum helpBufferName = "*Help*";
    app.addMessage("Showing help");

    if (!app.hasBuffer(helpBufferName))
        app.createBuffer(helpBufferName).insert(helpText);

	app.showBuffer(helpBufferName);
}

@MenuItem("Quit")
@Shortcut("<ctrl> + x <ctrl> + c")
void editorQuit(GUIApplication app)
{
	app.quit();
}

version(off):
class EditorExtension : BasicExtension!EditorExtension
{

}
