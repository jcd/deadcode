module gui.widgetfeature.windowdragger;

import gui.event;
import gui.widget;
import gui.widgetfeature;
import math;

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
			import platform.cursor;
            Vec2f winPos = getScreenPosition();
			widget.window.position = winPos - startDragPos;
		}
	}
}
