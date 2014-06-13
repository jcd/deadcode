module animation.animator;

import animation.interpolate;

class Animator
{
	this() nothrow
	{
		// Constructor code
	}
	void update(float offset)
	{
	}
}

class InterpolateAnimator(T) : Animator
{
	private
	{
		T _target;
		Interpolator _interpolator;
	} 

	this(T target, Interpolator i)
	{
		_target = target;
		_interpolator = i;
	}

	override void update(float offset)
	{
		_target = _interpolator.eval(offset);
	}
}
