module gui.widgetfeature.dragger;

import gui.event;
import gui.widget;
import gui.widgetfeature;
import math;

import gui.style.manager;

static init()
{
    StyleSheetManager.onInitialized ~= &registerCSSProperties;
}

private void registerCSSProperties(StyleSheetManager ssm)
{
    ssm.addPropertySpecification!bool("dragger", false);
}

class Dragger : WidgetFeature
{
	Rectf handleRect;
	Vec2f startDragPos;
	enum dragTriggerDistance = 5f; // pixels to drag before drag is started

	this(Rectf handleRect = Rectf.init)
	{
		this.handleRect = handleRect;
		this.startDragPos = Vec2f(-1000000, -1000000);
    }

	override EventUsed send(Event event, Widget widget)
	{
		// Dragging support
		Rectf handleRectAbs = handleRect;
        if (handleRect == Rectf.init)
        {
            handleRectAbs.pos = Vec2f(0,0);
            handleRectAbs.size = widget.rect.size;
        }
        handleRectAbs.pos.x += widget.rect.pos.x;
		handleRectAbs.pos.y += widget.rect.pos.y;

        EventUsed used = EventUsed.yes;

		if (event.type == EventType.MouseDown && handleRectAbs.contains(event.mousePos))
		{
			startDragPos = event.mousePos;
            used = EventUsed.no;
		}
		else if (event.type == EventType.MouseUp)
		{
            startDragPos = Vec2f(-1000000, -1000000);
            if (widget.isGrabbingMouse())
			    widget.releaseMouse();
            else
                used = EventUsed.no;
		}
		else if ( (widget.isGrabbingMouse() || (startDragPos - event.mousePos).squaredLength() >= (dragTriggerDistance*dragTriggerDistance)) &&
		         event.type == EventType.MouseMove &&
		         event.mouseButtonsActive == Event.MouseButton.Left)
		{
            if (!widget.isGrabbingMouse())
                widget.grabMouse();
			startDragPos = Vec2f(-1000000, -1000000);
			widget.parent = widget.window;
			widget.overridePos = Vec2f(widget.rect.x + event.mousePosRel.x, widget.rect.y + event.mousePosRel.y);
			//widget.moveTo(widget.rect.x + event.mousePosRel.x, widget.rect.y + event.mousePosRel.y);
            //import gui.style.types;
            //
            //   widget.styleOverride.position = CSSPosition.fixed;
            //widget.styleOverride.left = CSSScale(widget.rect.x + event.mousePosRel.x, CSSUnit.pixels);
            //widget.styleOverride.top = CSSScale(widget.rect.x + event.mousePosRel.x, CSSUnit.pixels);
		}
        else
        {
            used = EventUsed.no;
        }

		return used;
	}

	override void update(Widget widget)
	{
    }
}


