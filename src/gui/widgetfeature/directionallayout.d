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
	//override EventUsed send(Event event, Widget widget)
	//{
	//    if (event.type != EventType.Resize)
	//        return EventUsed.no;
	//    
	//    updateLayoutPreferred(widget);
	//    return EventUsed.no;
	//}

	private bool _stretchLastItem;

	this(bool stretchLastItem = true)
	{
		_stretchLastItem = stretchLastItem;
	}

	override void layout(Widget widget, bool fit)
	{
		auto children = widget.children;
		if (children is null || children.length == 0) return; // nothing to layout

		Rectf rect = widget.rect;

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
			RectfOffset pad = widget.style.padding;

			// Layout children until out of widget rect bounds
			auto r = Rectf(rect.x + pad.left, rect.y + pad.top, rect.w, 0);
			
			if (fit)
			{
				rect.h = 1000000f;
				rect.w = 1000000f;
			}

			foreach (ref w; children)
			{
				// no more room to in parent widget to layout children
				w.visible = r.y < rect.y2;
				
				// r.h = w.preferredSize.y;
				Vec2f childSizeStyled = w.size;
				r.w = childSizeStyled.x;
				r.h = childSizeStyled.y;

				if (r.y2 > rect.y2)
				{
					// This widget cannot fit. Make it smaller in order to fit.
					float tmp = r.h;
					r.y2 = rect.y2;
					w.rect = r;
					r.h = tmp;
				}
				else
				{
					w.rect = r;
				}
				
				//if (w.id == 8)
				//    std.stdio.writeln("w8 pos ", w.pos.y);

				r.pos.y += r.h;
			}

			// If there is any space left then give it to the last widget
			if (_stretchLastItem && !fit && children[$-1].rect.y2 < (rect.y2 - pad.bottom))
			{
				Rectf rr = children[$-1].rect;
				rr.size.y += widget.rect.y2 - children[$-1].rect.y2 - pad.bottom;
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
	
	//override void update(Widget widget) 
	//{
	//    updateLayoutPreferred(widget);
	//}
}

alias DirectionalLayout!true HorizontalLayout;
alias DirectionalLayout!false VerticalLayout;
