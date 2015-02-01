module controls.textfield;

import controls.texteditor;

import core.bufferview;
import gui.widget;
import math;

class TextField : TextEditor
{
	override const(Vec2f) preferredSize()
	{
		auto ps = renderer.layoutSize;
		if (ps.x != 0 && ps.y != 0)
			return max(ps, size);
		auto fontHeight = style.font.fontHeight;

		return max(Vec2f(100, fontHeight), size);
	}

	this(Widget parent, BufferView buf)
	{
		super(parent, buf);
		bufferView.visibleLineCount = 1;
	}

	override void draw()
	{
		renderer.ensureLayedOut(this);
		renderer.cursorSupported = hasKeyboardFocus;
		super.draw();
	}
}
