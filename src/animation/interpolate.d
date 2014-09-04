module animation.interpolate;
import animation.mutator;

import core.time;

import math.bezier;

//enum CurveStop
//{
//    clamp,
//    loop,
//    pingPong
//}

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

class Clip(T)
{
	CurveBinding!T[] bindings;
	
	@property double duration() const
	{
		import std.algorithm;

		if (bindings.length == 0)
			return 0.0;
		
		double begin = double.infinity;
		double end = -double.infinity;
		
		foreach (b; bindings)
		{
			begin = min(b.curveBegin, begin);
			end = max(b.curveEnd, end);
		}
		return end - begin;
	}

	auto createLinearCurve(alias propertyPath)(double x1, float y1, double x2, float y2)
	{
		auto b = new CurveBinding!(T, propertyPath)();
		bindings ~= b;
		b.curve = new LinearCurve!float(x1, y1, x2, y2);
		return b;
	}

	auto createCubicCurve(alias propertyPath)(double x1, float y1, double x2, float y2)
	{
		CurveBinding!(T, propertyPath) b = new CurveBinding!(T, propertyPath)();
		// pragma(msg, "TO2 " ~ b.MutatorType.stringof);
		bindings ~= b;
		b.curve = new CubicCurve!float(x1, y1, x2, y2);
		return b;
	}

	void update(T object, double timeOffset)
	{
		foreach (b; bindings)
			b.update(object, timeOffset);
	}
}

void createCurves(alias CurveType, T)(Clip!T clip, double x1, T y1, double x2, T y2)
{
	struct CurveProvider
	{
		double _x1;
		double _x2;

		this(double _x1, double _x2)
		{
			this._x1 = _x1;
			this._x2 = _x2;
		}

		Curve!FieldType getCurve(OwnerType, FieldType, string fieldPath)(FieldType q1, FieldType q2)
		{			
			return new CurveType!(FieldType)(_x1, q1, _x2, q2);
		}
	}

	clip.bindings ~= getTransitionCurves(CurveProvider(x1, x2), y1, y2);
}

import gui.style.style;

void createCurves(Clip!Style clip, Style y1, Style y2)
{
	struct CurveProvider
	{
		Style a;
		Style b;

		this(Style styleA, Style styleB)
		{
			a = styleA;
			b = styleB;
		}

		Curve!FieldType getCurve(OwnerType, FieldType, string fieldPath)(FieldType q1, FieldType q2)
		{
			// Lookup transitions in the y2 style
			pragma(msg, "FP " ~ fieldPath ~ " -> " ~ stylePropertyToCSSName(fieldPath));
			string cssName = stylePropertyToCSSName(fieldPath);
			Transition* transition = cssName in b.transitionCache;
			if (transition is null)
			{
				return new ConstantCurve!FieldType(0, q2, 0.1); // Todo: make instant curve
			}
			else
			{
				float begin = transition.delay.split!"usecs"().usecs / 1_000_000f;
				float duration = transition.duration.split!"usecs"().usecs / 1_000_000f;
				auto b = UnitBezier(transition.timing[0], transition.timing[1],
								    transition.timing[2], transition.timing[3]);

				return new CubicBezierCurve!FieldType(begin, q1, begin + duration, q2, b);
			}
		}
	}

	clip.bindings ~= getTransitionCurves(CurveProvider(y1, y2), y1, y2);
}

static CurveBinding!T[] getCurves(T)()
{
	import std.traits;
	import std.typetuple;
	import std.stdio;

	typeof(return) result;

	foreach (field; __traits(allMembers,T))
	{
		static if (field == "this")
		{
			continue;
		}
		else
		{
			foreach (attr;  __traits(getAttributes, mixin("T." ~ field)))
			{
				static if (is(typeof(attr) : Bindable))
				{
					writeln("Bindable ", field.stringof);
					result ~= new CurveBinding!(T, field);
				}
				else
					writeln("Not bindable ", field.stringof);
			}
		}
	}
	return result;
}

//CurveBinding!T createBinding(FP)(FP fieldProxy)
//{
//    return new CurveBinding!(FP.fieldPath, FP.OwnerType)();
//}

static CurveBinding!T[] getTransitionCurves(alias C, T)(double x1, T y1, double x2, T y2)
{
	struct CurveProvider
	{
		double _x1;
		double _x2;

		this(double _x1, double _x2)
		{
			this._x1 = _x1;
			this._x2 = _x2;
		}

		Curve!FieldType getCurve(OwnerType, FieldType, string fieldPath)(FieldType q1, FieldType q2)
		{
			return new C!(FieldType)(_x1, q1, _x2, q2);
		}
	}
	return getTransitionCurves(CurveProvider(x1, x2), y1, y2);
}

