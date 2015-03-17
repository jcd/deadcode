module gui.widgetfeature.windowresizer;

import gui.widgetfeature;

import gui.event;
import gui.widget;

import math;

version (Windows)
{
    import std.c.windows.windows;
    struct CURSORINFO {
	DWORD   cbSize;
	DWORD   flags;
	HCURSOR hCursor;
	POINT   ptScreenPos;
    };
    alias CURSORINFO* PCURSORINFO, NPCURSORINFO, LPCURSORINFO;

    extern (Windows) nothrow
    {
        export BOOL GetCursorInfo(LPCURSORINFO lpPoint);
    }
}

/** Makes a widget able to drag the containing window
 */
class WindowResizer : WidgetFeature
{
	Vec2f startDragPos;
	Vec2f startSize;
	enum dragTriggerDistance = 10f; // pixels to drag before drag is started

	this()
	{

		this.startDragPos = Vec2f(-1000000, -1000000);
	}

	override EventUsed send(Event event, Widget widget)
	{
		// Dragging support
		//if (event.type == EventType.MouseDown && widget.rectStyled.contains(event.mousePos))
		if (event.type == EventType.MouseDown && widget.rect.contains(event.mousePos))
		{
			startSize = widget.window.size;
			widget.grabMouse();
			startDragPos = getCursorScreenPos();
			//widget.window.waitForEvents = false;
			return EventUsed.yes;
		}
		if (event.type == EventType.MouseUp)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.releaseMouse();
			//widget.window.waitForEvents = true;
			return EventUsed.yes;
		}
		return EventUsed.no;
	}

	override void update(Widget widget)
	{
            version (Windows)
            {
		if (widget.isGrabbingMouse() && startDragPos.x > -1000)
		{
			Vec2f screenPos = getCursorScreenPos();
			widget.window.size = startSize + (screenPos - startDragPos);
		}
            }
	}

	static Vec2f getCursorScreenPos()
	{
            version (Windows)
            {
		CURSORINFO desktopPos;
		desktopPos.cbSize = CURSORINFO.sizeof;
		if (! GetCursorInfo(&desktopPos))
		{
			std.stdio.writeln("errocode ", GetLastError());
		}
		Vec2f pos = Vec2f(desktopPos.ptScreenPos.x, desktopPos.ptScreenPos.y);
		return pos;
            }
            version (linux)
            {
                pragma(msg, "Warning: getCursorScreenPos not implemented");
                return Vec2f(0,0);
            }
	}
}
