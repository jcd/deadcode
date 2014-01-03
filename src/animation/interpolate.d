module animation.interpolate;
import core.time;

interface Interpolator 
{
	float eval(float offset); // offset 0..1
}

class LinearInterpolator : Interpolator
{
	float start;
	float change;

	this (float start_, float end_)
	{
		start = start_;
		change = end_ - start_;
	}

	float eval(float offset)
	{
		return change * offset + start;
	}
}

class CubicInterpolator : Interpolator
{
	float start;
	float change;

	this (float start_, float end_)
	{
		start = start_;
		change = end_ - start_;
	}

	float eval(float offset)
	{
		offset -= 1;
		return change * (offset*offset*offset*offset*offset + 1) + start;
	}
}


// Makes this possible
// auto a = LERPInterpolator();
// auto b = LERPInterpolator();
// auto c = a.pipe(b);
/*
float then(float value, Interpolator i)
{

}
*/


interface Timer
{
	void reset();
	@property double now();
}

class SystemTimer : Timer
{
	void reset() {}

	@property double now() 
	{
		return systemNow;
	}

	static @property double systemNow() 
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
		double start() const { return _start; }
		double end() const { return _start + _duration; }
		double duration() const { return _start; }
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

	@property double now() 
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
	@property double nowRelative()
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
