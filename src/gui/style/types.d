module gui.style.types;

import gui.style.style;
import gui.style.stylesheet;

import std.algorithm;

enum AnimationLoopMode
{
	once,
	pingPong,
	loop
}

/** Style Animation 
For animating styles
*/
class Animation
{
	StyleSheet sheet;
	AnimationLoopMode loopMode;

	struct KeyFrame
	{
		float offset; // 0..1 
		Style style;  // Style to overlay base style at this keyframe
	}

	KeyFrame[] keyFrames; 

	this(StyleSheet _sheet)
	{
		sheet = _sheet;
		sheet.animations ~= this;
		loopMode = AnimationLoopMode.loop;
	}

	void addKeyFrame(float offset, Style style)
	{
		auto idx = countUntil!"a.offset >= b"(keyFrames, offset);
		if (idx == -1)
		{
			keyFrames ~= KeyFrame(offset, style);
		}
		else
		{
			auto len = keyFrames.length;
			keyFrames.length = len + 1;
			keyFrames[idx+1..len] = keyFrames[idx..len-1];
			keyFrames[idx] = KeyFrame(offset, style);
		}
	}
}


class Animator
{
	import animation.interpolate;

	Animation anim;
	int frameIdx;
	float offset; // 0..1 of total animation ie. all frames
	float speed;
	Curve!float curve;

	Style animStyle;

	this(Animation a, Curve!float i)
	{
		anim = a;
		curve = i;
		frameIdx = 0;
		animStyle = new Style(anim.sheet);
	}

	void update(float dt)
	{
		updateOffset(dt);
		updateAnimStyle();
	}

	private void updateOffset(float dt)
	{
		offset += dt * speed;
		if (offset >= 1 || offset < 0)
		{
			final switch (anim.loopMode)
			{
				case AnimationLoopMode.once:
					offset = 1;
					break;
				case AnimationLoopMode.pingPong:
					if (speed > 0)
						offset = 2f - offset;
					else
						offset = -offset;
					speed = -speed;
					break;
				case AnimationLoopMode.loop:
					offset = offset - 1f;
					break;
			}
		}
	}

	private void updateAnimStyle()
	{
		// First update frameIdx if necessary
		Animation.KeyFrame keyFrame = anim.keyFrames[frameIdx];
		bool nextFramePresent = anim.keyFrames.length > frameIdx + 1;

		if (offset < keyFrame.offset)
		{
			assert(frameIdx);
			frameIdx--;
			nextFramePresent = true;
		}
		else if (nextFramePresent)
		{
			if (offset > anim.keyFrames[frameIdx+1].offset)
			{
				frameIdx++;
				nextFramePresent = anim.keyFrames.length > frameIdx + 1;
			}
		}

		// Next, update style from update frameIdx
		if (nextFramePresent)
		{
			// Linear interpolation between cur and next frame necessary
			// TODO: handle case where some style fields are only present in some
			//		 of the key frames
			Animation.KeyFrame currKeyFrame = anim.keyFrames[frameIdx];
			Animation.KeyFrame nextKeyFrame = anim.keyFrames[frameIdx+1];

			float offsetDelta = nextKeyFrame.offset - currKeyFrame.offset;
			float weightCurr = (offset - currKeyFrame.offset ) / offsetDelta;
			float weightNext = 1f - weightCurr;


		}
		else
		{
			// Last frame so just use its value
			// TODO: clear is disabled for now animStyle.clear();
			keyFrame = anim.keyFrames[frameIdx];
			animStyle.overlay(keyFrame.style);
		}
	}
}

/** CSS Transition
*/

alias float[4] CubicCurveParameters;

import core.time;

struct Transition
{
	import animation.interpolate;
	
	this(string propName, 
		 Duration dura = dur!"seconds"(0), 
		 CubicCurveParameters cubicBezier = CubicBezierCurve!float.ease[0..4], 
		 Duration delay = dur!"seconds"(0))
	{
		propertyName = propName;
		duration = dura;
		timing = cubicBezier;
		this.delay = delay;
	}

	string propertyName;
	Duration duration; // seconds
	CubicCurveParameters timing;
	Duration delay;    // seconds
}

/*
class StyleTransitionAnimator : Animator
{
	Transition transition;

	override void update(double time)
	{
		
	}
}
*/

enum CSSUnit : byte
{
	pixels,
	points,
	picas,
	ex,
	em,
	mm,
	cm,
	inch,
	pct
}

struct CSSScale
{
	float value;
	CSSUnit unit;

