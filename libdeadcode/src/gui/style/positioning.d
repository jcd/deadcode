module gui.style.positioning;

import gui.widget;
import gui.style;
import math;
import std.math : isNaN;

private const(Vec2f) calcBasePosition(Widget w, Widget positionReference, CSSPosition cssPos)
{
	Vec2f res = w.rect.pos;
	final switch (cssPos)
	{
		case CSSPosition.fixed:
			res = Vec2f(0,0);
			break;
		case CSSPosition.absolute:
			return positionReference.pos;
		case CSSPosition.relative:
			break;
		case CSSPosition.static_:
			break;
		case CSSPosition.invalid:
			break;
	}

	return res;
}

struct FlexSize
{
    Vec2f min;
    Vec2f max;
    Vec2f preferred;
}

public FlexSize calcSize(Widget w, Widget positionReference)
{
    //Vec2f parentSize = void;
    //Widget p = w.parent; // lookFirstPositionedParent();
    //if (p is null)
    //    parentSize = w.window.size;
    //else
    //    parentSize = p.size;

    Vec2f refSize = positionReference.size;

	Vec2f baseSize = w.intrinsicSize;

	if (baseSize.x.isNaN)
		baseSize.x = refSize.x;

	if (baseSize.y.isNaN)
		baseSize.y = refSize.y;

	return calcSizeFromBaseSize(w, positionReference, baseSize);
}

private Vec2f getAutoSize(int I)(Widget w, Style st, Widget positionReference)
{
	bool widthIsAutoA = st.width[I].unit == CSSUnit.fit;
	bool heightIsAutoA = st.height[I].unit == CSSUnit.fit;

	if (widthIsAutoA || heightIsAutoA)
	{
		// Calculate width and height by inspecting descedant widgets
		Vec2f zero = Vec2f(0,0);
		foreach (child; w.children)
		{
			Vec2f intrinsicSize = child.intrinsicSize;
			if (intrinsicSize.x.isNaN) // TODO: handle partial intrinsic on one axis
				child.setFlexSize(calcSizeFromBaseSize(child, positionReference, zero));
			else
				child.setFlexSize(FlexSize(intrinsicSize, intrinsicSize, intrinsicSize));
		}

		w.layoutChildren(true, positionReference);
		Rectf unionRect = void;
		bool first = true;
		foreach (child; w.children)
		{
			if (first)
			{
				unionRect = child.rect;
				first = false;
			}
			else
				unionRect = child.rect.makeUnion(unionRect);
		}

		// TODO: maybe support further calc based on a new baseSize?
		//		baseSize = unionRect.size;
		// TODO: support animating ie. width_A_IsAuto
		return Vec2f(widthIsAutoA ? unionRect.size.x : float.nan, heightIsAutoA ? unionRect.size.y : float.nan);
	}
	Vec2f noAutoSize;
	return noAutoSize;
}


public FlexSize calcSizeFromBaseSize(Widget w, Widget positionReference, Vec2f baseSize)
{
	Style st = w.style;
	RectfOffset pad = st.padding;

	Vec2f autoSizeA = getAutoSize!0(w, st, positionReference);
	Vec2f autoSizeB = void;
	bool autoSizeBCalculated = false;

	Vec2f r = void;

	float mixHorzA = baseSize.x;
	if (autoSizeA.x.isNaN)
		calcWidth!(0,"width")(mixHorzA, st);
	else
		mixHorzA = autoSizeA.x;

    float minW = baseSize.x;
    calcWidth!(0,"minWidth")(minW, st);

    float maxW = baseSize.x;
    calcWidth!(0,"maxWidth")(maxW, st);

	// Crap! cannot tell why pad.left needs to be added here in the case of autoSize since that
	// shoul have been included by the auto size calculation for DirectionalLayout!
	// mixHorzA += pad.left + pad.right;

	if (st.width.isMixed || st.left.isMixed || st.right.isMixed)
	{
		autoSizeB = getAutoSize!1(w, st, positionReference);
		autoSizeBCalculated = true;

		float mixHorzB = baseSize.x;
		if (autoSizeB.x.isNaN)
			calcWidth!(1,"width")(mixHorzB, st);
		else
			mixHorzB = autoSizeB.x;

		float woffset = st.width.mixOffset.isNaN ? 1f : st.width.mixOffset;

		r.x = mixHorzA * (1 - woffset) + mixHorzB * woffset;
	}
	else
	{
		r.x = mixHorzA;
	}

	float mixVertA = baseSize.y;
	if (autoSizeA.y.isNaN)
		calcHeight!(0,"height")(mixVertA, st);
	else
		mixVertA = autoSizeA.y;

    float minHeight = baseSize.y;
    calcHeight!(0, "minHeight")(minHeight, st);

    float maxHeight = baseSize.y;
    calcHeight!(0, "maxHeight")(maxHeight, st);

	// mixVertA += pad.top + pad.bottom;

	if (st.height.isMixed || st.top.isMixed || st.bottom.isMixed)
	{
		if (!autoSizeBCalculated)
			autoSizeB = getAutoSize!1(w, st, positionReference);

		float mixVertB = baseSize.y;

		if (autoSizeB.y.isNaN)
			calcHeight!(1,"height")(mixVertB, st);
		else
			mixVertB = autoSizeB.y;

		float hoffset = st.height.mixOffset.isNaN ? 1f : st.height.mixOffset;

		r.y = mixVertA * (1 - hoffset) + mixVertB * hoffset;
	}
	else
	{
		r.y = mixVertA;
	}

    import std.math;
    if (!isFinite(r.y))
    {
        r.y = r.y;
    }

    return FlexSize(Vec2f(minW, minHeight), Vec2f(maxW, maxHeight), r);
}


