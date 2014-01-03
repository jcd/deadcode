module controls.editor;

import core.bufferview;
import core.command : CommandManager;
import graphics._;
import gui.event;
import gui.style;
import gui.widget;
import gui.widgetfeature._;
import guiapplication;
import math._;

class Editor : Widget
{
	/*
		Source code editor
		* indent policy (auto?, on tab?)
		* tab width
		* completions
		* parenthesis highligting
		* line markers
		* margin marker
		* draw spaces
		* bookmarks
		* selection (should also work for simple text rendering)
		* undo/redo
		* move line/word
		* linelayout caching (textrenderer)
		* 

	 */

	// Keep a tick shared for all editors in order to keep LRU order.
	static uint drawTick;

	// Tick when this editor was last drawn
	uint lastDrawTick = 0;

	BufferView bufferView;

	this(Widget parent, BufferView buf)
	{
		super(parent);
		acceptsKeyboardFocus = true;
		features ~= new BoxRenderer("edit-background");
		this.alignTo(Anchor.TopLeft);
		this.alignTo(Anchor.BottomRight);
		this.content = buf;
		bufferView = buf;	
	}

	override void draw(StyleSet styleSet)
	{
		if (!visible)
			return;
		drawTick++;
		lastDrawTick = drawTick;
		super.draw(styleSet);
	}

	override EventUsed onMouseScroll(Event event)
	{
		std.stdio.writeln("scrool");
		// Scroll view
		int d = cast(int) event.scroll.y;
		if (d < 0)
		{
			foreach (i; 0..d*d)
				bufferView.scrollDown();
		}
		else
		{
			foreach (i; 0..d*d)
				bufferView.scrollUp();
		}
		return EventUsed.yes;
	}
}

