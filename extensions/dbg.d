module extensions.dbg;

import extensions;
mixin registerCommands;

import controls.tree;

void dbgDumpWidgetHierarchy(GUIApplication app, BufferView bv)
{
	import std.conv;
	import std.algorithm;
	import std.range;
	import std.string;

    string treeName = "WidgetHierarchyTree";
	Tree hier = cast(Tree)app.getWidget(treeName);
    assert(hier);
    auto owner = cast(WidgetHierarchy) hier.parent;
    assert(owner);
    owner.visible = true;
    owner.children[0].visible = true;

	bv.clear();
	void dmp(Widget w, string indent, bool dumpText)
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

		if (dumpText)
        {
            import std.stdio;
			// bv.insert(dtext(indent, cn, "(", w.id, "): ", w.name, "\n"));
			writeln(text(indent, cn, "(", w.id, "): ", w.name));
            indent = indent ~ "  ";
        }
        else
        {
            indent = text(indent.empty ? "" : indent ~ "/",  cn , "(", w.id, ")");
           // writeln(indent);
            if (w.name == treeName)
            {
                hier.addTreeItem(indent ~ "...");
                return; // do not dump children of the tree itself
            }
            else
            {
                hier.addTreeItem(indent);
            }
        }

 		foreach (c; w.children)
            dmp(c, indent, dumpText);
	}

	dmp(app.activeWindow, "", false);
	dmp(app.activeWindow, "", true);
}


class WidgetHierarchy : BasicWidget
{
	override void init()
	{
        name = "WidgetHierarchy";
        add!Button("close").onActivated.connect(&close);
        add!Tree().name  = "WidgetHierarchyTree";
        visible = false;
    }

    void close(Button b)
    {
        visible = false;
        children[0].visible = false;
        auto h = children[1];
        foreach (c; h.children)
            c.destroyRecurse();
    }
}


