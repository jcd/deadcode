module behavior.behavior;

public import core.buffer;
import core.bufferview;
import core.commandparameter;
import core.command;
import application;
public import graphics;
import gui.event;
import gui.keybinding;
import gui.ruleset;
import gui.window;

import core.signals;

class EditorBehavior // : KeyBindingValidator
{
	KeyBindingStack keyBindings;

	// (commandName, arguments provided)
	mixin Signal!(Command, CommandParameter[]) onMissingCommandArguments;

	/*
	bool validate(Window window)
	{
		auto env = new KeyBindingRuleEnv(window);
		return rules.test(env);
	}
*/

	abstract EventUsed onEvent(ref Event event);
}

class NullBehavior : EditorBehavior
{
	override EventUsed onEvent(ref Event event)
	{
		std.stdio.writeln("NullBehavior got event ", event, " Window ID: ", event.windowID);
		return EventUsed.no;
	}
}

class KeyBindingRuleEnv : RuleEnv
{
	Application app;

	this(Application a)
	{
		app = a;
	}

	override bool lookupBoolValue(string key)
	{
		// Lookup the value for the rule operand
		if (key == "hasSelection")
		{
			if (app.currentBuffer is null)
				return false;
		}
		// auto_complete_visible
		// has_prev_field
		// has_prev_field
		// overlay_visible
		// panel_visible

		throw new InvalidRuleKeyError(key);
	}

	override int lookupIntValue(string key)
	{
		// Lookup the value for the rule operand
		// num_selections
		//
		return 0;
	}

	override string lookupStringValue(string key)
	{
		// Lookup the value for the rule operand
		if (app.currentBuffer is null)
			return null;

		if (key == "currentBufferName")
			return app.currentBuffer.name;
		/*
		if (key == "followingText")
			return app.currentBuffer.followingText;
		else if (key == "precidingText")
			return app.currentBuffer.precedingText;
		else if (key == "lineText")
			return app.currentBuffer.lineText;
		else if (key == "currentBufferName")
			return app.currentBuffer.name;
		// setting.x
	*/
		throw new InvalidRuleKeyError(key);
	}
}
