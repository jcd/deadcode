module gui.style.positioning;

import gui.widget;
import gui.style;
import math._;

private const(Vec2f) calcBasePosition(Widget w, CSSPosition cssPos)
{
	Vec2f res = w.rect.pos;
	final switch (cssPos)
	{
		case CSSPosition.fixed:
			res = Vec2f(0,0);
			break;
		case CSSPosition.absolute:
			Widget p = w.parent; // lookFirstPositionedParent();
			if (p !is null)
				res = p.rect.pos;
			else
				res = Vec2f(0,0);
			break;
		case CSSPosition.relative:
			break;
		case CSSPosition.static_:
			break;
		case CSSPosition.invalid:
			break;
	}

	return res;
}

public Vec2f calcSize(Widget w)
{
	Style st = w.style;
	
	Vec2f baseSize = void;
	Widget p = w.parent; // lookFirstPositionedParent();
	if (p is null)
		baseSize = w.window.size;
	else
		baseSize = p.size;

	Vec2f r = void;

	float mixHorzA = baseSize.x;

	calcWidth!0(w, mixHorzA, st);
	if (st.width.isMixed || st.left.isMixed || st.right.isMixed)
	{
		float mixHorzB = baseSize.x;
		calcWidth!1(w, mixHorzB, st);

		float woffset = st.width.mixOffset.isNaN ? 1f : st.width.mixOffset;

		r.x = mixHorzA * (1 - woffset) + mixHorzB * woffset;
	}
	else
	{
		r.x = mixHorzA;
	}

	float mixVertA = baseSize.y;

	calcHeight!0(w, mixVertA, st);
	if (st.height.isMixed || st.top.isMixed || st.bottom.isMixed)
	{
		float mixVertB = baseSize.y;
		calcHeight!1(w, mixVertB, st);

		float hoffset = st.height.mixOffset.isNaN ? 1f : st.height.mixOffset;

		r.y = mixVertA * (1 - hoffset) + mixVertB * hoffset;
	}
	else
	{
		r.y = mixVertA;
	}

	return r;
}


public Vec2f calcPosition(Widget w)
{
	Style st = w.style;
	CSSPositionMix posMix = st.position;
	Vec2f baseA = calcBasePosition(w, posMix.cssPositionA);
	Vec2f baseB = calcBasePosition(w, posMix.cssPositionB);

	//if (parent !is null && id == 8 && (baseA.x != 200 || baseB.x != 200))
	//    std.stdio.writeln("cp ", baseA.v, " ", baseB.v);

	// bool cssPosDiffers = st.position.posA != st.position.posB; // improve
	bool cssPosDiffers = false;

	Vec2f r = void;

	float mixHorzA = baseA.x;
	calcX!0(w, mixHorzA, st);
	if (st.width.isMixed || st.left.isMixed || st.right.isMixed || posMix.isMixed)
	{
		float mixHorzB = baseB.x;
		calcX!1(w, mixHorzB, st);
		float xoffset = st.left.mixOffset.isNaN ? (st.right.mixOffset.isNaN ? 1f : st.right.mixOffset) : st.left.mixOffset;
		if (xoffset.isNaN)
			xoffset = 1f;

		r.x = mixHorzA * (1 - xoffset) + mixHorzB * xoffset;
		//if (id == 20)
		//    std.stdio.writeln(r.x, " ", mixHorzA, " ", mixHorzB, " ", xoffset);		
	}
	else
	{
		r.x = mixHorzA;
		//if (id == 20)
		//    std.stdio.writeln(r.x, " ", mixHorzA);
	}

	float mixVertA = baseA.y;
	calcY!0(w, mixVertA, st);
	if (st.height.isMixed || st.top.isMixed || st.bottom.isMixed || posMix.isMixed)
	{
		float mixVertB = baseB.y;
		calcY!1(w, mixVertB, st);

		float yoffset = st.top.mixOffset.isNaN ? (st.bottom.mixOffset.isNaN ? 1f : st.bottom.mixOffset) : st.top.mixOffset;
		if (yoffset.isNaN)
			yoffset = 1f;

		r.y = mixVertA * (1 - yoffset) + mixVertB * yoffset;

	}
	else
	{
		r.y = mixVertA;
	}
	return r;
}

private float cssScaleToPixel(string attr)(Widget w, CSSScale s)
{
	if (s.value.isNaN)
		return s.value;

	final switch (s.unit)
	{
		case CSSUnit.pct:
			Widget p = w.parent;
			if (p is null)
				p = w;
			return mixin("p." ~ attr) * s.value;
		case CSSUnit.pixels:
			return s.value;
		case CSSUnit.cm:
			return s.value;
		case CSSUnit.em:
			return s.value;
		case CSSUnit.ex:
			return s.value;
		case CSSUnit.inch:
			return s.value;
		case CSSUnit.mm:
			return s.value;
		case CSSUnit.picas:
			return s.value;
		case CSSUnit.points:
			return s.value;
	}
}

private void calcX(int i)(Widget w, ref float res, Style st)
{
	float wi = cssScaleToPixel!("w")(w, st.width[i]);

	float l = cssScaleToPixel!("w")(w, st.left[i]);
	l = l.isNaN ? 0 : l;

	float r = cssScaleToPixel!("w")(w, st.right[i]);
	r = r.isNaN ? 0 : r;

	if (wi.isNaN)
	{
		res += l;
	}
	else
	{
		if (!st.left[i].value.isNaN)
		{
			res += l;
		}
		else if (!st.right[i].value.isNaN)
			res -= r;
	}
}

private void calcWidth(int i)(Widget w, ref float res, Style st)
{
	float wi = cssScaleToPixel!("w")(w, st.width[i]);

	float l = cssScaleToPixel!("w")(w, st.left[i]);
	l = l.isNaN ? 0 : l;

	float r = cssScaleToPixel!("w")(w, st.right[i]);
	r = r.isNaN ? 0 : r;

	if (wi.isNaN)
	{
		res -= l + r;
	}
	else
	{
		res = wi;
		if (!st.left[i].value.isNaN)
		{
			if (!st.right[i].value.isNaN)
				res -= r;
		}
	}
}

private void calcY(int i)(Widget w, ref float res, Style st)
{
	float hi = cssScaleToPixel!("h")(w, st.height[i]);

	float t = cssScaleToPixel!("h")(w, st.top[i]);
	t = t.isNaN ? 0 : t;

	float b = cssScaleToPixel!("h")(w, st.bottom[i]);
	b = b.isNaN ? 0 : b;

	if (hi.isNaN)
	{
		res += t;
	}
	else
	{
		if (!st.top[i].value.isNaN)
		{
			res += t;
		}
		else if (!st.bottom[i].value.isNaN)
		{
			res -= b;
		}
	}
}

private void calcHeight(int i)(Widget w, ref float res, Style st)
{
	float hi = cssScaleToPixel!("h")(w, st.height[i]);

	float t = cssScaleToPixel!("h")(w, st.top[i]);
	t = t.isNaN ? 0 : t;

	float b = cssScaleToPixel!("h")(w, st.bottom[i]);
	b = b.isNaN ? 0 : b;

	if (hi.isNaN)
	{
		res -= t + b;
	}
	else
	{
		res = hi;
		if (!st.top[i].value.isNaN)
		{
			if (!st.bottom[i].value.isNaN)
				res -= b;
		}
	}
}
