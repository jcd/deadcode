module extensions.dbg;

import extensions;
mixin registerCommands;

import controls.tree;

import gui.widgetfeature.ninegridrenderer;

import gui.style;

class DebugHighlightRenderer : NineGridRenderer
{
	this()
    {
        styleName = "DebugHighlight";
    }
}

void dbgHighlightWidget(Application app, WidgetID widgetID)
{
    Widget w = app.activeWindow.getWidget(widgetID);
    if (w is null)
    {
        app.addMessage("Cannot get widget with id %s", widgetID);
    }
    else
    {
        if (w.hasFeature!DebugHighlightRenderer)
            w.removeFeaturesByType!DebugHighlightRenderer();
        else
            w.features ~= new DebugHighlightRenderer();
    }
}

void dbgDumpWidgetHierarchy(Application app)
{
	import std.conv;
	import std.algorithm;
	import std.range;
	import std.string;

    string hierName = "WidgetHierarchy";
    auto h = cast(WidgetHierarchy)app.getWidget(hierName);
    assert(h);

    string treeName = "WidgetHierarchyTree";
	Tree hier = cast(Tree)app.getWidget(treeName);
    assert(hier);
    auto owner = cast(WidgetHierarchy) hier.parent.parent.parent;
    assert(owner);
    owner.visible = true;
    owner.children[0].visible = true;

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
			version (linux)
                writeln(text(indent, cn, "(", w.id, "): ", w.name));
            indent = indent ~ "  ";
        }
        else
        {
            indent = text(indent.empty ? "" : indent ~ "/",  cn , "(", w.id, ")");
           // writeln(indent);
            if (w.name == treeName)
            {
                auto item = hier.addTreeItem(indent ~ "...");
                item.userData = w.id;
                return; // do not dump children of the tree itself
            }
            else
            {
                auto item = hier.addTreeItem(indent, "dbg.highlightWidget", [ CommandParameter(w.id) ]);
                item.userData = w.id;
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
	private ScrollView _scrollView;

    override void init()
	{
        name = "WidgetHierarchy";
        auto lo = add!Widget(this);
        lo.name = "Buttons";
        auto glo = new GridLayout(GridLayout.Direction.row, 1);
        glo.cellHorizontalSpacing = 8;
        lo.layout = glo;
        lo.add!Button("close").onActivated.connect(&close);
        lo.add!Button("foo").onActivated.connect(&close);

        _scrollView = add!ScrollView(Vec2f(400, 3000));
        visible = false;
    }

    private void eventDispatched(Widget w, Event ev)
    {
        auto cw = cast(Tree) _scrollView.children[0].getChildByName("WidgetHierarchyTree");
        if (cw is null)
            return;

        Tree activeItem = cw.getTreeItemByUserData(w.id);
        if (activeItem is null)
            return;

        if (ev.type == EventType.MouseOver)
        {
            activeItem.features ~= new DebugHighlightRenderer();
            auto l = cast(Label) activeItem.children[0].children[0];
            l.text = "--" ~ l.text;
        }
        else if (ev.type == EventType.MouseOut)
        {
            activeItem.removeFeaturesByType!DebugHighlightRenderer();
            auto l = cast(Label) activeItem.children[0].children[0];
            l.text = l.text[2..$];
        }
    }

    private void commandTriggered(CommandCall cc)
    {
        app.commandManager.execute(cc);
    }

    override @property void visible(bool v)
    {
        if (v == super.visible)
            return;

        super.visible = v;
        if (v)
            enableTree();
        else
            disableTree();
    }

    private void enableTree()
    {
        Tree tree = _scrollView.contentWidget.add!Tree();
        tree.name  = "WidgetHierarchyTree";
        tree.commandTriggered.connect(&commandTriggered);
        window.onDispatchEvent.connect(&eventDispatched);
        dbgDumpWidgetHierarchy(app);
    }

    private void disableTree()
    {
        foreach (c; _scrollView.contentWidget.children)
            c.destroyRecurse();
        window.onDispatchEvent.disconnect(&eventDispatched);
    }

    void close(Button b)
    {
        visible = false;
    }
}


