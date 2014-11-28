module animation.animator;

import animation.interpolate;

class Animator
{
	this() nothrow
	{
		// Constructor code
	}

	@property bool done()
	{
		return true;
	}

	void update(double offset)
	{
	}
}

class InterpolateAnimator(T, V) : Animator
{
	private
	{
		T _target;
		Curve _curve;
	} 

	this(T target, Curve c)
	{
		_target = target;
		_curve = c;
	}

	override void update(double offset)
	{
		_target = _curve.eval(offset);
		// auto delta = _curve.eval(offset);
		// _target = delta * _end + (1 - delta) * _begin;
	}
}

class AnimatedObject(T) : Animator
{
	Clip!T clip;
	T object;

	this(T object)
	{
		this.object = object;
	}

	Clip!T createClip()
	{
		clip = new Clip!T();
		return clip;
	}

	override void update(double timeOffset)
	{
		clip.update(object, timeOffset);
	}
}

