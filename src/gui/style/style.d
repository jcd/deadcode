module gui.style.style;

import math._;

import graphics.color : Color;

import gui.resources.material;
import gui.resources.font : Font, FontManager;

import gui.style.property;
import gui.style.stylesheet;
import gui.style.types;

import std.string;

alias string StyleID;
immutable StyleID NullStyleName = "";
immutable StyleID DefaultStyleName = "default";

string cssifyName(string name)
{
	string res;
	foreach (c; name)
		if (c >= 'A' && c <= 'Z')
		{
			res ~= "-";
			res ~= c.toLower();
		}
		else
			res ~= c;
	return res;
}

mixin template styleProperty(string type, string name)
{
	mixin(type ~ " _" ~ name ~ ";");
	mixin("bool _" ~ name ~ "IsSet;");
	mixin("void clear" ~ toUpper(name[0..1]) ~ name[1..$] ~ "() pure nothrow { _" ~ name ~ "IsSet = false; }");
	mixin("@property " ~ type ~ " " ~ name ~ "() { " ~ 
		  " if ( _" ~ name ~ "IsSet) return _" ~ name ~ ";" ~
		  " else { " ~ type ~ " t; style.getProperty(\"" ~ cssifyName(name) ~ "\", t); return t; } }");
	mixin("@property void " ~ name ~ "(" ~ type ~ " value) { _" ~ name ~ " = value; _" ~ name ~ "IsSet = true; }");
}

struct StyleFields
{
	Rectf[PropertyID] rects;  // Keys in the map are property names
	float[PropertyID] floats;
	Vec2f[PropertyID] vec2fs;

	Transition[PropertyID] transitions; // as opposed to the above maps the key here is the name of the property to be transitioned

	Style.Position _position;
	RectCSSOffset _edgesOffset;

	// ref types
	Font _font;
	Material _background;

	// value types
	bool _wordWrap;  // bit 0
	Color _color;    // bit 1
	Color _backgroundColor;    // bit 2

	RectfOffset _padding;  
	RectfOffset _backgroundSpriteBorder;
	Rectf       _backgroundSprite;

	// float _glyphPadding; etc....

	// bitmask. One bit set unset for each by value property that does not support null values should be null. 
	// The fields are:
	// * wordWrap bit 0
	// * color bit 1
	ubyte _nullFields;

	// Copy all fields of this into sf where sf hasn't set the field 
	// and return the result.
	/*
	StyleFields overlayUnset(StyleFields sf)
	{
	if (sf._font is null)
	sf._font = _font;
	if (sf._background is null)
	sf._background = _background;
	if (isNaN(sf._color.r))
	sf._color = _color;
	if (!(sf._derived & 1))
	sf._wordWrap = _wordWrap;
	if (sf._padding.x.isNaN())
	sf._padding.x = _padding.x; 
	if (sf._padding.y.isNaN())
	sf._padding.y = _padding.y; 
	if (sf._padding.w.isNaN())
	sf._padding.w = _padding.w; 
	if (sf._padding.h.isNaN())
	sf._padding.h = _padding.h; 
	return sf;
	}
	*/
	private void setInvalid(float src, ref float dst)
	{
		if (dst.isNaN())
			dst = src;
	}

	private void setInvalid(CSSScale src, ref CSSScale dst)
	{
		if (dst.value.isNaN())
		{
			dst.value = src.value;
			dst.unit = src.unit;
		}
	}

	private void setInvalid(RectCSSOffset src, ref RectCSSOffset dst)
	{
		setInvalid(src.left, dst.left);
		setInvalid(src.top, dst.top);
		setInvalid(src.right, dst.right);
		setInvalid(src.bottom, dst.bottom);
	}

	private void setInvalid(RectfOffset src, ref RectfOffset dst)
	{
		setInvalid(src.left, dst.left);
		setInvalid(src.top, dst.top);
		setInvalid(src.right, dst.right);
		setInvalid(src.bottom, dst.bottom);
	}

