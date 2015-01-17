module controls.command;

import guiapplication;
import controls.texteditor;
import controls.textfield;
import core.bufferview;
import core.command : CommandManager, Command, CompletionEntry, Hints;
import core.commandparameter;
import graphics._;
import gui.event;
import gui.keycode;
import gui.models;
import gui.style;
import gui.styledtext;
import gui.widget;
import gui.widgetfeature._;
import math._;

import std.algorithm;
import std.array;
import std.conv;

import std.string;
import std.range;
import std.regex;

class CompletionListStyler : TextStyler
{
	enum CompletionStyle
	{
		other = 0,
		seleted = 1
	}

	int lineHighlighted = 0;
	int lastLineHighlighted = -1;

	this(BufferView text)
	{
		super();
		text.onInsert.connect(&textInsertedCallback);
		text.onRemove.connect(&textRemovedCallback);
	}

	override protected void textInsertedCallback(BufferView b, BufferView.BufferString str, int from)
	{
		super.textRemovedCallback(b, str, from);
		reset();
	}

	override protected void textRemovedCallback(BufferView b, BufferView.BufferString str, int from)
	{
		super.textRemovedCallback(b, str, from);
		reset();
	}

	void reset()
	{
		lineHighlighted = 0;
		lastLineHighlighted = -1;
	}

	protected override void styleBufferViewRegion(Region r, BufferView text)
	{
		// Region ignored. Just restyle all.

		if (lastLineHighlighted == lineHighlighted)
			return;
		
		lastLineHighlighted = lineHighlighted;

		// Highlight the selected line and rest in default color
		regionSet.clear();

		auto ends = text.buffer.lineEndsAtLineNumber(lineHighlighted);
		
		assert(ends[0] >= 0 && ends[0] <= text.length);
		assert(ends[1] >= 0 && ends[1] <= text.length);

		//uint lineStartIdx = text.buffer.startAtLineNumber(lineHighlighted);
		//uint lineEndIdx = text.buffer.offsetToEndOfLine(lineStartIdx);
				
		//auto selRegion = Region(lineStartIdx, lineEndIdx);
		//auto allRegion = Region(0, text.length);
		//
		//auto res = allRegion.intersect3(selRegion);
		//
		//if (!res.before.empty)
		//    rset.add(res.before.a, res.before.b, defaultID);
		//    rset.add(0, lineStartIdx, defaultID);

		if (ends[1] == 0)
		{
			onChanged.emit();
			return;
		}

		if (ends[0] != 0)
			regionSet.merge(0, ends[0], CompletionStyle.other);

		regionSet.merge(ends[0], ends[1], CompletionStyle.seleted);
		
		if (ends[1] != text.length)
			regionSet.merge(ends[1], text.length, CompletionStyle.other);
		onChanged.emit();
	}

	override string styleIDToName(int id)
	{
		CompletionStyle styleID = cast(CompletionStyle)id;
		final switch(styleID)
		{
			case CompletionStyle.other:
				return "completion-other";
			case CompletionStyle.seleted:
				return "completion-selected";
		}
	}
}

class CommandControl : Widget
{
	float height; // height when control is visible
	float onelineHeight;

	mixin styleProperty!("float", "expandDuration");

	enum Mode 
	{
		hidden,
		oneline,
		twoline,
		multiline,
	}

	Mode _mode = Mode.hidden;

	//float expandDuration; //
	float contractDuration; //

	TextField commandField;
	TextEditor completionWidget;
	CompletionListStyler completionStyler;
	
	WidgetID resumeWidgetID;
	string[string] commandMap;
	GUIApplication app;

	private bool _completionsEnabled = true;

	// If > 0 we are cycling buffers on next app.cycleBuffers command and
	// ending the cycling on <ctrl> key up. 
	// TODO: figure out a way to not have <ctrl> up hardcoded as end event
	int cycleBufferStartOffset; 
	string[] cycleBufferNames; // only used while cycling buffers
	@property bool isBufferCycleMode() const
	{
		return cycleBufferStartOffset >= 0;
	}

	@property Mode mode() const pure nothrow @safe
	{
		return _mode;
	}

	//private @property void mode(Mode m) pure 
	//{
	//	_mode = m;
		//final switch (m)
		//{
		//case Mode.oneline:
		//    completionWidget.visible = false;
		//    break;
		//case Mode.twoline:
		//    completionWidget.visible = true;
		//    break;
		//case Mode.multiline:
		//    completionWidget.visible = true;
		//    break;
		//}
//	}

