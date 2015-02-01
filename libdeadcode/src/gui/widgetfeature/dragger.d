module gui.widgetfeature.dragger;

import gui.event;
import gui.widget;
import gui.widgetfeature;
import math;

class Dragger : WidgetFeature
{
	Rectf handleRect;
	Vec2f startDragPos;
	enum dragTriggerDistance = 30f; // pixels to drag before drag is started

	this(Rectf handleRect)
	{
		this.handleRect = handleRect;
		this.startDragPos = Vec2f(-1000000, -1000000);
	}

	override EventUsed send(Event event, Widget widget)
	{
		// Dragging support
		Rectf handleRectAbs = handleRect;
		handleRectAbs.pos.x += widget.rect.pos.x;
		handleRectAbs.pos.y += widget.rect.pos.y;

		if (event.type == EventType.MouseDown && handleRectAbs.contains(event.mousePos))
		{
			widget.grabMouse();
			startDragPos = event.mousePos;
			return EventUsed.yes;
		}

		if ( (startDragPos - event.mousePos).squaredLength() < (dragTriggerDistance*dragTriggerDistance) )
		{
			// Wait for drag trigger distance
			return EventUsed.no;
		}

		if (widget.isGrabbingMouse() &&
		    event.type == EventType.MouseMove &&
		    event.mouseButtonsActive == Event.MouseButton.Left)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.parent = null;
			widget.moveTo(widget.rect.x + event.mousePosRel.x, widget.rect.y + event.mousePosRel.y);
			return EventUsed.yes;
		}

		if (event.type == EventType.MouseUp)
		{
			startDragPos = Vec2f(-1000000, -1000000);
			widget.releaseMouse();
			return EventUsed.yes;
		}
		return EventUsed.no;
	}

	override void update(Widget widget)
	{
	}
}


