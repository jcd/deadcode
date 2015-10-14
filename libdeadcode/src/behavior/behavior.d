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

    @property KeyBindingsSet currentKeyBindingsSet()
    {
        return keyBindings.keyBindings();
    }

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
        import std.stdio;
		version (linux)
            writeln("NullBehavior got event ", event, " Window ID: ", event.windowID);
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

        switch (key)
        {
            case "currentBufferName":
			    return app.currentBuffer.name;
            case "focusWidgetName":
            {
                import guiapplication;
                auto a = cast(GUIApplication) app; // TODO: get rid of cast
                if (auto w = a.activeWindow.getKeyboardFocusWidget())
                    return w.name;
                break;
            }
            case "focusWidgetBranchNames":
            {
                import guiapplication;
                auto a = cast(GUIApplication) app; // TODO: get rid of cast
                if (auto w = a.activeWindow.getKeyboardFocusWidget())
                {
                    string names = w.name;
                    w = w.parent;
                    while (w !is null)
                    {
                        names ~= "," ~ w.name;
                        w = w.parent;
                    }
                    return names;
                }
                return ""; // no focus widget
                // break;
            }
            case "languageName":
			    if (auto m = app.currentBuffer.codeModel)
                {
                    return m.name;
                }
                else
                {
                    return "";
                }
            default:
                break;
        }

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
