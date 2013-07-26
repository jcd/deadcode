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
	@property float now();
}

class SystemTimer : Timer
{
	void reset() {}

	@property float now() 
	{
		return systemNow;
	}

	static @property float systemNow() 
	{
		return TickDuration.currSystemTick.to!("seconds", float)();
	}
}

class InterpolateTimer : Timer
{
	private
	{
		float _start;
		float _duration;
		Timer _timer;
	}

	@property
	{
		float start() const { return _start; }
		float end() const { return _start + _duration; }
		float duration() const { return _start; }
	}

	this(Duration duration, Timer timer = null)
	{
		this((cast(TickDuration)duration).to!("seconds",float)(), timer);
	}

	this(Duration duration, TickDuration start, Timer timer = null)
	{
		this(timer is null ? SystemTimer.systemNow : timer.now, (cast(TickDuration)duration).to!("seconds",float)(), timer);
	}

	this(float duration, Timer timer = null)
	{
		this(duration, timer is null ? SystemTimer.systemNow : timer.now, timer);
	}

	this(float duration, float start, Timer timer = null)
	{
		_timer = timer;
		_start = start;
		_duration = duration;
	}

	void reset() 
	{
		_start = _timer is null ? SystemTimer.systemNow : _timer.now;
	}

	@property float now() 
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
	@property float nowRelative()
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
