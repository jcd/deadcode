module extensions.editor;

import extensions;
mixin registerCommands;

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
