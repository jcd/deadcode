module animation.animator;

import animation.interpolate;

class AnimatorBase
{
	this()
	{
		// Constructor code
	}
	void update(float offset)
	{
	}
}

class Animator(T) : AnimatorBase
{
	private
	{
		T* _target;
		Interpolator _interpolator;
	}

	this(T* target, Interpolator i)
	{
		_target = target;
		_interpolator = i;
	}

	override void update(float offset)
	{
		*_target = _interpolator.eval(offset);
	}
}