	@property float valueOrZero() const pure nothrow
	{
		import std.math;
		return value.isNaN ? 0 : value;
	}

	@property CSSScale clamped() const pure nothrow
	{
		return CSSScale(valueOrZero, unit);	
	}

	CSSScale opBinary(string OP)(CSSScale v) const pure nothrow
	{
		Rect!T res = this;
		mixin("res.value " ~ OP ~ "= v.value;");
		// mixin("res.size " ~ OP ~ "= v.unit;");
		return res;
	}

	void opOpAssign(string OP)(CSSScale v) pure nothrow
	{
		mixin("this.value" ~ OP ~ "= v.value;");
		//mixin("this.size" ~ OP ~ "= v.size;");
	}

	CSSScale opBinary(string OP)(float v) const pure nothrow if (OP == "*" || OP == "/")
	{
		CSSScale res = this;
		mixin("res.value " ~ OP ~ "= v;");
		return res;
	}

	void opOpAssign(string OP)(float v) pure nothrow if (OP == "*" || OP == "/")
	{
		mixin("this.value" ~ OP ~ "= v;");
	}
}

// Representation of a mix of two CSSScales A and B
// with 0 denoting all of value/unit A and 1 denoting all of value/unit B
struct CSSScaleMix
{
	CSSScale cssScaleA;
	alias cssScaleA this;

	CSSScale cssScaleB;

	float mixOffset; 

	CSSScale opIndex(int i) const pure nothrow
	{
		assert(i < 2);
		if (i == 0)
			return cssScaleA;
		return cssScaleB;
	}

	@property isMixed() const pure nothrow @safe
	{
		import std.math;
		return !mixOffset.isNaN && cssScaleA != cssScaleB;
	}
}

enum CSSPosition : byte
{
	invalid,
	static_,
	fixed,
	relative,
	absolute
}

struct CSSPositionMix 
{
	CSSPosition cssPositionA;
	alias cssPositionA this;

	CSSPosition cssPositionB;

	CSSPosition opIndex(int i) const pure nothrow
	{
		assert(i < 2);
		if (i == 0)
			return cssPositionA;
		return cssPositionB;
	}

	@property isMixed() const pure nothrow @safe
	{
		return cssPositionA != cssPositionB;
	}
}

struct RectCSSOffset
{
	CSSScale left; 
	CSSScale top;
	CSSScale right;
	CSSScale bottom;

	@property RectCSSOffset clamped() const pure nothrow
	{
		return RectCSSOffset(left.clamped, top.clamped, right.clamped, bottom.clamped);
	}

	RectCSSOffset reverse() const pure nothrow
	{
		RectCSSOffset res;
		res.left.value = -left.value;
		res.right.value = -right.value;
		res.top.value = -top.value;
		res.bottom.value = -bottom.value;
		return res;
	}

	RectCSSOffset opBinary(string OP)(RectCSSOffset v) const pure nothrow
	{
		RectCSSOffset res = this;
		mixin("res.left " ~ OP ~ "= v.left;");
		mixin("res.top " ~ OP ~ "= v.top;");
		mixin("res.right " ~ OP ~ "= v.right;");
		mixin("res.bottom " ~ OP ~ "= v.bottom;");
		return res;
	}

	void opOpAssign(string OP)(RectCSSOffset v) pure nothrow
	{
		mixin("this.left" ~ OP ~ "= v.left;");
		mixin("this.top" ~ OP ~ "= v.top;");
		mixin("this.right" ~ OP ~ "= v.right;");
		mixin("this.bottom" ~ OP ~ "= v.bottom;");
	}
	
	RectCSSOffset opBinary(string OP)(float v) const pure nothrow if (OP == "*" || OP == "/")
	{
		RectCSSOffset res = this;
		mixin("res.left " ~ OP ~ "= v;");
		mixin("res.top " ~ OP ~ "= v;");
		mixin("res.right " ~ OP ~ "= v;");
		mixin("res.bottom " ~ OP ~ "= v;");
		return res;
	}

	void opOpAssign(string OP)(float v) pure nothrow if (OP == "*" || OP == "/")
	{
		mixin("this.left" ~ OP ~ "= v;");
		mixin("this.top" ~ OP ~ "= v;");
		mixin("this.right" ~ OP ~ "= v;");
		mixin("this.bottom" ~ OP ~ "= v;");
	}

	@property bool empty() @safe nothrow
	{
		import std.math;
		return isNaN(top.value) || isNaN(left.value) || isNaN(bottom.value) || isNaN(right.value) || (top.value == 0f && left.value == 0f && bottom.value == 0f && right.value == 0f);
	}
}