	enum _classes = [["hidden"],["oneline"], ["twoline"], ["multiline"]];

	override protected @property const(string[]) classes() const pure nothrow @safe
	{
		return _classes[mode];
	}

	// Widget bottomWidget;

	this(Widget parent, float _height, BufferView bufView, GUIApplication _app)
	{
		super(parent);
		app = _app;
		commandMap = [ "f" : "edit.open", "b" : "edit.showBuffer" ];
		
		expandDuration = 0.10f;
		clearExpandDuration();
		contractDuration = 0.03f;
		height = _height;
		onelineHeight = 24;
		
		acceptsKeyboardFocus = true;
		h = 0;
		// visible = false;
		cycleBufferStartOffset = -1; // cycling off initially

		// Layout
		features ~= new VerticalLayout;

		// Command text entry field
		commandField = new TextField(this, bufView);
		commandField.h = 32;
		commandField.bufferView.onInsert.connect(&handleBufferChanged);
		commandField.bufferView.onRemove.connect(&handleBufferChanged);
		commandField.name = "commandEntryField";
		commandField.onCommandCallback = (Event event, Widget w) => onCommand(event);
		commandField.onKeyDownCallback = (Event event, Widget w) => onKeyDown(event);
		commandField.onKeyUpCallback = (Event event, Widget w) => onKeyUp(event);

		// Child widget showing the completions
		auto completionView = app.bufferViewManager.create();
		completionWidget = new TextEditor(this, completionView);
		completionStyler = new CompletionListStyler(completionView);
		completionWidget.renderer.textStyler = completionStyler;
		completionWidget.renderer.cursorSupported = false;
		completionWidget.name = "commandCompletion";
		//completionWidget.h = 180; // TODO: vert layout should instead just use remaining space so we do not have to specify this.

		onKeyboardFocusCallback = (Event ev, Widget w) {
			app.currentBuffer = commandField.bufferView;
			return EventUsed.yes;
		};

		onKeyboardUnfocusCallback = (Event ev, Widget w) {
			hide();
			return EventUsed.yes;
		};
	}

	override EventUsed onMouseClick(Event event)
	{
		if (!isShown)
			show(Mode.multiline);
		return EventUsed.yes;
	}

	override EventUsed onKeyDown(Event ev)
	{
		if (ev.keyCode == stringToKeyCode("escape"))
		{
			hide();
			clearCompletions();
		}
		else if (ev.keyCode == stringToKeyCode("return"))
		{
			hide();
			executeCommand();
		}
		else if (ev.mod == 0 && isBufferCycleMode)
		{
			hide();
			endCycleBufferMode();
		}
		else 
		{
			return EventUsed.no;
		}
		return EventUsed.yes;
	}

	override EventUsed onKeyUp(Event ev)
	{
		if (ev.mod == 0 && isBufferCycleMode)
		{
			hide();
			endCycleBufferMode();
		}
		else 
		{
			return EventUsed.no;
		}
		return EventUsed.yes;
	}

	override void draw()
	{
		if (!visible)
			return;

		auto tup = completionWidget.bufferView.buffer.lineEndsAtLineNumber(completionStyler.lineHighlighted);
		completionWidget.bufferView.selection = Region(tup[0], tup[1], 0);
		// completionWidget.renderer.selectionStyle = "completionListBox";
		super.draw();
	}

	override EventUsed onCommand(Event event)
	{
		switch (event.name)
		{
		case "edit.commitCompletion":
			hide();
			executeCommand();
			return EventUsed.yes;
		case "edit.complete":
			completeCommand();
			return EventUsed.yes;
		case "edit.incrFind":
			if (visible)
			{
				
			}
			else
			{
				setCommand("edit.incrFind");
				hide();
			}
			return EventUsed.yes;
		case "navigate.up":
			navigateUp();
			return EventUsed.yes;
		case "navigate.down":
			navigateDown();
			return EventUsed.yes;
		case "navigate.right":
			if (commandField.bufferView.isCursorAtEndOfline())
			{
				completeCommand();
				return EventUsed.yes;
			}
			break;
		//case "edit.scrollPageUp":
		//    auto scrollLineCount = to!int(completionWidget.bufferView.visibleLineCount * 0.70f);
		//    foreach (i; 0..scrollLineCount)
		//        navigateUp();
		//    break;
		//case "edit.scrollPageDown":
		//    auto scrollLineCount = to!int(completionWidget.bufferView.visibleLineCount * 0.70f);
		//    foreach (i; 0..scrollLineCount)
		//        navigateDown();
		//    break;
		case "app.cycleBuffers":
			import std.conv;

			int val = 1;
			auto valPtr = event.argument[0].peek!string();
			if (valPtr !is null)
				val = (*valPtr).to!int();
	
			cycleBuffers(val);
			break;
		default:
			break;
		}
		return EventUsed.no;
	}

