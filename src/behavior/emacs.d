module behavior.emacs;

import application;
import core.bufferview;
import core.command;
import graphics._;
import gui.event;
import gui.keybinding;
import gui.keycode;
import gui.ruleset;
import gui.widget;
import gui.widgetfeature.textrenderer;
import gui.window;

public import behavior.behavior : EditorBehavior;
import behavior.behavior : RuleEnv, KeyBindingRuleEnv;


import std.array;
import std.variant;

class EmacsBehavior : EditorBehavior
{
	KeyBindingStack keyBindings;
	RuleEnv ruleEnv;
	CommandManager commandManager;


	private bool _skipNextTextEvent = false;

	void setup()
	{
		KeyBindingsSet set = new KeyBindingsSet();
		keyBindings = new KeyBindingStack();
		keyBindings.push(set);
	
		// Register emacs behavior as an option
		set.setKeyBinding("<ctrl> + v", "edit.scrollPageDown");
		set.setKeyBinding("<alt> + v", "edit.scrollPageUp");
		set.setKeyBinding("<pagedown>", "edit.scrollPageDown");
		set.setKeyBinding("<pageup>", "edit.scrollPageUp");
		set.setKeyBinding("<ctrl> + a", "edit.cursorToBeginningOfLine");
		set.setKeyBinding("<ctrl> + e", "edit.cursorToEndOfLine");
		set.setKeyBinding("<ctrl> + <shift> + a", "edit.selectToBeginningOfLine");
		set.setKeyBinding("<ctrl> + <shift> + e", "edit.selectToEndOfLine");
		set.setKeyBinding("<ctrl> + <shift> + <left>", "edit.selectToWordBefore");
		set.setKeyBinding("<ctrl> + <shift> + <right>", "edit.selectToWordAfter");
		set.setKeyBinding("<ctrl> + <backspace>", "edit.deleteWordBefore");
		set.setKeyBinding("<ctrl> + <delete>", "edit.deleteWordAfter");
		set.setKeyBinding("<ctrl> + <left>", "edit.cursorToWordBefore");
		set.setKeyBinding("<ctrl> + <right>", "edit.cursorToWordAfter");
		set.setKeyBinding("<left>", "edit.cursorToCharBefore");
		set.setKeyBinding("<right>", "edit.cursorToCharAfter");
		set.setKeyBinding("<up>", "edit.cursorToCharAbove");
		set.setKeyBinding("<down>", "edit.cursorToCharBelow");
		set.setKeyBinding("<shift> + <left>", "edit.selectToCharBefore");
		set.setKeyBinding("<shift> + <right>", "edit.selectToCharAfter");
		set.setKeyBinding("<shift> + <up>", "edit.selectToCharAbove");
		set.setKeyBinding("<shift> + <down>", "edit.selectToCharBelow");
		set.setKeyBinding("<ctrl> + k", "edit.deleteToEndOfLine");
		set.setKeyBinding("<backspace>", "edit.deleteCharBefore");
		auto rs = new RuleSet();
		rs.addEquals("currentBufferName", "*CommandInput*");
		set.setKeyBinding("<return>", "edit.commitCompletion", Variant(), rs);
		set.setKeyBinding("<tab>", "edit.complete", Variant(), rs);
		set.setKeyBinding("<ctrl> + g", "app.toggleCommandArea", Variant(), rs);

		set.setKeyBinding("<return>", "edit.insertNewline");
		set.setKeyBinding("<ctrl> + d", "edit.deleteCharAfter");
		set.setKeyBinding("<delete>", "edit.deleteCharAfter");
		set.setKeyBinding("<ctrl> + x <ctrl> + p", "edit.clear");
		
		set.setKeyBinding("<ctrl> + x <ctrl> + f", "app.toggleCommandArea", Variant("edit.open "));
		set.setKeyBinding("<ctrl> + x b", "app.toggleCommandArea", Variant("edit.showBuffer "));
		set.setKeyBinding("<ctrl> + x <ctrl> + s", "edit.save");
		set.setKeyBinding("<ctrl> + x <ctrl> + w", "edit.saveBufferAs");
		set.setKeyBinding("<ctrl> + x <ctrl> + w", "edit.saveBufferAs");

		set.setKeyBinding("<ctrl> + /", "edit.undo");
		set.setKeyBinding("<ctrl> + _", "edit.undo");
		set.setKeyBinding("<ctrl> + x u", "edit.undo");
		set.setKeyBinding("<ctrl> + <shift> + z", "edit.redo");
		set.setKeyBinding("<ctrl> + z", "edit.undo");
		set.setKeyBinding("<ctrl> + b", "core.rebuildEditor");
		set.setKeyBinding("<ctrl> + w", "app.toggleCommandArea");

		//set.setKeyBinding("<tab>", "edit.
	}