static CurveBinding!T[] getTransitionCurves(CurveProvider, T)(CurveProvider p, T y1, T y2)
{
	import animation.mutator;
	ObjectProxy!T proxyObj1 = proxy(y1);
	ObjectProxy!T proxyObj2 = proxy(y2);

	CurveBinding!T[] result;
	
	// pragma(msg, T);
	//pragma(msg, ObjectProxy!T.fields);	
	
	foreach (f; ObjectProxy!T.fields)
	{
		auto b = new CurveBinding!(f.OwnerType, f.fieldPath)();
		string ff = f.fieldPath;
//		b.curve = new C!(f.FieldType)(x1, f.get(y1), x2, f.get(y2));
		auto y1value = f.get(y1);
		auto y2value = f.get(y2);
		//if (y1value != y2value)
		//{
		
		// TODO: Make Animatable() in addition to Bindable()
		static if (f.fieldPath != "_position")
		{
			b.curve = p.getCurve!(f.OwnerType, f.FieldType, f.fieldPath)(y1value, y2value);
			result ~= b;
		}
		//}
	}
	
	return result;
}


//static Clip!T createTransitionClip(T)(T start, T end)
//{
//    auto curves = getCurves!T();
//
//}

static this()
{
	class Foo 
	{
		float field1;
		
		@Bindable()
		float field2;
		
		@Bindable()
		Color color1;
	}
	
	// pragma(msg, ObjectProxy!Foo.fields);
	
	auto res = getCurves!Foo();
	
	auto foo = new Foo();
	foo.field1 = 1;
	foo.field2 = 2;
	foo.color1 = Color.fromCSSString("#FFFFFF")[0];
	(cast(CurveBinding!(Foo, "field2"))(res[0])).curve = new LinearCurve!float(0, 0, 1, 10);
	res[0].update(foo, 0.5);
	// std.stdio.writeln(foo.field1, " ", foo.field2);

	auto foo2 = new Foo();
	foo2.field1 = 10;
	foo2.field2 = 20;
	foo.color1 = Color.fromCSSString("#00FF00")[0];

	foo.field1 = 1;
	foo.field2 = 2;
	auto curves = getTransitionCurves!LinearCurve(0, foo, 1, foo2);

	auto target = new Foo();
	target.field1 = 42;
	auto clip = new Clip!Foo();
	clip.bindings = curves;
	
	clip.update(target, 0.5);
	assert(target.field1 == 42);
	assert(target.field2 == 11);
	
	assert(target.color1 == Color.interpolate(foo.color1, foo2.color1, 0.5));
}

class CurveBinding(T) if ( ! is (T : FieldProxy!(A,B), A, B) )
{
	// pragma(msg, "fda " ~ T.OwnerType.stringof);|
	abstract @property
	{
		double curveBegin() const pure;
		double curveEnd() const pure;
	}
	abstract void update(T object, double timeOffset);
}
/*
class CurveBinding( MutatorType : FieldProxy!(A,B), A, B) : CurveBinding!(MutatorType.OwnerType)
{
	
	//	alias DirectFieldMutator!(Field, T) MutatorType;
	// alias FieldProxy!(Field, T) MutatorType;

	static if (is(MutatorType.FieldType : float))
	{
		override void update(MutatorType.OwnerType object, double timeOffset) 
		{
			float value = curve.eval(timeOffset);
			MutatorType.set(object, value);
		}
	}
}
*/

import graphics.color;
import std.traits;

class CurveBinding(T, string Field) : CurveBinding!T 
{
	//	alias DirectFieldMutator!(Field, T) MutatorType;
	alias FieldProxy!(Field, T) MutatorType;
	alias Unqual!(MutatorType.FieldType) ValueType;

	Curve!ValueType curve;

	override @property
	{
		double curveBegin() const pure { return curve.begin; }
		double curveEnd() const pure { return curve.end; }
	}

	//static if (is(MutatorType.FieldType : float))
	//{
		override void update(T object, double timeOffset)
		{
			ValueType value = curve.eval(timeOffset);
			MutatorType.set(object, value);
		}
	//}
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

auto interpolate(T)(T beginValue, T endValue, float delta)
{
	return (endValue - beginValue) * delta + beginValue;
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

//auto interpolate(T : CSSPositionMix)(T beginValue, T endValue, float delta)
//{
//    // Cannot do mix here because unit of CSSScale may be percent which depends on
//    // a widget to be calculated.
//    CSSPositionMix r = void;
//    r.posA = beginValue;
//    r.posB = endValue;
//    return r;
//}


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
		if (offset <= _begin)
			return interpolate(_beginValue, _endValue, 0);
		else if (offset >= _end)
			return interpolate(_beginValue, _endValue, 1);
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