public Vec2f calcPosition(Widget w, Widget positionReference)
{
	Style st = w.style;
	CSSPositionMix posMix = st.position;
	Vec2f baseA = calcBasePosition(w, positionReference, posMix.cssPositionA);
	Vec2f baseB = calcBasePosition(w, positionReference, posMix.cssPositionB);

	//if (parent !is null && id == 8 && (baseA.x != 200 || baseB.x != 200))
	//    std.stdio.writeln("cp ", baseA.v, " ", baseB.v);

	// bool cssPosDiffers = st.position.posA != st.position.posB; // improve
	bool cssPosDiffers = false;

	Vec2f r = void;

	float mixHorzA = baseA.x;

	float baseWidth = getBaseValue!("w")(w);
	calcX!0(baseWidth, mixHorzA, st);
	if (st.width.isMixed || st.left.isMixed || st.right.isMixed || posMix.isMixed)
	{
		float mixHorzB = baseB.x;
		calcX!1(baseWidth, mixHorzB, st);
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
	float baseHeight = getBaseValue!("h")(w);
	calcY!0(baseHeight, mixVertA, st);
	if (st.height.isMixed || st.top.isMixed || st.bottom.isMixed || posMix.isMixed)
	{
		float mixVertB = baseB.y;
		calcY!1(baseHeight, mixVertB, st);

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

private float cssScaleToPixel(float baseValue, CSSScale s)
{
	if (s.value.isNaN)
		return s.value;

	final switch (s.unit)
	{
		case CSSUnit.pct:
			return baseValue * s.value;
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
		case CSSUnit.fit:
			return 0f;
		case CSSUnit.automatic:
			return float.nan;
	}
}

private float getBaseValue(string attr)(const(Widget) w)
{
	if (const(Widget) p = w.parent)
        return mixin("p." ~ attr);
    else
       	return mixin("w." ~ attr);
}

private void calcX(int i)(float baseWidth, ref float res, Style st)
{
	float wi = cssScaleToPixel(baseWidth, st.width[i]);
	float l = cssScaleToPixel(baseWidth, st.left[i]);
	float r = cssScaleToPixel(baseWidth, st.right[i]);

	if (wi.isNaN)
	{
        l = l.isNaN ? 0 : l;
		res += l;
	}
	else
	{
		if (!l.isNaN)
			res += l;
		else if (!r.isNaN)
			res += baseWidth - r;
	}
}

private void calcWidth(int i, string width)(ref float res, Style st)
{
	float wi = cssScaleToPixel(res, mixin("st." ~ width ~ "[i]"));
	float l = cssScaleToPixel(res, st.left[i]);
	float r = cssScaleToPixel(res, st.right[i]);

	if (wi.isNaN)
	{
        l = l.isNaN ? 0 : l;
        r = r.isNaN ? 0 : r;
		static if (width == "width")
		    res -= l + r; // // Modify incoming base value
        else
            res = float.nan;
	}
	else
	{
		// Overwrite incoming base value
		res = wi;
		if (!l.isNaN)
		{
			if (!r.isNaN)
				res -= r;
		}
	}
}

private void calcY(int i)(float baseHeight, ref float res, Style st)
{
	float hi = cssScaleToPixel(baseHeight, st.height[i]);
	float t = cssScaleToPixel(baseHeight, st.top[i]);
	float b = cssScaleToPixel(baseHeight, st.bottom[i]);

	if (hi.isNaN)
	{
        t = t.isNaN ? 0 : t;
		res += t;
	}
	else
	{
		if (!t.isNaN)
			res += t;
		else if (!b.isNaN)
			res += baseHeight - b;
	}
}

private void calcHeight(int i, string height)(ref float res, Style st)
{
	float hi = cssScaleToPixel(res, mixin("st." ~ height ~ "[i]"));
	float t = cssScaleToPixel(res, st.top[i]);
	float b = cssScaleToPixel(res, st.bottom[i]);

	if (hi.isNaN)
	{
        t = t.isNaN ? 0 : t;
        b = b.isNaN ? 0 : b;
        static if (height == "height")
		    res -= t + b;
        else
            res = float.nan;
	}
	else
	{
		res = hi;
		if (!t.isNaN)
		{
			if (!b.isNaN)
				res -= b;
		}
	}
}
