module controls.command;

import guiapplication;
import controls.texteditor;
import core.bufferview;
import core.command : CommandManager, Command;
import graphics._;
import gui.event;
import gui.keycode;
import gui.style;
import gui.styledtext;
import gui.widget;
import gui.widgetfeature._;
import math._;

import std.algorithm;
import std.array;
import std.conv;

class CompletionListStyler(Text) : TextStyler!Text
{
	enum defaultID = 0;
	enum seletedID = 2;

	int lineHighlighted = 0;

	override void update(RegionSet rset, Text text)
	{
		// Highlight the selected line and rest in default color
		rset.clear();

		auto ends = text.buffer.lineEndsAtLineNumber(lineHighlighted);
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
			return;

		if (ends[0] != 0)
			rset.add(0, ends[0], defaultID);

		rset.add(ends[0], ends[1], seletedID);
		
		if (ends[1] != text.length)
			rset.add(ends[1], text.length, defaultID);
	}
}

class CommandControl : Widget
{
	float height; // height when control is visible
	float expandDuration; //
	float contractDuration; //
	core.bufferview.BufferView bufferView;
	TextRenderer!(core.bufferview.BufferView) textRenderer; // to lookup glyph positions for bufferView
	TextEditor completionWidget;
	BufferView completionView;
	CompletionListStyler!BufferView completionStyler;
	WidgetID resumeWidgetID;
	string[string] commandMap;
	GUIApplication app;

	// Widget bottomWidget;

	this(Widget parent, float _height, BufferView bufView, GUIApplication _app)
	{
		super(parent);
		app = _app;
		commandMap = [ "f" : "edit.open", "b" : "edit.showBuffer" ];
		
		expandDuration = 0.15f;
		contractDuration = 0.03f;
		height = _height;

		acceptsKeyboardFocus = true;
		h = 200f;
		bufferView = bufView;
		visible = true;
	}

	private void init(StyleSet styleSet)
	{
		//bottomWidget = new Widget(this);
		//bottomWidget.name = "commandBottom";
		//auto renderer = new BoxRenderer("foobar");
		////renderer.model.material = mat;
		//bottomWidget.features ~= renderer;

	//	bottomWidget.events[EventType.Update] = (Event ev, ref Widget w) {
			//std.stdio.writeln("hello ", w.rect.pos.v, " ", w.rect.size.v);
	//		return true;
	//	};

		// bottomWidget.alignTo(this, Anchor.BottomRight, Vec2f(-1, 10));
		// bottomWidget.alignTo(this, Anchor.BottomLeft);
		this.alignToWindow(Anchor.TopCenter, Vec2f(600,-1), Vec2f(0,0));
		//this.alignToWindow(Anchor.TopLeft, Vec2f(200,100), Vec2f(-100,0));

		//auto mat =  styleSet.getStyle("builtin").background;

		import gui.models;

		auto ren = new NineGridRenderer("box");
		ren.model.topLeft = ren.model.left;
		ren.model.top = ren.model.center;
		ren.model.topRight= ren.model.right;
		ren.color = Vec3f(0.25, 0.25, 0.25);
		//renderer.model.material = mat;
		
		features ~= ren;

		// Need to rememer the text renderer in order to get the rect of the last char in buffer so that we know where to render completions
		textRenderer = content(this, bufferView);
		bufferView.onInsert.connect(&handleBufferChanged);
		bufferView.onRemove.connect(&handleBufferChanged);
		//textRenderer.onLayoutChanged = (typeof(textRenderer) r) { handleBufferChanged(r.text); };
		completionView = app.bufferViewManager.create();
		completionWidget = new TextEditor(this, completionView);
		completionStyler = new CompletionListStyler!BufferView;
		completionWidget.renderer.styledText.textStyler = completionStyler;
		completionWidget.renderer.cursorEnabled = false;
		completionWidget.name = "commandCompletion";
		completionWidget.alignTo(this, Anchor.TopRight, Vec2f(-1, -1), Vec2f(-2,20));
		completionWidget.alignTo(this, Anchor.TopLeft, Vec2f(-1, -1), Vec2f(2,20));
		completionWidget.alignTo(this, Anchor.BottomLeft, Vec2f(-1, -1), Vec2f(2,-10));

		//auto textRenderer = completionWidget.content(completionView);
		//textRenderer.cursorEnabled = false;

		//completionView.append("this isa test");
		//completionWidget.visible = false;

		onKeyboardFocusCallback = (Event ev, Widget w) {
			app.currentBuffer = bufferView;
			return EventUsed.yes;
		};

		onKeyboardUnfocusCallback = (Event ev, Widget w) {
		//	app.guiRoot.timeline.animate!"h"(this, 0, expandDuration);
			return EventUsed.yes;
		};

		onTextCallback = (Event ev, Widget w) {
			return EventUsed.no; // do not use the event
		};

		show = false;
	}

	override EventUsed onKeyDown(Event ev)
	{
		auto used = EventUsed.yes;

		if (ev.keyCode == stringToKeyCode("up"))
		{
			if (completionStyler.lineHighlighted > 0)
			{
				completionStyler.lineHighlighted--;
				if (completionStyler.lineHighlighted < completionView.lineOffset)
					completionView.scrollUp();
			}
		}
		else if (ev.keyCode == stringToKeyCode("down"))
		{
			auto lc = completionView.buffer.lineCount;			
			if (lc > completionStyler.lineHighlighted)
			{
				completionStyler.lineHighlighted++;
				if (completionStyler.lineHighlighted > (completionView.lineOffset + completionView.visibleLineCount))
					completionView.scrollDown();
			}
		}
		else if (ev.keyCode == stringToKeyCode("escape"))
		{
			toggleShown();
		}
		else if (ev.keyCode == stringToKeyCode("return"))
		{
			toggleShown();
			executeCommand();
		}
		else
		{
			return EventUsed.no;
		}
		return used;
	}