	private void setInvalid(Rectf src, ref Rectf dst)
	{
		setInvalid(src.x, dst.x);
		setInvalid(src.y, dst.y);
		setInvalid(src.w, dst.w);
		setInvalid(src.h, dst.h);
	}

	// Copy all fields of sf to this where this hasn't got
	// a value itself yet.
	void overlay(StyleFields sf)
	{
		if (_font is null)
			_font = sf._font;

		if (sf._background !is null)
		{
			if (_background is null)
				_background = sf._background; // TODO: hmmm. could this make _background be modified later because of a second overlay?
			else 
			{
				if (_background.shader is null)
					_background.shader = sf._background.shader;
				if (_background.texture is null)
					_background.texture = sf._background.texture;
			}
		}

		if (!(_nullFields & 1) && (sf._nullFields & 1))
		{
			_wordWrap = sf._wordWrap;
			_nullFields |= 1;
		}

		if (!(_nullFields & 2) && (sf._nullFields & 2) )
		{
			_color = sf._color;
			_nullFields |= 2;
		}

		if (! (_nullFields & 4) && (sf._nullFields & 4) )
		{
			_backgroundColor = sf._backgroundColor;
			_nullFields |= 4;
		}

		setInvalid(sf._padding, _padding);
		setInvalid(sf._backgroundSpriteBorder, _backgroundSpriteBorder);
		setInvalid(sf._backgroundSprite, _backgroundSprite);
		setInvalid(sf._edgesOffset, _edgesOffset);

		if (_position == Style.Position.invalid)
			_position = sf._position;

		foreach (key, value; sf.floats)
			PropertySpecification!float.overlay(floats, key, value);

		foreach (key, value; sf.rects)
			PropertySpecification!Rectf.overlay(rects, key, value);

		foreach (key, value; sf.vec2fs)
			PropertySpecification!Vec2f.overlay(vec2fs, key, value);
	}
}

class Style
{
	StyleSheet styleSheet; // StyleSheet owning this style

	enum Position : byte
	{
		invalid,
		static_,
		fixed,
		relative,
		absolute
	}

	StyleFields _fields; // Fields set on this style

	@property 
	{	
		Position position() const
		{
			return _fields._position;
		}

		void position(Position p)
		{
			_fields._position = p;
		}

		RectCSSOffset edgesOffset() const
		{
			return _fields._edgesOffset;
		}

		void edgesOffset(RectCSSOffset offset)
		{
			_fields._edgesOffset = offset;
		}

		CSSScale left() const
		{
			return _fields._edgesOffset.left;
		}

		CSSScale top() const
		{
			return _fields._edgesOffset.top;
		}

		CSSScale right() const
		{
			return _fields._edgesOffset.right;
		}

		CSSScale bottom() const
		{
			return _fields._edgesOffset.bottom;
		}

		Font font()
		{
			auto f = _fields._font;
			if (f !is null)
				f.ensureLoaded();
			return f;
		}

		void font(Font f) 
		{
			_fields._font = f;
		}

		Material background()
		{
			auto b = _fields._background;
			if (b !is null)
				b.ensureLoaded();
			return b;
		}

		void background(Material b)
		{
			_fields._background = b;
		}

		Color color() const
		{
			return _fields._color;
		}

		void color(Color c)
		{
			_fields._nullFields |= 2;
			_fields._color = c;
		}

		Color backgroundColor() const
		{
			return _fields._backgroundColor;
		}

		void backgroundColor(Color c)
		{
			_fields._nullFields |= 4;
			_fields._backgroundColor = c;
		}

		bool wordWrap() const
		{
			return _fields._wordWrap;
		}

		void wordWrap(bool w)
		{
			_fields._nullFields |= 1;
			_fields._wordWrap = w;
		}

		RectfOffset padding() const
		{
			return _fields._padding;
		}

		// TODO: make a paddingX, paddingY etc. methods
		void padding(RectfOffset w)
		{
			_fields._padding = w;
		}

		RectfOffset backgroundSpriteBorder() const
		{
			return _fields._backgroundSpriteBorder;
		}

		void backgroundSpriteBorder(RectfOffset w)
		{
			_fields._backgroundSpriteBorder = w;
		}

		Rectf backgroundSprite() 
		{
			Rectf r = _fields._backgroundSprite;
			Vec2f sz;
			if (background !is null && background.texture !is null)
				sz = background.texture.size;
			else
				sz = Vec2f(0,0);

			if (r.x.isNaN())
				r.x = 0; // default to 0 offset

			if (r.y.isNaN())
				r.y = 0; // default to 0 offset

			if (r.w.isNaN())
				r.w = sz.x; 

			if (r.h.isNaN())
				r.h = sz.y; 

			return r;
		}

		void backgroundSprite(Rectf w)
		{
			_fields._backgroundSprite = w;
		}

		string name() const
		{
			return _name;
		}
	}