	private KeySequence currentKeySequence;

	this(Application app)
	{
		commandManager = app.commandManager;
		ruleEnv = new KeyBindingRuleEnv(app);
	}
	
	/*
	 * Handles emacs behavior such as shortcuts etc. Note the event is passed by ref and
	 * may be changed. Therefore it this method return EventUsed.no the passed in 
	 * event should be the one that is handled from there on.
	 * Returns 
	 * 	true if the event has been used
	 */
	override EventUsed onEvent(ref Event event)
	{	

		if (keyBindings is null)
		{
			setup();
			currentKeySequence = new KeySequence("");
			
		}

		switch (event.type)
		{
			case EventType.KeyDown:
				break;
			case EventType.Text:
				if (_skipNextTextEvent)
				{
					_skipNextTextEvent = false;
					return EventUsed.yes;
				}
				break;
			default:
				return EventUsed.no; // event not used
		}
		_skipNextTextEvent = false;
	//	auto widget = window.getKeyboardFocusWidget();
	//	BufferView view = text!BufferView(widget); // There may be an attached bufferview on the widget
		if (event.type == EventType.KeyDown)
		{
			currentKeySequence.add(event.keyCode, event.mod);

			//auto fn = (KeyBinding a) => { return a.command.canExecute(Variant(1u)); };
			/*
			auto rangeResult = std.algorithm.filter!fn(keyBindings.match(currentKeySequence, true));
			KeyBinding[] b = array(rangeResult);
			 */
			KeyBinding[] matchedBindings;
			Variant dummy;
			foreach (kb; keyBindings.match(currentKeySequence, true))
			{
				auto command = commandManager.lookup(kb.command);

				// If the command is null then the command manager doesn't know about the
				// command and we assume it is valid and handled by the event dispatching to a 
				// widgets onEvent(Event e) using EventType.command.
				if (kb.validate(ruleEnv) && (command is null || command.canExecute(dummy)))
					matchedBindings ~= kb;
			}

			if (!matchedBindings.empty)
			{
				foreach (matchedBinding; matchedBindings)
				{
					if (currentKeySequence.length == matchedBinding.sequence.length)
					{
						// We got a match but since the last entered character may be without modifies this can result in a EventType.Text
						// being sent just right after the current event. We want to eat that text event.
						_skipNextTextEvent = !(event.mod & (KeyMod.CTRL | KeyMod.ALT | KeyMod.GUI));

						// First match is served so make sure the define the bindings by priority and/or use rules.
						currentKeySequence.length = 0;
						auto command = commandManager.lookup(matchedBinding.command);
						if (command !is null)
						{
							// A command is registered for this commandName
							command.execute(matchedBinding.args);
							return EventUsed.yes;
						}
						else
						{
							// No command registered with this commanName
							// We rewrite the event to a command event matching the keybinding command
							// in order to let the callers further dispatching handle the command.
							event.type = EventType.Command;
							event.name = matchedBinding.command;
							event.argument = &matchedBinding.args;
							return EventUsed.no; // re-dispatch
						}
					}
				}
				// wait for more key downs to get full key binding match
				return EventUsed.yes;
			}
	
			// No key bindings for this key event. Go enter text to editor
			currentKeySequence.length = 0;
		} 
		/*
		else if (event.type == EventType.MouseScroll && view !is null)
		{
			// Scroll view
			int d = cast(int) event.scroll.y;
			if (d < 0)
			{
				foreach (i; 0..d*d)
					view.scrollDown();
			}
			else
			{
				foreach (i; 0..d*d)
					view.scrollUp();
			}
			return EventUsed.yes;
		}

		else if (event.type == EventType.MouseClick && view !is null)
		{

			// Locate char under mouse pointer and set cursor at that char
			
		}
*/
		/*

		//std.stdio.writeln(event.type, " ", std.conv.to!string(event.mod), " ", view);
		if (view is null) return false;

		switch (event.type)
		{
		case EventType.Text:
			view.insert(event.ch);
			//std.stdio.writeln(event.ch, " ", std.conv.to!string(event.mod));
			break;
		case EventType.KeyDown:
			//handleKeyDown(event, controller);
		default:
		break;
		}
		*/

		return EventUsed.no;
	}
}
