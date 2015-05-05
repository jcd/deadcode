module animation.curvebinding;

import animation.curve;
import animation.mutator;

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
