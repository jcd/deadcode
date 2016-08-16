module gui.widgetfeature.windowdragger;

import gui.event;
import gui.widget : Widget;
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
		if (event.type == GUIEvents.mousePressed && widget.rect.contains((cast(MousePressedEvent)event).position))
		{
			widget.grabMouse();
			startDragPos = (cast(MousePressedEvent)event).position;
		//	widget.window.waitForEvents = false;
			return EventUsed.yes;
		}
		if (event.type == GUIEvents.mouseReleased)
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
            Vec2f winPos = widget.window.getCursorScreenPosition();
			widget.window.position = winPos - startDragPos;
		}
	}
}