	string _name;

	this(string name)
	{
		this._name = name;	
	}

	this(StyleSheet s)
	{
		styleSheet = s;
	}

	bool getProperty(PropertyID id, ref float value) const pure nothrow
	{
		auto v = id in _fields.floats;
		if (v is null)
			return false;
		value = *v;
		return true;
	}

	bool getProperty(PropertyID id, ref Vec2f value) const pure nothrow
	{
		auto v = id in _fields.vec2fs;
		if (v is null)
			return false;
		value = *v;
		return true;
	}

	//bool getPropertyDef(PropertyID id, ref float value) const pure nothrow
	//{
	//    auto v = id in _fields.floats;
	//    if (v is null)
	//        return styleSheet.manager
	//    value = *v;
	//    return true;
	//}

	bool getProperty(PropertyID id, ref Rectf value) 
	{
		auto v = id in _fields.rects;
		if (v is null)
			return false;
		value = *v;
		return true;
	}

	// Reset to init state ie. having all fields "null" values
	void clear()
	{
		_fields._position = Position.invalid;
		_fields._edgesOffset = RectCSSOffset.init;
		_fields._font = null;
		_fields._background = null;
		_fields._nullFields = 0;
		_fields._padding = RectfOffset.init;
		_fields._backgroundSpriteBorder = RectfOffset.init;
		_fields._backgroundSprite = Rectf.init;

		foreach (ref v; _fields.floats)
			v = float.init;

		foreach (ref v; _fields.rects)
			v = Rectf.init;

		foreach (ref v; _fields.vec2fs)
			v = Vec2f.init;
	}

	// reset in the same state as s
	void reset(Style s)
	{
		_fields._position = s._fields._position;
		_fields._edgesOffset = s._fields._edgesOffset;
		_fields._font = s._fields._font;
		_fields._background = s._fields._background;
		_fields._color = s._fields._color;
		_fields._backgroundColor = s._fields._backgroundColor;
		_fields._wordWrap = s._fields._wordWrap;
		_fields._nullFields = s._fields._nullFields;
		_fields._padding = s._fields._padding;
		_fields._backgroundSpriteBorder = s._fields._backgroundSpriteBorder;
		_fields._backgroundSprite = s._fields._backgroundSprite;

		foreach (key, ref v; _fields.floats)
			v = s._fields.floats[key];

		foreach (key, ref v; _fields.rects)
			v = s._fields.rects[key];

		foreach (key, ref v; _fields.vec2fs)
			v = s._fields.vec2fs[key];
	}

	// Merge s into this but only set fields that are not null set on s
	void overlay(Style s)
	{
		// _fields = s._fields.overlay(_fields);
		_fields.overlay(s._fields);
	}
}

// Example sheet:
//
// color = white;
//
// * {
// font: "resources/fonts/cour.ttf" 16;
// padding: 2 2 2 2;
//  color: $color;
//     background-shader: "default.shaderprogram";
// }
// 
// TextEditor[lars] > [ib] {
// color: yellow;
// background: "bgplain.png;
// }


version (unittest)
{
	import std.typecons;
	import graphics.rendertarget;
	import gui.window;
	import gui.widget;
	import test;

	Window createTestWindow()
	{
		return new Window("testWindow", 100, 200, new BlackHole!RenderTarget());
	}
}