	void navigateUp()
	{
		if (completionStyler.lineHighlighted > 0)
		{
			completionStyler.lineHighlighted--;
			if (completionStyler.lineHighlighted < completionWidget.bufferView.lineOffset)
				completionWidget.bufferView.scrollUp();
			completionWidget.renderer.textStyler.scheduleAll();
		}	
	}

	void navigateDown()
	{
		auto lc = completionWidget.bufferView.buffer.lineCount;			
		if (lc > completionStyler.lineHighlighted)
		{
			completionStyler.lineHighlighted++;
			if (completionStyler.lineHighlighted > (completionWidget.bufferView.lineOffset + completionWidget.bufferView.visibleLineCount))
				completionWidget.bufferView.scrollDown();
			completionWidget.renderer.textStyler.scheduleAll();
		}	
	}

	void navigateTo(int idx)
	{		
		int prev = -1;
		while (idx > completionStyler.lineHighlighted && prev != completionStyler.lineHighlighted)
		{
			prev = completionStyler.lineHighlighted;
			navigateDown();
		}
		prev = -1;
		while (idx < completionStyler.lineHighlighted && idx >= 0 && prev != completionStyler.lineHighlighted)
		{
			prev = completionStyler.lineHighlighted;
			navigateUp();
		}
	}

	void cycleBuffers(int i)
	{
		if (!isBufferCycleMode)
		{
			// Start cycling mode
			setCommand("app.cycleBuffers");
			cycleBufferStartOffset = 0;
			cycleBufferNames = app.getActiveBufferCompletions("");
			displayStringList(cycleBufferNames);
		}

		while (i < 0)
			i += cycleBufferNames.length;
		
		i = i % cycleBufferNames.length;
		cycleBufferStartOffset = (cycleBufferStartOffset + i) % cycleBufferNames.length;

		app.previewBuffer(cycleBufferNames[cycleBufferStartOffset]);
		navigateTo(cycleBufferStartOffset);
	}

	void endCycleBufferMode()
	{
		app.showBuffer(cycleBufferNames[cycleBufferStartOffset]);
		cycleBufferNames.length = 0;
		cycleBufferStartOffset = -1;
	}

	@property
	{
		void show(Mode m)
		{
			if (window is null || _mode == m)
				return;

			//completionWidget.visible = b;
			//std.stdio.writeln("show ", b, " ", id, " ", h);

			//if (!app.guiRoot.timeline.hasPendingAnimation)
			//{
			//    //if (b)
			//    //{
			//    //    // style.getProperty("expand-duration", expandDuration);
			//    //    float targetHeight = height;
			//    //    float dura = expandDuration;
			//    //    if (mode == Mode.oneline)
			//    //    {
			//    //        targetHeight = onelineHeight;
			//    //        dura /= 10;
			//    //    }
			//    //    app.guiRoot.timeline.animate!"h"(this, targetHeight, dura);
			//    //}
			//    //else
			//    //{
			//    //    //style.getProperty("contract-duration", expandDuration);
			//    //    app.guiRoot.timeline.animate!"h"(this, 0, contractDuration);
			//    //    app.guiRoot.timeline.event(contractDuration * 0.1, (int d) { this.visible = false; mode = Mode.multiline; });
			//    //}
			//}
			_mode = m;

			if (m == Mode.hidden)
			{
				window.setKeyboardFocusWidget(resumeWidgetID);
			}
			else
			{
				resumeWidgetID = window.getKeyboardFocusWidget().id;
				commandField.setKeyboardFocusWidget();
			}
		}

		void hide()
		{
			show(Mode.hidden);
		}

		bool isShown()
		{
			return _mode != Mode.hidden;
			//return h != 0f;
		}
	}

	void setCommand(string cmd)
	{
		_completionsEnabled = false;
		completionWidget.bufferView.clear();
		commandField.bufferView.cursorToBeginningOfLine();
		commandField.bufferView.deleteToEndOfLine();
		commandField.bufferView.append(cmd);
		_completionsEnabled = true;
		showCompletions();
	}

