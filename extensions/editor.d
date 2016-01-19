module extensions.editor;

import extensionapi;
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
void help(Application app)
{
    enum helpBufferName = "*Help*";
    app.addMessage("Showing help");

    if (!app.hasBuffer(helpBufferName))
        app.createBuffer(helpBufferName).insert(helpText);

	app.showBuffer(helpBufferName);
}

@MenuItem("Quit")
@Shortcut("<ctrl> + x <ctrl> + c")
void editorQuit(Application app)
{
	app.quit();
}

private void dmp(Widget w, string prefix, ref CompletionEntry[] entries)
{
    string cn = w.classinfo.name;
	auto p = cn.findSplitAfter("controls.");
	if (p[0].empty)
		p = cn.findSplitAfter("gui.");

	if (!p[0].empty)
	{
		cn = p[1];
		cn.munch("^.");
		cn = cn[1..$];
	}
        else
        {
		p = cn.findSplitAfter("extensions.base.BasicWidgetWrap!(");

            if (!p[0].empty)
            {
                cn = p[1];
                cn = cn.munch("^)");
            }
        }

        if (cn.startsWith(prefix))
        {
            if (w.name.empty)
                entries ~= CompletionEntry(format("(%s %s)", cn, w.id), cn);
            else
                entries ~= CompletionEntry(format("%s (%s %s)", w.name, cn, w.id), cn);
        }

        foreach (wc; w.children)
            dmp(wc, prefix, entries);
    }


private struct WidgetNameRank
{
    string label;
    string value;
    double rank;
}

private void dmp2(Widget w, string match, ref WidgetNameRank[] entries)
{
    string cn = w.classinfo.name;
	auto p = cn.findSplitAfter("controls.");
	if (p[0].empty)
		p = cn.findSplitAfter("gui.");

	if (!p[0].empty)
	{
		cn = p[1];
		cn.munch("^.");
		cn = cn[1..$];
	}
    else
    {
		p = cn.findSplitAfter("extensions.base.BasicWidgetWrap!(");

        if (!p[0].empty)
        {
            cn = p[1];
            cn = cn.munch("^)");
        }
    }

    import util.string;
    double r = cn.rank(match);
    if (r != 0.0)
    {
        if (w.name.empty)
            entries ~= WidgetNameRank(format("(%s %s)", cn, w.id), cn, r);
        else
            entries ~= WidgetNameRank(format("%s (%s %s)", w.name, cn, w.id), cn, r);
    }

    foreach (wc; w.children)
        dmp2(wc, match, entries);
}


@Shortcut("<ctrl> + b")
class EditorShowWidgetCommand : BasicCommand
{
	void run(string widgetName)
	{
		if (auto w = app.getWidget(widgetName))
	    {
		    w.visible = true;
	    }
	    else
	    {
	        app.addMessage("Cannot show widget '%s'", widgetName);
	    }
	}

	override CompletionEntry[] getCompletions(CommandParameter[] data)
	{
        import std.array;
        string match = data[0].get!string();
        WidgetNameRank[] entries;
        dmp2(app.activeWindow, match, entries);

        CompletionEntry[] result;
        return entries
                 .sort!((a,b) => a.rank > b.rank)
                 .map!(a => CompletionEntry(a.label, a.value))
                 .array();
	}
}


@Shortcut("<ctrl> + <shift> + b")
class EditorHideWidgetCommand : BasicCommand
{
	void run(string widgetName)
	{
		if (auto w = app.getWidget(widgetName))
	    {
		    w.visible = false;
	    }
	    else
	    {
	        app.addMessage("Cannot hide widget '%s'", widgetName);
	    }
	}

	override CompletionEntry[] getCompletions(CommandParameter[] data)
	{
        import std.array;
        string match = data[0].get!string();
        WidgetNameRank[] entries;
        dmp2(app.activeWindow, match, entries);

        CompletionEntry[] result;
        return entries
            .sort!((a,b) => a.rank > b.rank)
            .map!(a => CompletionEntry(a.label, a.value))
            .array();
	}
}

@MenuItem("Tools/List Widgets...")
void editorListWidgets(Application app, string widgetName)
{
	if (auto w = app.getWidget(widgetName))
	    w.visible = false;
}

version(off):
class EditorExtension : Extension
{

}
