module gui.style.property;

import animation.interpolate;

import gui.style.parser;
import gui.style.style;
import gui.style.stylesheet;
import gui.style.types;

import math;

import std.range;

alias string PropertyID;

/** Specifies the name, type and default value of a style property
*/
interface IPropertySpecification
{
	@property
	{
		PropertyID id() const pure nothrow @safe;
		bool inherited() const pure nothrow @safe;
		bool multi() const pure nothrow @safe;
	}

	// Return true if property value is parsed and
	// set in style
	abstract bool parse(StyleSheetParser parser, Style style) const @safe;
	abstract void setDefault(Style style) const pure nothrow @trusted;
	abstract void clear(Style style) const pure nothrow @safe;
}

abstract class PropertySpecificationBase(T) : IPropertySpecification
{
	private
	{
		PropertyID _id;
		T _default;
		bool _inherited;
		bool _multi;
	}

	@property
	{
		PropertyID id() const pure nothrow @safe
		{
			return _id;
		}
		bool inherited() const pure nothrow @safe
		{
			return _inherited;
		}
		bool multi() const pure nothrow @safe
		{
			return _multi;
		}
		void multi(bool v) pure nothrow @safe
		{
			_multi = v;
		}
	}

	this(PropertyID _id, T _default, bool _inherited)
	{
		this._id = _id;
		this._default = _default;
		this._inherited = _inherited;
		_multi = false;
	}

	T getDefaultValue() const pure nothrow @safe
	{
		return _default;
	}
}

class PropertySpecification(T : float) : PropertySpecificationBase!T
{
	this(PropertyID _id, T _default, bool _inherited = false)
	{
		super(_id, _default, _inherited);
	}

	bool parse(StyleSheetParser parser, Style style) const @safe
	{
		auto tok = parser.nextToken();
		float num;
		if (tok.asNumber(num))
		{
			if (!multi || style.floats.get(id, null) is null)
			{
				style.floats[id] = [ num ];
			}
			else
			{
				style.floats[id] ~= num;
			}
			return true;
		}
		parser.resetToToken(tok);
		return false;
	}

	void setDefault(Style style) const pure nothrow @trusted
	{
		try
		{
			if (!multi || style.floats.get(id, null) is null)
				style.floats[id] = [ _default ];
			else
				style.floats[id] ~= _default;
		}
		catch (Exception)
		{
			assert(0);
		}
	}

	void clear(Style style) const pure nothrow @safe
	{
		style.floats[id] = null;
	}

	static void overlay(ref T[][PropertyID] dest, PropertyID key, T[] value)
	{
		//if (!value.isNaN() && key !in dest)
		if (value.length && key !in dest)
			dest[key] = value;
	}
}

import std.datetime;
class PropertySpecification(T : Duration) : PropertySpecificationBase!T
{
	this(PropertyID _id, T _default, bool _inherited = false)
	{
		super(_id, _default, _inherited);
	}

	bool parse(StyleSheetParser parser, Style style) const @safe
	{
		auto tok = parser.nextToken();
		float num;
		if (tok.asNumber(num))
		{
			auto tok2 = parser.nextToken();
			Duration d;
			if (tok2.value == "s")
			{
				d = dur!"usecs"(cast(long)(num * 1_000_000));
			}
			else if (tok2.value == "ms")
			{
				d = dur!"usecs"(cast(long)(num * 1_000));
			}
			else
			{
				parser.addError("Invalid duration unit " ~ tok2.value);
				throw new Exception("Invalid duration unit");
			}

			float dd = d.total!"seconds"();

			if (!multi || style.durations.get(id, null) is null)
			{
				style.durations[id] = [ d ];
			}
			else
			{
				style.durations[id] ~= d;
			}
			return true;
		}
		parser.resetToToken(tok);
		return false;
	}

	void setDefault(Style style) const pure nothrow @trusted
	{
		try
		{
			if (!multi || style.durations.get(id, null) is null)
				style.durations[id] = [ _default ];
			else
				style.durations[id] ~= _default;
		}
		catch (Exception)
		{
			assert(0);
		}
	}

	void clear(Style style) const pure nothrow @safe
	{
		style.durations[id] = null;
	}

	static void overlay(ref T[][PropertyID] dest, PropertyID key, T[] value)
	{
		//if (!value.isNaN() && key !in dest)
		if (value.length && key !in dest)
			dest[key] = value;
	}
}

class PropertySpecification(T : CubicCurveParameters) : PropertySpecificationBase!T
{
	this(PropertyID _id, T _default, bool _inherited = false)
	{
		super(_id, _default, _inherited);
	}

