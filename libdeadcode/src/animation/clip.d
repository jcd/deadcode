module animation.clip;

import animation.curve;
import animation.curvebinding;

class Clip(T)
{
	CurveBinding!T[] bindings;

	private double _duration; // If set to -1 means calculated by looking a duration of each curve

	@property
	{
		double duration() const
		{
			import std.algorithm;

			if (_duration >= 0)
				return _duration;
			else if (bindings.length == 0)
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

		void duration(double d)
		{
			_duration = d;
		}
	}

	void clearExplicitDuration()
	{
		_duration = -1;
	}

	auto createCurve(alias propertyPath, alias CurveType, ValueType)(double x1, ValueType y1, double x2, ValueType y2)
	{
		auto b = new CurveBinding!(T, propertyPath)();
		bindings ~= b;
		b.curve = new CurveType!ValueType(x1, y1, x2, y2);
		return b;
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

	auto createCubicCurve(alias propertyPath)(double x1, uint y1, double x2, uint y2)
	{
		CurveBinding!(T, propertyPath) b = new CurveBinding!(T, propertyPath)();
		// pragma(msg, "TO2 " ~ b.MutatorType.stringof);
		bindings ~= b;
		b.curve = new CubicCurve!uint(x1, y1, x2, y2);
		return b;
	}

	auto createCubicCurve(alias propertyPath)(double x1, int y1, double x2, int y2)
	{
		CurveBinding!(T, propertyPath) b = new CurveBinding!(T, propertyPath)();
		// pragma(msg, "TO2 " ~ b.MutatorType.stringof);
		bindings ~= b;
		b.curve = new CubicCurve!int(x1, y1, x2, y2);
		return b;
	}

	void update(T obj, double timeOffset)
	{
		import std.traits;
        static if (hasMember!(T, "increaseVersion"))
			obj.increaseVersion();
		foreach (b; bindings)
			b.update(obj, timeOffset);
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
            import gui.style.types;
			// Lookup transitions in the y2 style
			// pragma(msg, "FP " ~ fieldPath ~ " -> " ~ stylePropertyToCSSName(fieldPath));
			string cssName = stylePropertyToCSSName(fieldPath);
			Transition* transition = cssName in b.transitionCache;
			if (transition is null)
			{
				//return new ConstantCurve!FieldType(0, q2, 5.0); // Todo: make instant curve. Just use 5 secs for now
				return new LinearCurve!FieldType(0, q1, 0, q2);
			}
			else
			{
				float begin = transition.delay.split!"usecs"().usecs / 1_000_000f;
				float duration = transition.duration.split!"usecs"().usecs / 1_000_000f;
                import math.bezier;
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
    import animation.mutator;

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
					// writeln("Bindable ", field.stringof);
					result ~= new CurveBinding!(T, field);
				}
				else
				{
					// writeln("Not bindable ", field.stringof);
				}
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
		//static if (f.fieldPath != "_position")
		//{
		b.curve = p.getCurve!(f.OwnerType, f.FieldType, f.fieldPath)(y1value, y2value);
		result ~= b;
		//		}
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
	import animation.mutator;
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

	Foo target = new Foo();
	target.field1 = 42;
	auto clip = new Clip!Foo();
	clip.bindings = curves;

	clip.update(target, 0.5);
	assert(target.field1 == 42);
	assert(target.field2 == 11);

	assert(target.color1 == Color.interpolate(foo.color1, foo2.color1, 0.5));
}