	override void draw()
	{
		if (!visible)
			return;
		if (textRenderer is null)
			init(window.styleSet);
		auto tup = completionView.buffer.lineEndsAtLineNumber(completionStyler.lineHighlighted);
		completionView.selection = Region(tup[0], tup[1], 0);
		completionWidget.renderer.selectionStyle = "completionListBox";
		super.draw();
	}

	override EventUsed onCommand(Event event)
	{
		if (event.name == "edit.commitCompletion")
		{
			completeCommand();
			toggleShown();
			executeCommand();
		} 
		else if (event.name == "edit.complete")
		{
			completeCommand();
		}
		return EventUsed.yes;
	}

	@property
	{
		void show(bool b)
		{
			if (window is null || b && show || !b && !show)
				return;

			//completionWidget.visible = b;
			//std.stdio.writeln("show ", b, " ", id, " ", h);

			if (!app.guiRoot.timeline.hasPendingAnimation)
			{
				if (b)
				{
					app.guiRoot.timeline.animate!"h"(this, height, expandDuration);
				}
				else
				{
					app.guiRoot.timeline.animate!"h"(this, 0, contractDuration);
					app.guiRoot.timeline.event(contractDuration * 0.1, (int d) { this.visible = false; });
				}
			}

			if (b)
			{
				resumeWidgetID = window.getKeyboardFocusWidget().id;
				setKeyboardFocusWidget();
				visible = true;
			}
			else
			{
				window.setKeyboardFocusWidget(resumeWidgetID);
			}
		}

		bool show()
		{
			return h != 0f;
		}
	}

	void setCommand(string cmd)
	{
		completionWidget.bufferView.clear();
		bufferView.cursorToBeginningOfLine();
		bufferView.deleteToEndOfLine();
		bufferView.append(cmd);
	}

	private auto getActiveCommand()
	{
		// Parse last line of buffer and offer autocomplete if possible
		auto l = std.conv.text(bufferView.lastLine);
		auto cmdName = std.string.munch(l, "^ ");
		struct GetActiveCommandData
		{
			Command cmd;
			string rest;
		}
		GetActiveCommandData result;

		if (l.length == 0)
			return result;
		
		result.rest = l[1..$];
		result.cmd = app.commandManager.lookup(cmdName);

		if (result.cmd is null)
		{
			auto internalCmdName = cmdName in commandMap;
			if (internalCmdName is null)
				return result;
			result.cmd = app.commandManager.lookup(*internalCmdName);
		}
		return result;
	}

	

	//bool handleBufferChanged(BufferView b)
	void handleBufferChanged(BufferView b, BufferView.BufferString,uint)
	{
		auto cmdData= getActiveCommand();
		if (cmdData.cmd is null) 
		{
			// completionWidget.visible = false;
			completionWidget.bufferView.clear();
			return;
			//return false;
		}

		//completionWidget.visible = true;
		auto completions = cmdData.cmd.getCompletions(std.variant.Variant(cmdData.rest));

		dstring comps;
		foreach (c; completions)
			comps ~= dtext(c ~ " \n");

		completionWidget.bufferView.clear(comps);
		completionView.bufferOffset = 0;
		completionStyler.lineHighlighted = 0;

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

	void completeCommand()
	{
		auto cmdData= getActiveCommand();
		if (cmdData.cmd is null) 
		{
			//completionWidget.visible = false;
			return;
		}
		auto prefix = cmdData.rest;
		auto completions = cmdData.cmd.getCompletions(std.variant.Variant(prefix));

		// filter away active editor buffer name from list here.

		if (completions.empty) return;

		auto cs = completions;
		auto csLen = cs.length;

		size_t cutIdx = 0;
		foreach (idx; 0 .. completions[0].length)
		{
			auto csNew = array(cs.filter!((a) => a[idx] == completions[0][idx])());
			auto csNewLen = csNew.length;
			if (csLen != csNewLen)
				break;
			csLen = csNewLen;
			cs = csNew;
			cutIdx++;
		}

		// If no common prefix found then use first completion
		if (cutIdx == 0)
			cutIdx = completions[0].length;

		auto completionText = completions[0][0..cutIdx];
		auto completionSameAsEnteredPrefix = completionText.length == prefix.length;
		// TODO: when this condition is true also allow for further tabbing to switch between
		//       entries that matched the original prefix. The first non-tab key should
		//       abort this state.
		if (completionSameAsEnteredPrefix)
		{
			// Complete using the first completion on double complete
			completionText = completions[0];
		}

		bufferView.remove(-prefix.length);
		//completionWidget.visible = true;
		completionWidget.bufferView.clear();
		bufferView.insert(dtext(completionText));
	}

	void executeCommand()
	{
		//string path = std.conv.text(bufferView.buffer.toArray());
		//w.window.app.executeCommand("editor.open", std.variant.Variant(path));
		auto cmdData = getActiveCommand();
		if (cmdData.cmd is null) 
		{
			//completionWidget.visible = false;
			return;
		}

		import std.range;

		auto cmd = getActiveCommand();
		auto completions = cmdData.cmd.getCompletions(std.variant.Variant(cmdData.rest));
		auto res = completions.dropExactly(completionStyler.lineHighlighted);
		cmd.cmd.execute(std.variant.Variant(res.front));
		setCommand("");
		//window.app.
	}

	void toggleShown()
	{
		show = !show;
	}
}
