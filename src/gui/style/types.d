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
	Interpolator interpolator;

	Style animStyle;

	this(Animation a, Interpolator i)
	{
		anim = a;
		interpolator = i;
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
			animStyle.clear();
			keyFrame = anim.keyFrames[frameIdx];
			animStyle.overlay(keyFrame.style);
		}
	}
}

/** CSS Transition
*/
class Transition
{
	import animation.interpolate;

	float delay;    // seconds
	float duration; // seconds
	Interpolator timing;
	string propertyName;
}

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
}

struct RectCSSOffset
{
	CSSScale left; 
	CSSScale top;
	CSSScale right;
	CSSScale bottom;

	RectCSSOffset reverse() const pure nothrow
	{
		RectCSSOffset res;
		res.left.value = -left.value;
		res.right.value = -right.value;
		res.top.value = -top.value;
		res.bottom.value = -bottom.value;
		return res;
	}

	@property bool empty() @safe nothrow
	{
		import std.math;
		return isNaN(top.value) || isNaN(left.value) || isNaN(bottom.value) || isNaN(right.value) || (top.value == 0f && left.value == 0f && bottom.value == 0f && right.value == 0f);
	}
}
