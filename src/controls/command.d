module controls.command;

import guiapplication;
import core.bufferview;
import core.command : CommandManager, Command;
import graphics._;
import gui.event;
import gui.keycode;
import gui.style;
import gui.widget;
import gui.widgetfeature._;
import math._;

import std.algorithm;
import std.array;
import std.conv;

class CommandControl : Widget
{
	float height; // height when control is visible
	float expandDuration; //
	float contractDuration; //
	core.bufferview.BufferView bufferView;
	TextRenderer!(core.bufferview.BufferView) textRenderer; // to lookup glyph positions for bufferView
	core.bufferview.BufferView completionView;
	Widget completionWidget;
	WidgetID resumeWidgetID;
	string[string] commandMap;
	GUIApplication app;

	Widget bottomWidget;

	this(Widget parent, float _height, BufferView bufView, GUIApplication _app)
	{
		super(parent);
		app = _app;
		commandMap = [ "of" : "edit.open", "sb" : "edit.showBuffer" ];
		
		expandDuration = 0.2f;
		contractDuration = 0.07f;
		height = _height;

		acceptsKeyboardFocus = true;
		h = 200f;
		bufferView = bufView;
		visible = true;
	}

	private void init(StyleSet styleSet)
	{
		bottomWidget = new Widget(this);
		bottomWidget.name = "commandBottom";

	//	bottomWidget.events[EventType.Update] = (Event ev, ref Widget w) {
			//std.stdio.writeln("hello ", w.rect.pos.v, " ", w.rect.size.v);
	//		return true;
	//	};

		bottomWidget.alignTo(this, Anchor.BottomRight, Vec2f(-1, 10));
		this.alignToWindow(Anchor.TopRight);
		this.alignToWindow(Anchor.TopLeft);

		//auto mat =  styleSet.getStyle("builtin").background;

		auto renderer = new BoxRenderer("edit-background");
		//renderer.model.material = mat;
		
		features ~= renderer;

		// Need to rememer the text renderer in order to get the rect of the last char in buffer so that we know where to render completions
		textRenderer = content(this, bufferView);
		textRenderer.onLayoutChanged = (typeof(textRenderer) r) { handleBufferChanged(r.text); };
		completionWidget = new Widget(this);
		completionWidget.name = "commandCompletion";
		completionWidget.alignTo(this, Anchor.TopRight);
		completionView = app.bufferViewManager.create();
		auto textRenderer = completionWidget.content(completionView);
		textRenderer.cursorEnabled = false;

		//completionView.append("this isa test");
		completionWidget.visible = false;

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
		
		renderer = new BoxRenderer("foobar");
		//renderer.model.material = mat;
		bottomWidget.features ~= renderer;
		show = false;
	}

	override void draw()
	{
		if (!visible)
			return;
		if (bottomWidget is null)
			init(window.styleSet);
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

			completionWidget.visible = b;
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
					// app.guiRoot.timeline.event(contractDuration * 0.1, (int d) { this.visible = false; });
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
		completionView.clear();
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

	bool handleBufferChanged(BufferView b)
	{
		auto cmdData= getActiveCommand();
		if (cmdData.cmd is null) 
		{
			completionWidget.visible = false;
			return false;
		}

		completionWidget.visible = true;
		auto completions = cmdData.cmd.getCompletions(std.variant.Variant(cmdData.rest));

		dstring comps;
		foreach (c; completions)
			comps ~= dtext(c ~ "\n");
		completionView.clear(comps);
		// std.stdio.writeln("rest '", cmdData.rest, "'");
		size_t offset = max(0, cmdData.rest.length);
		auto worldRectRelativeToWidget = textRenderer.getRectForViewIndex(bufferView.length-1-offset);
		auto p = worldRectRelativeToWidget.pos;
		p.x += worldRectRelativeToWidget.w;
		auto pixelRectRelativeToWidget = window.worldToPixelSize(p);
		completionWidget.x = x + pixelRectRelativeToWidget.x;
		// std.stdio.writeln("Completions ", pixelRectRelativeToWidget.x, " ", bufferView.length, " ", completions);
		return false;
	}

	void completeCommand()
	{
		auto cmdData= getActiveCommand();
		if (cmdData.cmd is null) 
		{
			completionWidget.visible = false;
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
		completionWidget.visible = true;
		completionView.clear();
		bufferView.insert(dtext(completionText));
	}

	void executeCommand()
	{
		//string path = std.conv.text(bufferView.buffer.toArray());
		//w.window.app.executeCommand("editor.open", std.variant.Variant(path));
		auto cmdData = getActiveCommand();
		if (cmdData.cmd is null) 
		{
			completionWidget.visible = false;
			return;
		}

		auto cmd = getActiveCommand();
		cmd.cmd.execute(std.variant.Variant(cmdData.rest));
		setCommand("");
		//window.app.
	}

	void toggleShown()
	{
		show = !show;
	}
}
