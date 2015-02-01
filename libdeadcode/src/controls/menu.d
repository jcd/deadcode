module controls.menu;

import controls.button;
import controls.tree;

import core.command;

import gui.event;
import gui.widget;
import gui.widgetfeature.windowdragger;

import core.signals;
import std.stdio;
import std.typetuple;

struct MenuItem
{
	string path;
}

enum isMenuItem(alias T) = is(typeof(T) == MenuItem);

alias hasMenuItemAttribute(alias what) = anySatisfy!(isMenuItem, __traits(getAttributes, what));
// enum hasMenuItemAttribute(what) = false;
enum getMenuItemAttribute(alias what) = Filter!(isMenuItem, __traits(getAttributes, what))[0];

class Menu : Tree
{
	Button menuButton;
	CommandManager commandManager;

	mixin Signal!(Command, CommandParameter[]) onMissingCommandArguments;

	alias parent = Widget.parent;
    @property override void parent(Widget newParent) nothrow
	{
		menuButton.parent = newParent;
		super.parent = newParent;
	}

	this(CommandManager cmdMgr)
	{
        super();
		commandManager = cmdMgr;
		// Menu
		hidden = true;
		acceptsKeyboardFocus = true;
		onKeyboardUnfocusCallback = (Event ev, Widget w) {
			this.hidden = true;
			return EventUsed.yes;
		};

		//addTreeItem("Bar/Bazzimusss", "edit.scrollPageDown");
		//addTreeItem("Bar/Baxx");
		//addTreeItem("Lars");

		menuButton = new Button("Menu");

        menuButton.features ~= new WindowDragger();
		menuButton.name = "menuButton";
		menuButton.zOrder = 99;
		menuButton.onMouseOverCallback = (Event, Widget) {
			this.hidden = false;
			return EventUsed.yes;
		};

		menuButton.onMouseClickCallback = (Event, Widget) {
			this.hidden = !this.hidden;
			return EventUsed.yes;
		};

		treeClicked.connect(&onMenuClicked);
		commandTriggered.connect(&onCommandCall);
	}

	private void onMenuClicked(Tree t)
	{
		std.stdio.writeln("Hello from " ~ t.name);
	}

	private void onCommandCall(CommandCall cc)
	{
		auto cmd = commandManager.lookup(cc.name);
		if (cmd is null)
			return;

		auto defs = cmd.getCommandParameterDefinitions();
		CommandParameter[] params;
		if (defs is null || defs.setValues(params, cc.arguments))
			commandManager.execute(cc);
		else
			onMissingCommandArguments.emit(cmd, params);
	}
}