	private auto getActiveCommand()
	{
		// Parse last line of buffer and offer autocomplete if possible
		auto l = std.conv.text(commandField.bufferView.lastLine);
		auto cmdName = std.string.munch(l, "^ ");
		struct GetActiveCommandData
		{
			Command cmd;
			string rest;
		}
		GetActiveCommandData result;

		result.cmd = app.commandManager.lookup(cmdName);
	
		if (result.cmd is null)
		{
			result.rest = cmdName ~ l;
		}
		else
		{
			std.string.munch(l, " ");
			result.rest = l;
		}

		/+
		if (result.cmd is null)
		{
		result.cmd = app.commandManager.lookupFuzzy(cmdName);
		auto internalCmdName = cmdName in commandMap;
		if (internalCmdName is null)
		return result;
		result.cmd = app.commandManager.lookup(*internalCmdName);
		}
		+/
		return result;
	}

	
	void displayStringList(string[] list)
	{
		dstring comps;
		size_t maxLen = reduce!( (a,b) => max(a, b.length) )(0, list);
		size_t cutLen = 40;

		foreach (c; list)
		{
			if (maxLen > cutLen && cutLen < c.length)
				comps ~= dtext("..." ~ c[$-cutLen..$] ~ " \n");
			else
				comps ~= dtext(c ~ " \n");
		}
		
		//if (list.length == 1)
		//    mode = Mode.twoline;
		//else
		//    mode = Mode.multiline;

		completionWidget.bufferView.clear(comps);
		completionWidget.bufferView.lineOffset = 0;
	}

	void clearCompletions()
	{
		completionWidget.bufferView.clear();
		completionWidget.bufferView.lineOffset = 0;
	}

	//bool handleBufferChanged(BufferView b)
	void handleBufferChanged(BufferView b, BufferView.BufferString, int)
	{
		if (_completionsEnabled)
			showCompletions();
		// std.stdio.writeln("rest '", cmdData.rest, "'");
version(oldvw)
{
		size_t offset = max(0, cmdData.rest.length);
		auto worldRectRelativeToWidget = textRenderer.getRectForViewIndex(bufferView.length-1-offset);
		auto p = worldRectRelativeToWidget.pos;
		p.x += worldRectRelativeToWidget.w;
		auto pixelRectRelativeToWidget = window.worldToPixelSize(p);
		completionWidget.x = x + pixelRectRelativeToWidget.x;
}
		// std.stdio.writeln("Completions ", pixelRectRelativeToWidget.x, " ", bufferView.length, " ", completions);
		//return false;
	}

	private void showCompletions()
	{
		auto cmdData = getActiveCommand();
		if (cmdData.cmd is null)
		{
			showCommandNameCompletions(cmdData.rest);
		}
		else
		{
			auto completions = cmdData.cmd.getCompletions(cmdData.rest);
			showCommandArgumentCompletions(cmdData.cmd, completions);
		}
	}

	private void showCommandNameCompletions(string str)
	{
		auto cmdNameSearch = std.string.munch(str, "^ ");

		auto cmdList = app.commandManager.lookupFuzzy(cmdNameSearch);

		if (cmdList.empty)
		{
			completionWidget.bufferView.clear();
		}
		else
		{
			show(Mode.multiline);
			displayStringList(cmdList.map!(e => e.name).array);
		}	
	}

	private void showCommandArgumentCompletions(Command cmd, CompletionEntry[] completions)
	{
		if (completions.empty)
		{
			bool showCommandCompletion = (cmd.hints & Hints.completion) != 0;
			auto defs = cmd.getCommandParameterDefinitions();
			if (showCommandCompletion && defs !is null)
			{
				// Set at minimum two lines so that we can show parameter. But if we already have multiline
				// mode we don't want that to collapse to twoline mode.
				if (mode == Mode.oneline || mode == Mode.hidden)
					show(Mode.twoline);
				auto str = getCommandArgsString(cmd);
				displayStringList([str]);
			}
			else
			{
				show(Mode.oneline);
			}
		}
		else
		{
			show(Mode.multiline);
			displayStringList(completions.map!(a => a.label).array);
		}
	}

	private void completeCommandName(string str)
	{
		// Try to complete command name
		auto cmdNameSearch = std.string.munch(str, "^ ");
		Command[] cmdList = app.commandManager.lookupFuzzy(cmdNameSearch);

		auto res = cmdList
			.dropExactly(completionStyler.lineHighlighted)
			.map!(e => e.name).array;
		if (res.length)
		{
			completionWidget.bufferView.clear();
			commandField.bufferView.clear();
			commandField.bufferView.insert(dtext(res.front ~ ' '));
		}
	}