	bool parse(StyleSheetParser parser, Style style) const @safe
	{
		import animation.interpolate;

		auto tok = parser.nextToken();

		CubicCurveParameters params;
		switch (tok.value)
		{
			case "ease":
				params = CubicBezierCurve!float.ease;
				break;
			case "linear":
				params = CubicBezierCurve!float.linear;
				break;
			case "ease-in":
				params = CubicBezierCurve!float.easeIn;
				break;
			case "ease-out":
				params = CubicBezierCurve!float.easeOut;
				break;
			case "ease-in-out":
				params = CubicBezierCurve!float.easeInOut;
				break;
			case "cubic-bezier":
				parser.requireNextToken(StyleSheetParser.TokenType.parenOpen);
				StyleSheetParser.Token n1 = parser.requireNextToken(StyleSheetParser.TokenType.number);
				n1.asNumber(params[0]);
				parser.requireNextToken(StyleSheetParser.TokenType.comma);
				StyleSheetParser.Token n2 = parser.requireNextToken(StyleSheetParser.TokenType.number);
				n2.asNumber(params[1]);
				parser.requireNextToken(StyleSheetParser.TokenType.comma);
				StyleSheetParser.Token n3 = parser.requireNextToken(StyleSheetParser.TokenType.number);
				n3.asNumber(params[2]);
				parser.requireNextToken(StyleSheetParser.TokenType.comma);
				StyleSheetParser.Token n4 = parser.requireNextToken(StyleSheetParser.TokenType.number);
				n4.asNumber(params[3]);
				parser.requireNextToken(StyleSheetParser.TokenType.parenClose);
				break;
			default:
				parser.resetToToken(tok);
				return false;
		}

		if (!params.empty && !params[0].isNaN)
		{
			if (style.curveParameters.get(id,null) is null)
				style.curveParameters[id] = [ params ];
			else
				style.curveParameters[id] ~= params;
			return true;
		}
		else
		{
			parser.resetToToken(tok);
			return false;
		}
	}

	void setDefault(Style style) const pure nothrow @trusted
	{
		try
		{
			if (style.curveParameters.get(id, null) is null)
				style.curveParameters[id] = [ _default ];
			else
				style.curveParameters[id] ~= _default;
		}
		catch (Exception)
		{
			assert(0);
		}
	}

	void clear(Style style) const pure nothrow @safe
	{
		style.curveParameters[id] = null;
	}

	static void overlay(ref T[][PropertyID] dest, PropertyID key, T[] value)
	{
		//if (!value.isNaN() && key !in dest)
		if (value.length && key !in dest)
			dest[key] = value;
	}
}

class PropertySpecification(T : PropertyID) : PropertySpecificationBase!T
{
	this(PropertyID _id, T _default, bool _inherited = false)
	{
		super(_id, _default, _inherited);
	}

	bool parse(StyleSheetParser parser, Style style) const @safe
	{
		if (parser.peekToken().type == StyleSheetParser.TokenType.identifier)
		{
			if (!multi || style.propertyIDs.get(id, null) is null)
			{
				style.propertyIDs[id] = [ parser.nextToken().value ];
			}
			else
			{
				style.propertyIDs[id] ~= parser.nextToken().value;
			}
			return true;
		}
		return false;
	}

	void setDefault(Style style) const pure nothrow @trusted
	{
		try
		{
			if (!multi || style.propertyIDs.get(id, null) is null)
				style.propertyIDs[id] = [_default];
			else
				style.propertyIDs[id] ~= _default;
		}
		catch (Exception)
		{
			assert(0);
		}
	}

	void clear(Style style) const pure nothrow @safe
	{
		style.propertyIDs[id] = null;
	}

	static void overlay(ref T[][PropertyID] dest, PropertyID key, T[] value)
	{
		if (value.length && key !in dest)
			dest[key] = value;
	}
}
/*
class PropertySpecification(T : Curve!U, U) : PropertySpecificationBase!T
{
	this(PropertyID _id, T _default, bool _inherited = false)
	{
		super(_id, _default, _inherited);
	}

	bool parse(StyleSheetParser parser, Style style)
	{
		if (parser.peekToken().type == StyleSheetParser.TokenType.identifier)
		{
			auto i = parser.peekToken.value.to!Curve;
			if (i !is null)
			{
				if (!multi || style.curves is null)
					style.curves = [ i ];
				else
					style.curves ~= i;
				parser.nextToken;
				return true;
			}
		}
		return false;
	}

	void setDefault(Style style)
	{
		if (!multi || style.curves is null)
			style.curves = [ _default ];
		else
			style.curves ~= _default;
	}

	void clear(Style style)
	{
		style.curves = null;
	}

	static void overlay(ref T[] dest, T[] value)
	{
		if (value.length)
			dest = value;
	}
}
*/

class PropertySpecification(T : Vec2f) : PropertySpecificationBase!T
{
	this(PropertyID _id, T _default, bool _inherited = false)
	{
		super(_id, _default, _inherited);
	}

	bool parse(StyleSheetParser parser, Style style) const @safe
	{
		Vec2f r;

		auto tok1 = parser.nextToken();
		auto tok2 = parser.nextToken();
		float num1;
		float num2;

		if (tok1.asNumber(num1) && tok2.asNumber(num2))
		{
			r.x = num1;
			r.y = num2;
			style.vec2fs[id] = r;
			return true;
		}

		parser.resetToToken(tok1);
		return false;
	}

