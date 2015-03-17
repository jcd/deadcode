module gui.widgetfeature.windowdragger;

import gui.event;
import gui.widget;
import gui.widgetfeature;
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
class WindowDragger : WidgetFeature
{
	Vec2f startDragPos;

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
			widget.grabMouse();
			startDragPos = event.mousePos;
		//	widget.window.waitForEvents = false;
			return EventUsed.yes;
		}
		if (event.type == EventType.MouseUp)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.releaseMouse();
		//	widget.window.waitForEvents = true;
			return EventUsed.yes;
		}
		return EventUsed.no;
	}

	override void update(Widget widget)
	{
		if (widget.isGrabbingMouse())
		{
                    version (Windows)
                    {
			CURSORINFO desktopPos;
			desktopPos.cbSize = CURSORINFO.sizeof;
			if (! GetCursorInfo(&desktopPos))
			{
				std.stdio.writeln("errocode ", GetLastError());
			}

			Vec2f winPos = Vec2f(desktopPos.ptScreenPos.x, desktopPos.ptScreenPos.y);
			widget.window.position = winPos - startDragPos;
                    }
		}
	}
}
