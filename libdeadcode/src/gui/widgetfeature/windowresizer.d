module gui.widgetfeature.windowresizer;

import gui.widgetfeature;

import gui.event;
import gui.widget : Widget;

import math;

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
            import platform.cursor;
            startDragPos = widget.window.getCursorScreenPosition();
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
		if (widget.isGrabbingMouse() && startDragPos.x > -1000)
		{
			import platform.cursor;
            Vec2f screenPos = widget.window.getCursorScreenPosition();
			widget.window.size = startSize + (screenPos - startDragPos);
		}
	}
}