	void setDefault(Style style) const pure nothrow @safe
	{
		style.vec2fs[id] = _default;
	}

	void clear(Style style) const pure nothrow @safe
	{
		style.vec2fs[id] = T.init;
	}

	static void overlay(ref T[PropertyID] dest, PropertyID key, const(T) value)
	{
		T* v = key in dest;
		T res;

		if (v)
			res = v;

		bool changed = false;

		if (res.x.isNaN() && !value.x.isNaN())
		{
			changed = true;
			res.x = value.x;
		}

		if (res.y.isNaN() && !value.y.isNaN())
		{
			changed = true;
			res.y = value.y;
		}

		if (changed)
			dest[key] = res;
	}
}

class PropertySpecification(T : Rectf) : PropertySpecificationBase!T
{
	this(PropertyID _id, T _default, bool _inherited = false)
	{
		super(_id, _default, _inherited);
	}

	bool parse(StyleSheetParser parser, Style style) const @safe
	{
		float num1, num2, num3, num4;
		auto tok1 = parser.nextToken();
		auto tok2 = parser.nextToken();
		auto tok3 = parser.nextToken();
		auto tok4 = parser.nextToken();

		if (tok1.asNumber(num1) &&
			tok2.asNumber(num2) &&
			tok3.asNumber(num3) &&
			tok4.asNumber(num4))
		{
			Rectf r;
			r.x = num1;
			r.y = num2;
			r.w = num3;
			r.h = num4;
			style.rects[id] = r;
			return true;
		}
		parser.resetToToken(tok1);
		return false;
	}

	void setDefault(Style style) const pure nothrow @safe
	{
		style.rects[id] = _default;
	}

	void clear(Style style) const pure nothrow @safe
	{
		style.rects[id] = T.init;
	}

	static void overlay(ref T[PropertyID] dest, PropertyID key, const(T) value)
	{
		T* v = key in dest;
		T res;

		if (v)
			res = *v;

		bool changed = false;

		if (res.x.isNaN() && !value.x.isNaN())
		{
			changed = true;
			res.x = value.x;
		}

		if (res.y.isNaN() && !value.y.isNaN())
		{
			changed = true;
			res.y = value.y;
		}

		if (res.w.isNaN() && !value.w.isNaN())
		{
			changed = true;
			res.size.x = value.w;
		}

		if (res.h.isNaN() && !value.h.isNaN())
		{
			changed = true;
			res.size.y = value.h;
		}

		if (changed)
			dest[key] = res;
	}
}

class PropertyShorthand : IPropertySpecification
{
	private
	{
		PropertyID _id;
		bool _inherited;
		bool _multi;
		IPropertySpecification[] subProperties;
	}

	@property
	{
		PropertyID id() const pure nothrow @safe
		{
			return _id;
		}
		bool inherited() const pure nothrow @safe
		{
			return _inherited;
		}
		bool multi() const pure nothrow @safe
		{
			return _multi;
		}
		void multi(bool f) pure nothrow @safe
		{
			_multi = f;
		}
	}

	this(PropertyID id, IPropertySpecification[] subProps, bool inherited = false)
	{
		_id = id;
		_inherited = inherited;
		subProperties = subProps;
		_multi = false;
	}

	bool parse(StyleSheetParser parser, Style style) const @safe
	{
		// Parsed subproperties in order and in a cycle.
		// When either a no subproperty has been parsed through an
		// entire cycle but something is left (an parse error) or the } token
		// is reached we stop.
		const(IPropertySpecification)[] cycleProps;
		foreach (i, v; subProperties)
			cycleProps ~= v;
		size_t lastLen = 0;

		auto multiDelim = multi ? parser.TokenType.comma : parser.TokenType.semicolon;

		while (lastLen != cycleProps.length)
		{
			lastLen = cycleProps.length;

			import std.algorithm;

			// BUG WORKAROUND FOR:	cycleProps = cycleProps.remove!( p => p.parse(parser,style) );
			const(IPropertySpecification)[] newCycleProps;
			foreach (i, v; cycleProps)
			{
				if (!v.parse(parser, style))
					newCycleProps ~= v;
			}
			cycleProps = newCycleProps;

			if (parser.peekToken().oneOf(parser.TokenType.curlClose,
										 parser.TokenType.semicolon,
										 multiDelim))
				break;
		}

		if (!parser.peekToken().oneOf(parser.TokenType.curlClose,
									  parser.TokenType.semicolon, multiDelim))
		{
			parser.addError("Unexpected token at this point in file '" ~ parser.curToken.value ~ "'", parser.line);
			throw new Exception("Unexpected token in stylesheet property shortcut");
		}

		// Set unset props to default value as CSS also does.
		foreach (p; cycleProps)
		{
			p.setDefault(style);
		}

		return true;
	}

	void clear(Style style) const pure nothrow @safe
	{
		// Set unset props to default value as CSS also does.
		foreach (p; subProperties)
		{
			p.clear(style);
		}
	}

	void setDefault(Style style) const pure nothrow @safe
	{
		assert(0);
	}
}
