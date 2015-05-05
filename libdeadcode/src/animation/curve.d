module animation.curve;

import animation.interpolate;

//enum CurveStop
//{
//    clamp,
//    loop,
//    pingPong
//}

/** An abstract curve

Provides a begin, end point and the posibility to evaluate the value
of the curve at a given timeoffset.
*/
class Curve(T)
{
	// CurveStop curveStop;

	abstract @property
	{
		double begin() const pure;
		double end() const pure;
	}

	@property duration() const pure
	{
		return end - begin;
	}

	abstract T eval(double timeOffset);
}

class SampleCurve(T) : Curve!T
{
	struct Sample
	{
		double x;
		T y;
	}

	@property
	{
		double begin() const pure { return _begin; }
		double end() const pure   { return _end; }
	}

	this (double b, double e)
	{
		_begin = b;
		_end = e;
	}

	float eval(double timeOffset)
	{
		return offset;
	}
}

class ConstantCurve(T) : Curve!T
{
	private
	{
		double _begin;
		double _end;
		T _beginValue;
	}

	override @property
	{
		double begin() const pure { return _begin; }
		double end() const pure   { return _end; }
	}

	this(double xBegin, T yBegin, double xEnd)
	{
		_begin = xBegin;
		_end = xEnd;
		_beginValue = yBegin;
	}

	override T eval(double offset)
	{
		return _beginValue;
	}
}

class LinearCurve(T) : Curve!T
{
	private
	{
		double _begin;
		double _end;
		T  _beginValue;
		T  _endValue;
	}

	override @property
	{
		double begin() const pure { return _begin; }
		double end() const pure   { return _end; }
	}

	this(double xBegin, T yBegin, double xEnd, T yEnd)
	{
		_begin = xBegin;
		_end = xEnd;
		_beginValue = yBegin;
		_endValue = yEnd;
	}

	override T eval(double offset)
	{
		if (offset >= _end)
			return interpolate(_beginValue, _endValue, 1);
		else if (offset < _begin)
			return interpolate(_beginValue, _endValue, 0);
		else
		{
			float delta = (offset - _begin) / (_end - _begin);
			return interpolate(_beginValue, _endValue, delta);
		}
	}
}

LinearCurve!T linear(T)()
{
	static LinearCurve!T i;
	if (i is null)
		i = new LinearCurve!T(0, 0, 1, 1);
	return i;
}

class CubicCurve(T) : Curve!T
{
	private
	{
		double _begin;
		double _end;
		T  _beginValue;
		T  _endValue;
	}

	override @property
	{
		double begin() const pure { return _begin; }
		double end() const pure   { return _end; }
	}

	this(double xBegin, T yBegin, double xEnd, T yEnd)
	{
		_begin = xBegin;
		_end = xEnd;
		_beginValue = yBegin;
		_endValue = yEnd;
	}

	override T eval(double offset)
	{

		if (offset <= _begin)
			return interpolate(_beginValue, _endValue, 0);
		else if (offset >= _end)
			return interpolate(_beginValue, _endValue, 1);
		else
		{
			float delta = (offset - _begin) / (_end - _begin);
			delta -= 1;
			delta = delta*delta*delta*delta*delta + 1;
			return interpolate(_beginValue, _endValue, delta);
		}
	}
}

CubicCurve!T cubic(T)()
{
	static CubicCurve!T _cubic;
	if (_cubic is null)
		_cubic = new CubicCurve!T(0, 0, 1, 1);

	return _cubic;
}

class CubicBezierCurve(T) : Curve!T
{
    import math.bezier;

	private
	{
		double _begin;
		double _end;
		T  _beginValue;
		T  _endValue;

		UnitBezier _unitBezier;
	}

	//union
	//{
	//    float[4] p;
	//    struct
	//    {
	//        float p0, p1, p2, p3;
	//    }
	//}

	static immutable ease   = [0.25f, 0.1f, 0.25f, 1];
	static immutable linear = [0f, 0, 1, 1];
	static immutable easeIn = [0.42f, 0, 1, 1];
	static immutable easeOut = [0f, 0, 0.58f, 1];
	static immutable easeInOut = [0.42f, 0, 0.58f, 1];

	override @property
	{
		double begin() const pure { return _begin; }
		double end() const pure   { return _end; }
	}

	this(double xBegin, T yBegin, double xEnd, T yEnd, UnitBezier ub)
	{
		_begin = xBegin;
		_end = xEnd;
		_beginValue = yBegin;
		_endValue = yEnd;
		_unitBezier = ub;
		//p[] = ease;
	}

	override T eval(double offset)
	{

		if (offset <= _begin)
			return interpolate(_beginValue, _endValue, 0);
		else if (offset >= _end)
			return interpolate(_beginValue, _endValue, 1);
		else
		{
			double duration = _end - _begin;
			double t = (offset - _begin) / duration;
			//double e = 1-t;

			//import math.smallvector;
			//
			//Vec2f pa = Vec2f(0,0);
			//Vec2f pb = Vec2f(p0,p1);
			//Vec2f pc = Vec2f(p2,p3);
			//Vec2f pd = Vec2f(0,0);

			//Vec2f b =      (1.0-t*t*t)*        pa +
			//          3.0 * (1.0-t*t) * t *     pb +
			//          3.0 * (1.0-t) *   t*t *   pc +
			//                            t*t*t * pd;

			//Vec2f b = pa *     (1.0-t*t*t)        +
			//    pb * (3.0 * (1.0-t*t) * t)      +
			//    pc * (3.0 * (1.0-t) *   t*t)    +
			//    pd * (t*t*t);
			//

			double epsilon = 1.0 / (200.0 * duration);
			auto y = _unitBezier.solve(t, epsilon);

			T result = interpolate(_beginValue, _endValue, y);
			//static if (is(T : CSSScaleMix))
			//    std.stdio.writeln(offset, " ", " ", _begin, " ", b);
			return result;

			//
			//auto b =     (1-t^3) * p0 +
			//         3 * (1-t^2) * t * p1 +
			//         3 * (1-t) * t^2 * p2 +
			//         t^3 * p3;
		}
	}
}
