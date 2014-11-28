module behavior.emacs;

import application;
import core.bufferview;
import core.command;
import core.commandparameter;
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
	RuleEnv ruleEnv;
	CommandManager commandManager;
	bool initialized = false;

	private bool _skipNextTextEvent = false;

	void setup()
	{
		auto set = keyBindings.keyBindings;
		
		// Register emacs behavior as an option
		// set.setKeyBinding("<ctrl> + v", "edit.scrollPageDown"); 
		set.setKeyBinding("<ctrl> + x <ctrl> + c", "core.quit");
		set.setKeyBinding("<alt> + v", "edit.scrollPageUp");
		set.setKeyBinding("<pagedown>", "edit.scrollPageDown");
		set.setKeyBinding("<pageup>", "edit.scrollPageUp");
		set.setKeyBinding("<ctrl> + a", "edit.cursorToBeginningOfLine");
		set.setKeyBinding("<ctrl> + e", "edit.cursorToEndOfLine");
		set.setKeyBinding("<ctrl> + <shift> + a", "edit.selectToBeginningOfLine");
		set.setKeyBinding("<ctrl> + <shift> + e", "edit.selectToEndOfLine");
		set.setKeyBinding("<ctrl> + <shift> + <left>", "edit.selectToWordBefore");
		set.setKeyBinding("<ctrl> + <shift> + <right>", "edit.selectToWordAfter");
		set.setKeyBinding("<ctrl> + <backspace>", "edit.deleteToWordBefore");
		set.setKeyBinding("<ctrl> + <delete>", "edit.deleteToWordAfter");
		set.setKeyBinding("<ctrl> + <left>", "edit.cursorToWordBefore");
		set.setKeyBinding("<ctrl> + <right>", "edit.cursorToWordAfter");
		set.setKeyBinding("<left>", "navigate.left");
		set.setKeyBinding("<right>", "navigate.right");
		set.setKeyBinding("<up>", "navigate.up");
		set.setKeyBinding("<down>", "navigate.down");
		set.setKeyBinding("<shift> + <left>", "edit.selectToCharBefore");
		set.setKeyBinding("<shift> + <right>", "edit.selectToCharAfter");
		set.setKeyBinding("<shift> + <up>", "edit.selectToCharAbove");
		set.setKeyBinding("<shift> + <down>", "edit.selectToCharBelow");
		set.setKeyBinding("<shift> + <pagedown>", "edit.selectPageDown");
		set.setKeyBinding("<shift> + <pageup>", "edit.selectPageUp");
		set.setKeyBinding("<ctrl> + k", "edit.deleteToEndOfLine");
		set.setKeyBinding("<backspace>", "edit.deleteCharBefore");
		auto rs = new RuleSet();
		rs.addEquals("currentBufferName", "*CommandInput*");
		set.setKeyBinding("<return>", "edit.commitCompletion", rs);
		set.setKeyBinding("<tab>", "edit.complete", rs);
		set.setKeyBinding("<ctrl> + p", "app.toggleCommandArea", "", rs);

		set.setKeyBinding("<return>", "edit.insert", "\n");
		set.setKeyBinding("<tab>", "edit.insert", "\t");
		set.setKeyBinding("<ctrl> + d", "edit.deleteCharAfter");
		set.setKeyBinding("<delete>", "edit.deleteCharAfter");
		set.setKeyBinding("<ctrl> + x <ctrl> + p", "edit.clear");
		
		set.setKeyBinding("<ctrl> + <tab>", "app.cycleBuffers", 1);

		set.setKeyBinding("<ctrl> + <shift> + <tab>", "app.cycleBuffers", -1);
		
		set.setKeyBinding("<ctrl> + x <ctrl> + f", "edit.open");
		set.setKeyBinding("<ctrl> + x b", "edit.showBuffer");
		set.setKeyBinding("<ctrl> + x <ctrl> + s", "edit.save");
		set.setKeyBinding("<ctrl> + x <ctrl> + w", "edit.saveBufferAs");
		set.setKeyBinding("<ctrl> + x <ctrl> + w", "edit.saveBufferAs");

		set.setKeyBinding("<ctrl> + /", "edit.undo");
		set.setKeyBinding("<ctrl> + _", "edit.undo");
		set.setKeyBinding("<ctrl> + x u", "edit.undo");
		set.setKeyBinding("<ctrl> + <shift> + z", "edit.redo");
		set.setKeyBinding("<ctrl> + z", "edit.undo");
		set.setKeyBinding("<ctrl> + c", "edit.copy");
		set.setKeyBinding("<ctrl> + v", "edit.paste");
		set.setKeyBinding("<ctrl> + <shift> + v", "edit.pasteCycle");
		// set.setKeyBinding("<ctrl> + x", "edit.cut");

		set.setKeyBinding("<ctrl> + b", "core.rebuildEditor");
		set.setKeyBinding("<ctrl> + p", "app.toggleCommandArea", "");

		set.setKeyBinding("<f7>", "dub.build");
		set.setKeyBinding("<ctrl> + ,", "dub.quickopen");
		set.setKeyBinding("<ctrl> + i", "edit.incrFind");

		set.setKeyBinding("<alt> + /", "edit.undo");
		set.setKeyBinding("<ctrl> + g", "edit.cursorToLine");

		//set.setKeyBinding("<tab>", "edit.
	}

	private KeySequence currentKeySequence;

	this(Application app)
	{
		commandManager = app.commandManager;
		ruleEnv = new KeyBindingRuleEnv(app);
		KeyBindingsSet set = new KeyBindingsSet();
		keyBindings = new KeyBindingStack();
		keyBindings.push(set);
		currentKeySequence = new KeySequence("");
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
		if (!initialized)
			setup();

		//if (keyBindings is null)
		//{
		//    setup();
		//    currentKeySequence = new KeySequence("");
		//}

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
			CommandParameter[] dummy = null;
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
						auto commandName = matchedBinding.command;
						auto command = commandManager.lookup(commandName);
						if (command !is null)
						{
							// A command is registered for this commandName
							
							// Make sure we have the needed arguments for the command
							CommandParameter[] params;
							auto defs = command.getCommandParameterDefinitions();
							if (defs is null || defs.setValues(params, matchedBinding.args))
							{
								command.execute(params);
							}
							else
							{
								// Need more arguments. Signal this.
								onMissingCommandArguments.emit(command, params);
							}
							return EventUsed.yes;
						}
						else
						{
							// No command registered with this commandName
							// We rewrite the event to a command event matching the keybinding command
							// in order to let the callers further dispatching handle the command.
							event.type = EventType.Command;
							event.name = matchedBinding.command;
							event.argument = matchedBinding.args;
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
