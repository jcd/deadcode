module controls.tree;

import core.commandparameter;

import math;

import gui.event;
import gui.widget;

import std.array;
import std.conv;
import std.range;
import core.signals;

import gui.layout.directionallayout;
import gui.widgetfeature.textrenderer;

class Tree : Widget
{
	private
	{
		CommandCall commandCall;
		@property int treeDepth() const pure nothrow
		{
			import std.typecons;

			int i = 0;
			auto it = rebindable(this);
			while (it.parentTree !is null)
			{
				it = it.parentTree;
				++i;
			}
			return i;
		}

		@property bool isLeaf() const pure nothrow @safe
		{
			foreach (c; _children)
			{
				if (cast(const(Tree))c !is null)
					return false;
			}
			return true;
		}

		Tree root;
		bool _hidden = false;
	}

	@property bool hidden() const pure nothrow @safe
	{
		return _hidden;
	}
	@property void hidden(bool b)
	{
		if (_hidden != b)
			_hidden = b;

		if (!_hidden)
			setKeyboardFocusWidget();
	}

	mixin Signal!(Tree) treeClicked;
	mixin Signal!(CommandCall) commandTriggered;

	enum _leafClasses = [ "leaf" ];
	enum _treeClasses = [ "internal" ];
	enum _nodeClasses = [ "node" ];
	enum _rootClasses = [ "root" ];
	enum _hiddenClasses = [ "hidden" ];

	override const(string[]) classes() const pure nothrow @safe {


		if (hidden)
			return _hiddenClasses;
		else if (root is this)
	        return _rootClasses;
	    else if (isLeaf)
		{
            return _leafClasses;
            //bool nodeWithSubtrees = this !is root && parentTree._children.length != 1;
            //if (nodeWithSubtrees)
            //    return _nodeClasses;
            //else
            //    return _leafClasses;
		}
	    else
	        return _treeClasses;
	}

	private Tree getTreeByPath(string[] path)
	{
		Widget w = root;
		foreach (segment; path)
		{
			w = w.getChildByName(root.id.to!string ~ "!" ~ segment);
			if (w is null)
				break;
		}

		return cast(Tree) w;
	}

	@property Tree parentTree() pure nothrow @safe
	{
		return cast(Tree) _parent;
	}

	@property const(Tree) parentTree() pure nothrow @safe const
	{
		return cast(const(Tree)) _parent;
	}


	alias parent = Widget.parent;

	@property override void parent(Widget newParent) nothrow
	{
		super.parent = newParent;
		Tree p = cast(Tree) newParent;
		if (p is null)
			root = this;
		else
			root = p.root;
	}

    this()
	{
		super();
		root = this;
		zOrder = 50;
		layout = new VerticalLayout(false);
	}

	Tree addTreeItem(string path, string commandName = null, CommandParameter[] arguments = null)
	{
		return addTreeItem(path.split('/'), commandName, arguments);
	}

	private Tree addTreeItem(string[] pathSegments, string commandName = null, CommandParameter[] arguments = null)
	{
		assert(!pathSegments.empty);
		auto childName = pathSegments[0];
		Tree parentTreeForItem = getTreeByPath(pathSegments[0..$-1]);
		if (parentTreeForItem is null)
			parentTreeForItem = addTreeItem(pathSegments[0..$-1], null, null);

		string itemName = pathSegments[$-1];
        auto item = new Tree();
        item.name = root.id.to!string ~ "!" ~ itemName;
		item.parent = parentTreeForItem;
		import gui.label;
		auto leaf = new Tree();
        leaf.name = item.name ~ "/leaf";
		leaf.parent = item;
		leaf.zOrder = 100;
		leaf.commandCall = CommandCall(commandName, arguments);
		leaf.onMouseClickCallback = (Event, Widget) {
			// Need indirection through leaf in case leaf is being reparented at some point
			leaf.root.treeClicked.emit(leaf);
			if (leaf.commandCall.name !is null)
			{
				leaf.root.commandTriggered.emit(leaf.commandCall);
				import gui.event;
				root.hidden = true;
				return EventUsed.yes;
			}
			return EventUsed.no;
		};

		auto l = new Label(itemName);
		l.parent = leaf;
        int leafID = leaf.id;
		return item;
	}

	override void layoutChildren(bool fit, Widget positionReference)
	{
		static import gui.style;

        super.layoutChildren(fit, positionReference);
		if (isLeaf)
		{
			gui.style.Style st = style;
			Vec2f offset = Vec2f(20, 0);
			st.getProperty("offset", offset);
			int depth = treeDepth - 1;

			// First child is label
			foreach (c; children)
			{
				Tree t = cast(Tree) c;
				if (t is null)
					c.moveBy(depth * offset.x, offset.y);
			}
		}
	}

	override void draw()
	{
		if (!visible)
			return;

		import derelict.opengl3.gl3;

		Rectf r = rect;
		r.y = window.size.y - (r.h + r.y);

		glScissor( cast(int)r.x, cast(int)r.y, cast(int)r.w, cast(int)r.h);
		glEnable(GL_SCISSOR_TEST);
		super.draw();
		glDisable(GL_SCISSOR_TEST);
	}

	//override EventUsed onMouseOut(Event event)
	//{
	//    // Look if any ancestor is the root of the tree for the new "over" widget
	//
	//    Widget w = window.getWidget(event.overWidgetID);
	//
	//    while (w !is null)
	//    {
	//        Tree p = cast(Tree) w;
	//        if (p !is null)
	//        {
	//            hidden = p.root !is root;
	//            return EventUsed.no;
	//        }
	//        w = w.parent;
	//    }
	//
	//    hidden = true;
	//    return EventUsed.no;
	//}
}
