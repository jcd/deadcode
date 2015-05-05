module animation.interpolate;
import animation.mutator;
import animation.curve;

import core.time;

import graphics.color;


auto interpolate(T)(T beginValue, T endValue, float delta)
{
	return (endValue - beginValue) * delta + beginValue;
}

auto interpolate(T : int)(T beginValue, T endValue, float delta)
{
	return cast(int) std.math.round((endValue - beginValue) * delta + beginValue);
}

auto interpolate(T : uint)(T beginValue, T endValue, float delta)
{
	return cast(uint) std.math.round((endValue - beginValue) * delta + beginValue);
}

auto interpolate(T : CSSVisibility)(T beginValue, T endValue, float delta)
{
	if (endValue == beginValue)
        return endValue;

    // To support fading we treat transition from visible to hidden and vice verse different.
    if (beginValue == CSSVisibility.visible && delta >= 1)
            return CSSVisibility.hidden;

    return CSSVisibility.visible;
}

auto interpolate(T : Color)(T beginValue, T endValue, float delta)
{
	return Color.interpolate(beginValue, endValue, delta);
}

import gui.style.types;

auto interpolate(T : CSSScaleMix)(T beginValue, T endValue, float delta)
{
	// Cannot do mix here because unit of CSSScale may be percent which depends on
	// a widget to be calculated.
	CSSScaleMix r = void;
	r.cssScaleA = beginValue;
	r.cssScaleB = endValue;
	r.mixOffset = delta;
	return r;
}

auto interpolate(T : CSSPositionMix)(T beginValue, T endValue, float delta)
{
	// Positions are not mixed over time but we propegate the begin and end values
	// for e.g. the widget.calcPosition() to use.
	CSSPositionMix r = void;
	r.cssPositionA = beginValue;
	r.cssPositionB = endValue;
	return r;
}

//auto interpolate(T : CSSPositionMix)(T beginValue, T endValue, float delta)
//{
//    // Cannot do mix here because unit of CSSScale may be percent which depends on
//    // a widget to be calculated.
//    CSSPositionMix r = void;
//    r.posA = beginValue;
//    r.posB = endValue;
//    return r;
//}




/*
T to(T : Curve)(string s)
{
	switch (s)
	{
		case "linear":
			return linear();
		case "cubic":
			return cubic();
		default:
			break;
	}
	return null;
}
*/
// Makes this possible
// auto a = LERPCurve();
// auto b = LERPCurve();
// auto c = a.pipe(b);
/*
float then(float value, Curve i)
{

}
*/


interface Timer
{
	void reset();
	@property double now() const nothrow;
}

class SystemTimer : Timer
{
	void reset() {}

	@property double now() const nothrow
	{
		return systemNow;
	}

	static @property double systemNow() nothrow
	{
		auto t = TickDuration.currSystemTick;
		auto res = t.to!("seconds", double)();
		return res;
	}
}

class InterpolateTimer : Timer
{
	private
	{
		double _start;
		double _duration;
		Timer _timer;
	}

	@property
	{
		double start() const pure nothrow @safe { return _start; }
		double end() const pure nothrow @safe { return _start + _duration; }
		double duration() const pure nothrow @safe { return _start; }
	}

	this(Duration duration, Timer timer = null)
	{
		this((cast(TickDuration)duration).to!("seconds",double)(), timer);
	}

	this(Duration duration, TickDuration start, Timer timer = null)
	{
		this(timer is null ? SystemTimer.systemNow : timer.now, (cast(TickDuration)duration).to!("seconds",double)(), timer);
	}

	this(double duration, Timer timer = null)
	{
		this(duration, timer is null ? SystemTimer.systemNow : timer.now, timer);
	}

	this(double duration, double start, Timer timer = null)
	{
		_timer = timer;
		_start = start;
		_duration = duration;
	}

	void reset()
	{
		_start = _timer is null ? SystemTimer.systemNow : _timer.now;
	}

	@property double now() const nothrow
	{
		auto timeNow = _timer is null ? SystemTimer.systemNow : _timer.now;
		if (timeNow <= _start)
			return start;
		auto dt = timeNow - _start;
		if (dt >= _duration)
			return end;
		return timeNow;
	}

	// Returns: 0..1
	@property double nowRelative() const
	{
		auto timeNow = _timer is null ? SystemTimer.systemNow : _timer.now;
		if (timeNow <= _start)
			return 0f;
		auto dt = timeNow - _start;
		if (dt >= _duration)
			return 1f;
		return dt / _duration;
	}
}
