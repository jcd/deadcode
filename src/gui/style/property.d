module gui.style.property;

import gui.style.parser;
import gui.style.style;
import gui.style.stylesheet;

import math._;

alias string PropertyID;

/** Specifies the name, type and default value of a style property
*/
interface IPropertySpecification
{
	@property 
	{
		PropertyID id() const pure nothrow;
		bool inherited() const pure nothrow;
	}

	// Return true if parser.curToken is not yet consumed
	abstract bool parse(StyleSheetParser parser, Style style);
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
		PropertyID id() const pure nothrow
		{
			return _id;
		}
		bool inherited() const pure nothrow
		{
			return _inherited;
		}
		bool multi() const pure nothrow
		{
			return _multi;
		}
		void multi(bool v) pure nothrow
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

	void getDefault(ref T _default) 
	{
		_default = this._default;
	}
}

class PropertySpecification(T : float) : PropertySpecificationBase!T
{
	this(PropertyID _id, T _default, bool _inherited = false)
	{
		super(_id, _default, _inherited);
	}

	bool parse(StyleSheetParser parser, Style style)
	{
		style._fields.floats[id] = parser.requireNextOptionalNumber();
		return false;
	}

	static void overlay(ref T[PropertyID] dest, PropertyID key, const(T) value)
	{
		if (!value.isNaN() && key !in dest)
			dest[key] = value;
	}
}

class PropertySpecification(T : Vec2f) : PropertySpecificationBase!T
{
	this(PropertyID _id, T _default, bool _inherited = false)
	{
		super(_id, _default, _inherited);
	}

	bool parse(StyleSheetParser parser, Style style)
	{
		Vec2f r;
		r.x = parser.requireNextOptionalNumber();
		r.y = parser.requireNextOptionalNumber();
		style._fields.vec2fs[id] = r;
		return false;
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

	bool parse(StyleSheetParser parser, Style style)
	{
		Rectf r;
		r.x = parser.requireNextOptionalNumber();
		r.y = parser.requireNextOptionalNumber();
		r.w = parser.requireNextOptionalNumber();
		r.h = parser.requireNextOptionalNumber();
		style._fields.rects[id] = r;
		return false;
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
