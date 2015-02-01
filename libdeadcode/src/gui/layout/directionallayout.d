module gui.layout.directionallayout;

import gui.event;
import gui.widget;
import gui.layout;
import math;

/** Layouting of child widgets
*
* When this feature is set on a widget all child widgets will
* be layed by this class.
*/
class DirectionalLayout(bool isHorz) : ILayout
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

	enum Mode
	{
		scaleChildren,
		cullChildren,
	}
	private Mode _mode;

	this(bool stretchLastItem = true, Mode mode = Mode.cullChildren)
	{
		_stretchLastItem = stretchLastItem;
		_mode = mode;
	}

	override void layout(Widget widget, bool fit)
	{
		auto children = widget.children;
		if (children is null || children.length == 0) return; // nothing to layout

		final switch (_mode)
		{
			case Mode.scaleChildren:
				scaledLayout(widget, fit);
				break;
			case Mode.cullChildren:
				culledLayout(widget, fit);
				break;
		}
	}

	final private void culledLayout(Widget widget, bool fit)
	{
		auto children = widget.children;

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
				//Style childStyle = w.style;
				//if (style.position == CSSPosition.absolute || style.position == CSSPosition.fixed)
				//    continue;

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

	final private void scaledLayout(Widget widget, bool fit)
	{
		auto children = widget.children;

		RectfOffset pad = widget.style.padding;
		const rect = widget.rect;
		auto r = Rectf(rect.x + pad.left, rect.y + pad.top, rect.w, 0);

		static if (isHorz)
		{
			// Divide the current width into even horizontal pieces
			float d = rect.w / children.length;
			r.w = d;
			foreach (ref w; children)
			{
				w.rect = r;
				r.pos.x += d;
			}
		}
		else
		{
			//// Get accumulated height for children
			//float fixedH = 0f;    // child has a fixed height set
			//float relativeH = 0f; // child has a relative height set
			//foreach (ref w; children)
			//{
			//
			//    h += w.h;
			//}

			// Divide the current width into even horizontal pieces
			float d = rect.h / children.length;
			r.h = d;
			foreach (ref w; children)
			{
				w.rect = r;
				r.pos.y += d;
			}
		}
	}
}

alias DirectionalLayout!true HorizontalLayout;
alias DirectionalLayout!false VerticalLayout;