	private void completeCommandArgument(Command cmd, string str)
	{
		// Try to complete command argument
		auto prefix = str;
		auto completions = cmd.getCompletions(prefix);
		if (completions.empty)
		{
			auto res = completions.dropExactly(completionStyler.lineHighlighted);
			import std.stdio;
			writeln("ff1");
			commandField.bufferView.remove(-prefix.length);
			writeln("ff2");
			//completionWidget.visible = true;
			completionWidget.bufferView.clear();
			writeln("ff3");
			commandField.bufferView.insert(dtext(res.front.label ~ ' '));
		}
	}

	void completeCommand()
	{
		auto cmdData = getActiveCommand();
		if (cmdData.cmd is null) 
			completeCommandName(cmdData.rest);
		else
			completeCommandArgument(cmdData.cmd, cmdData.rest);

version(NONE)
{
		// filter away active editor buffer name from list here.

		if (completions.empty) return;

		auto cs = completions;
		auto csLen = cs.length;

		size_t cutIdx = 0;
		foreach (idx; 0 .. completions[0].data.length) // TODO: .data really?
		{
			auto csNew = array(cs.filter!((a) => a.data[idx] == completions[0].data[idx])());
			auto csNewLen = csNew.length;
			if (csLen != csNewLen)
				break;
			csLen = csNewLen;
			cs = csNew;
			cutIdx++;
		}

		// If no common prefix found then use first completion
		if (cutIdx == 0)
			cutIdx = completions[0].data.length; // TODO: .data really?

		auto completionText = completions[0].data[0..cutIdx];
		auto completionSameAsEnteredPrefix = completionText.length == prefix.length;
		// TODO: when this condition is true also allow for further tabbing to switch between
		//       entries that matched the original prefix. The first non-tab key should
		//       abort this state.
		if (completionSameAsEnteredPrefix)
		{
			// Complete using the first completion on double complete
			completionText = completions[0].data;
		}

		commandField.bufferView.remove(-prefix.length);
		//completionWidget.visible = true;
		completionWidget.bufferView.clear();
		commandField.bufferView.insert(dtext(completionText));
}
	}

	void executeCommand()
	{
		auto cmdData = getActiveCommand();
		if (cmdData.cmd is null) 
		{
			completeCommand();
			cmdData = getActiveCommand();
			if (cmdData.cmd is null)
			{
				app.addMessage(format("Unknown command: %s", cmdData.rest));
				return;
			}
		}

		import std.range;

		CommandParameter[] ps;
		auto defs = cmdData.cmd.getCommandParameterDefinitions();
		if (defs !is null)
		{
			bool allSet = defs.parseValues(ps, cmdData.rest);
			auto var = createArgs(cmdData.rest);
			auto completions = cmdData.cmd.getCompletions(ps);
			auto res = completions.dropExactly(completionStyler.lineHighlighted);
			if (!res.empty)
				ps = createArgs(res.front.data);
		}
		// setCommand("");
		clearCompletions();
		hide();
		cmdData.cmd.execute(ps);
		//window.app.
	}

	void onMissingCommandArguments(Command cmd, CommandParameter[] args)
	{
		string cmdStr = cmd.name;
		foreach (a; args)
		{
			cmdStr ~= " ";
			cmdStr ~= a.toString();
		}
		
		if (args.empty)
			cmdStr ~= " ";
		
		setCommand(cmdStr);
		// showCompletions();
		auto str = getCommandArgsString(cmd);
		// displayStringList([str]);
		app.addMessage(format("Missing arguments: %s", str));
	}

	private string getCommandArgsString(Command cmd)
	{
		auto paramDefs = cmd.getCommandParameterDefinitions();
		auto str = cmd.name;

		foreach (i; 0..paramDefs.length)
		{
			string name = paramDefs[i].name;
			if (name.empty)
				name ~= "abcdefghijklmnopqrstuvxyz"[i];
			string typeName = paramDefs[i].parameter.type().toString();
			if (typeName == "immutable(char)[]")
				typeName = "string";
			str ~= format(" %s:%s", name, typeName);
		}
		return str;		
	}

	void toggleShown(Mode m)
	{
		if (_mode == Mode.hidden)
			show(m);
		else
			show(Mode.hidden);
	}

}

version (unittest) import test;

unittest
{
	Assert("this is", "this is");
	
	Assert("this is", "this is not");


	Assert("this is", "this is");
}