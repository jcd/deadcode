/** Animator classes are used to animate objects such as a Sprite or Style

    These classes are usually not instantiated directly but through an instance of Timeline and its animate methods.
*/
module animation.animator;

import animation.interpolate;

/** A Animator is a base class for classes that can do animation

    It provides the interface for updates and knowing when a animation is done.

    Animator classes and derivative are usually not created directly but by using
    an instance of Timeline.

    See_Also: Timeline
*/
class Animator
{
	/// True when this animator is done animating
    @property bool done()
	{
		return true;
	}

	/// Called on each tick with the time offset when this Animator is enabled
	void update(double offset)
	{
	}
}

version (OFF)
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

/** A animator that will call its targets update method in discrete time intervals

    Animator classes and derivative are usually not created directly but by using
    an instance of Timeline.

    See_Also: Timeline
*/
class DiscreteAnimator(T) : Animator
{
	private	T _target;
    private    double _timeStep;
    private    double _nextTick;
    private   int count;

    /** Accepting a target object and a timestep

        Params:
            target   = the target object to be updated
            timeStep = the time step between each update call on object
    */
	this(T target, double timeStep) nothrow
	{
		_target = target;
        _timeStep = timeStep;
        _nextTick = 0;
	}

	/// Called on each tick when this Animator is enabled with the time offset
	override void update(double offset)
	{
        if (_nextTick > offset)
            return;
        _nextTick += _timeStep;

        static if (is (T == delegate))
            _target(offset, count++);
        else
            _target.update(offset, count++);
	}
}

/** An Animator that will apply a Clip on a target object

    This Animator uses a target type specific Clip and applies it to an instance
    of such a type at the given time offset.

    Animator classes and derivative are usually not created directly but by using
    an instance of Timeline.

    See_Also: Timeline
*/
class AnimatedObject(T) : Animator
{
	import animation.clip;

    T object;    /// The object being animated
	Clip!T clip; /// The Clip used for animating the object

	/** Constructor accepting the object to be animated

        This constructor will create an Animator ready for animating the object using a Clip.
        A Clip needs to be assigned after construction before adding this to a Timeline or
        using any of its methods.

        Params:
            object = the object to be animated using a Clip!typeof(object)
    */
    this(T object)
	{
		this.object = object;
	}

	/** Creates a Clip and assign it to this object

        Returns: the newly created Clip
    */
    Clip!T createClip()
	{
		clip = new Clip!T();
		return clip;
	}

	/// Called on each tick when this Animator is enabled with the time offset
	override void update(double timeOffset)
	{
		clip.update(object, timeOffset);
	}
}

