module gui.widgetfeature.constraintlayout;

import gui.event;
import gui.widget;
import gui.widgetfeature._;
import math._;

enum HorizontalAnchor
{
	Left = 0x01,
	Center = 0x02,
	Right = 0x03
}

enum VerticalAnchor
{
	Top = 0x10,
	Middle = 0x20,
	Bottom = 0x30
}

enum Anchor
{
	TopLeft = HorizontalAnchor.Left | VerticalAnchor.Top,
	TopCenter = HorizontalAnchor.Center | VerticalAnchor.Top,
	TopRight = HorizontalAnchor.Right | VerticalAnchor.Top,
	MiddleLeft = HorizontalAnchor.Left | VerticalAnchor.Middle,
	MiddleCenter = HorizontalAnchor.Center | VerticalAnchor.Middle,
	MiddleRight = HorizontalAnchor.Right | VerticalAnchor.Middle,
	BottomLeft = HorizontalAnchor.Left | VerticalAnchor.Bottom,
	BottomCenter = HorizontalAnchor.Center | VerticalAnchor.Bottom,
	BottomRight = HorizontalAnchor.Right | VerticalAnchor.Bottom
}

Vec2f anchorPosition(Rectf rect, Anchor a)
{
	Vec2f result = rect.pos;
	final switch (a)
	{
		case Anchor.TopLeft:
			break;
		case Anchor.TopCenter:
			result.x += rect.w * 0.5;
			break;
		case Anchor.TopRight:
			result.x += rect.w;
			break;
		case Anchor.MiddleLeft:
			result.y += rect.h * 0.5;
			break;
		case Anchor.MiddleCenter:
			result.y += rect.h * 0.5;
			result.x += rect.w * 0.5;
			break;
		case Anchor.MiddleRight:
			result.y += rect.h * 0.5;
			result.x += rect.w;
			break;
		case Anchor.BottomLeft:
			result.y += rect.h;
			break;
		case Anchor.BottomCenter:
			result.y += rect.h;
			result.x += rect.w * 0.5;
			break;
		case Anchor.BottomRight:
			result.y += rect.h;
			result.x += rect.w;
			break;
	}
	return result;
}

// TODO: Think this is too complex. Maybe do several simpler ones that can be combined
//       Maybe build constraints from a string...?
class ConstraintLayout : WidgetFeature
{

	// Widget that this constraint relates to. If it is the window
	// the relation is NullWidgetID
	WidgetID relation;
	
	HorizontalAnchor hRelAnchor;
	VerticalAnchor vRelAnchor;
	
	HorizontalAnchor hWidgetAnchor;
	VerticalAnchor vWidgetAnchor;
	
	Vec2f lockedSize;
	Vec2f offset;
	
	bool _relayout = true;

	this(WidgetID relation, 
	     HorizontalAnchor hRelAnchor, VerticalAnchor vRelAnchor,
	     HorizontalAnchor hWidgetAnchor, VerticalAnchor vWidgetAnchor,
	     Vec2f lockedSize = Vec2f(-1, -1),
	     Vec2f offset = Vec2f(0,0))
	{
		this.relation = relation;
		this.hRelAnchor = hRelAnchor;
		this.vRelAnchor = vRelAnchor;
		this.hWidgetAnchor = hWidgetAnchor;
		this.vWidgetAnchor = vWidgetAnchor;
		this.lockedSize = lockedSize;
		this.offset = offset;
		_relayout = true;
	}
	
	override void update(Widget widget) 
	{
		if (_relayout)
			layout(widget, false);
	}
	
	override EventUsed send(Event event, Widget widget)
	{
		if (event.type == EventType.Resize)
		{
			widget.manualLayout = true;
			_relayout = true;
		}

		return EventUsed.no;
	}
	
