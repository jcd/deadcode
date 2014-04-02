module gui.widgetfeature.directionallayout;

import gui.event;
import gui.widget;
import gui.widgetfeature._;
import math._;

/** Layouting of child widgets
 * 
 * When this feature is set on a widget all child widgets will
 * be layed by this class.
 */
class DirectionalLayout(bool isHorz) : WidgetFeature
{	
	override EventUsed send(Event event, Widget widget)
	{
		if (event.type != EventType.Resize)
			return EventUsed.no;
		
		updateLayoutPreferred(widget);
		return EventUsed.no;
	}

	void updateLayoutPreferred(Widget widget)
	{
		auto children = widget.children;
		if (children is null || children.length == 0) return; // nothing to layout

		const rect = widget.rect;

		static if (isHorz)
		{
			// Divide the current width into even horizontal pieces
			float d = rect.w / children.length;
			auto r = Rectf(rect.x, rect.y, d, rect.w);
			foreach (ref w; children)
			{
				w.rect = r;
				r.pos.x += d;
			}
		}
		else
		{
			// Layout children until out of widget rect bounds
			auto r = Rectf(rect.x, rect.y, rect.w, 0);
			foreach (ref w; children)
			{
				r.h = w.preferredSize.y;
				w.rect = r;
				r.pos.y += r.h;
			}

			if (children[$-1].rect.y2 < widget.rect.y2)
			{
				Rectf rr = children[$-1].rect;
				rr.size.y += widget.rect.y2 - children[$-1].rect.y2;
				children[$-1].rect = rr;
			}
		}
	}
	
	void updateLayoutEven(Widget widget)
	{
		auto children = widget.children;
		if (children is null || children.length == 0) return; // nothing to layout
		
		const rect = widget.rect;
		
		static if (isHorz)
		{
			// Divide the current width into even horizontal pieces
			float d = rect.w / children.length;
			auto r = Rectf(rect.x, rect.y, d, rect.w);
			foreach (ref w; children)
			{
				w.rect = r;
				r.pos.x += d;
			}
		}
		else
		{
			// Divide the current width into even horizontal pieces
			float d = rect.h / children.length;
			auto r = Rectf(rect.x, rect.y, rect.w, d);
			foreach (ref w; children)
			{
				w.rect = r;
				r.pos.y += d;
			}
		}
	}
	
	override void update(Widget widget) 
	{
		updateLayoutPreferred(widget);
	}
}

alias DirectionalLayout!true HorizontalLayout;
alias DirectionalLayout!false VerticalLayout;