	override void layout(Widget widget, bool fit)
	{
		if (!_relayout)
			return;
		
		float k = 0.999f;
		
		Rectf startRect = widget.rect;
		Rectf targetRect = startRect;
	
		Vec2f winSize = widget.window.size;
		
		Rectf windowRect = Rectf(0,0,winSize.x,winSize.y);
		
		Rectf relRect = relation == NullWidgetID ? windowRect : widget.window.getWidget(relation).rect;
		Vec2f relAnchor;
		
		// The vertical axis
		final switch (vRelAnchor)
		{
			case VerticalAnchor.Top:
				relAnchor.y = relRect.y;
				break;
			case VerticalAnchor.Middle:
				relAnchor.y = (relRect.y + relRect.y2) * 0.5f;
				break;
			case VerticalAnchor.Bottom:
				relAnchor.y = relRect.y2;
				break;
		}
		
		relAnchor.y += offset.y;
		
		// No matter the event we try to satisfy the constraint
		//Rectf wrect = widget.rect;
		float dy;
		final switch (vWidgetAnchor)
		{
			case VerticalAnchor.Top:
				dy = (relAnchor.y - startRect.y) * k;
				targetRect.y += dy;
				// If needed try to satify a vertical size constraint
				if (lockedSize.y > 0)
					targetRect.h += (lockedSize.y - startRect.h) * k;
				break;
			case VerticalAnchor.Middle:
				float wy = (startRect.y + startRect.y2) * 0.5f;
				dy = (relAnchor.y - wy) * k;
				targetRect.y += dy;
				break;
			case VerticalAnchor.Bottom:
				dy = (relAnchor.y - startRect.y2) * k;
				targetRect.h += dy;
				// If needed try to satify a vertical size constraint
				if (lockedSize.y > 0)
				{
					auto deltaHeight = -(lockedSize.y - targetRect.h) * k;
					targetRect.y += deltaHeight;
					targetRect.h -= deltaHeight;
				}
				break;
		}
		
		
		// The horizontal axis
		final switch (hRelAnchor)
		{
			case HorizontalAnchor.Left:
				relAnchor.x = relRect.x;
				break;
			case HorizontalAnchor.Center:
				relAnchor.x = (relRect.x + relRect.x2) * 0.5f;
				break;
			case HorizontalAnchor.Right:
				relAnchor.x = relRect.x2;
				break;
		}
		
		relAnchor.x += offset.x;
		
		// No matter the event we try to satisfy the constraint
		float dx;
		final switch (hWidgetAnchor)
		{
			case HorizontalAnchor.Left:
				dx = (relAnchor.x - startRect.x) * k;
				targetRect.x += dx;
				// If needed try to satify a horizontal size constraint
				if (lockedSize.x > 0)
					targetRect.w += (lockedSize.x - startRect.w) * k;
				break;
			case HorizontalAnchor.Center:
				float wx = (startRect.x + startRect.x2) * 0.5f;
				dx = (relAnchor.x - wx) * k;
				targetRect.x += dx;
				if (lockedSize.x > 0)
					targetRect.w += (lockedSize.x - startRect.w) * k;
				break;
			case HorizontalAnchor.Right:
				dx = (relAnchor.x - startRect.x2) * k;
				targetRect.w += dx;
				// If needed try to satify a horizontal size constraint
				if (lockedSize.x > 0)
				{
					auto deltaWidth = -(lockedSize.x - targetRect.w) * k;
					targetRect.x += deltaWidth;
					targetRect.w -= deltaWidth;
				}
				break;
		}		

		float limit = 0.016;
		bool done = startRect.pos.squaredDistanceTo(targetRect.pos) < limit && startRect.size.squaredDistanceTo(targetRect.size) < limit;

		if (!done)
			widget.rect = targetRect;

		_relayout = !done;
	//
	//    // TODO: Make sure that widget.rect is integer size when done is true.
	//    if (done)
	//    {
	//        
	//        //std.stdio.writeln("done ", widget.name, " ", startRect.w, " ", targetRect.w);
	//        return EventUsed.no;
	//    }
	//    else
	//    {
	////		std.stdio.writeln("not done ", widget.name, " ", startRect.h, " ", targetRect.h);
	//        widget.rect = targetRect;
	//        return EventUsed.yes;
	//    }
	}	
}


void alignTo(Widget me, WidgetID target, Anchor anchorTarget, Anchor anchorMe,
                        Vec2f lockedSize = Vec2f(-1, -1),
                        Vec2f offset = Vec2f(0,0))
{
	HorizontalAnchor ht = cast(HorizontalAnchor) (anchorTarget & 0x0f);
	VerticalAnchor vt = cast(VerticalAnchor)(anchorTarget & 0xf0);

	HorizontalAnchor hm = cast(HorizontalAnchor) (anchorMe & 0x0f);
	VerticalAnchor vm = cast(VerticalAnchor)(anchorMe & 0xf0);

	me.features ~= new 	ConstraintLayout(target, ht, vt, hm, vm, lockedSize, offset);
}

void alignTo(Widget me, Widget target, Anchor anchor,
                        Vec2f lockedSize = Vec2f(-1, -1),
                        Vec2f offset = Vec2f(0,0))
{
	alignTo(me, target.id, anchor, anchor, lockedSize, offset);
}

void alignTo(Widget me, Widget target, Anchor anchorTarget, Anchor anchorMe,
                   Vec2f lockedSize = Vec2f(-1, -1),
                   Vec2f offset = Vec2f(0,0))
{
	alignTo(me, target.id, anchorTarget, anchorMe, lockedSize, offset);
}

void alignTo(Widget me, Anchor anchor,
             Vec2f lockedSize = Vec2f(-1, -1),
             Vec2f offset = Vec2f(0,0))
{
	assert(me.parent !is null);
	alignTo(me, me.parent.id, anchor, anchor, lockedSize, offset);
}

void alignTo(Widget me, Anchor anchorTarget, Anchor anchorMe,
             Vec2f lockedSize = Vec2f(-1, -1),
             Vec2f offset = Vec2f(0,0))
{
	assert(me.parent !is null);
	alignTo(me, me.parent.id, anchorTarget, anchorMe, lockedSize, offset);
}

void alignToWindow(Widget me, Anchor anchor,
                        Vec2f lockedSize = Vec2f(-1, -1),
                        Vec2f offset = Vec2f(0,0))
{
	alignTo(me, NullWidgetID, anchor, anchor, lockedSize, offset);
}


