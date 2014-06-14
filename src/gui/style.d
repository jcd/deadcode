module gui.style;

import core.uri;

import math._;

import graphics.color : Color;

import gui.gui;
import gui.locations;
import gui.resource;
import gui.resources.material;
import gui.resources.font : Font, FontManager;

import animation.mutator;

import io.iomanager;

import std.algorithm;
import std.exception;
import std.conv;
import std.file;
import std.math;
import std.path;
import std.range;
import std.string;


version (unittest) import test;

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
	abstract void parse(StyleSheetParser parser, Style style);
}

abstract class PropertySpecificationBase(T) : IPropertySpecification
{
	private
	{
		PropertyID _id;
		T _default;
		bool _inherited;
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
	}

	this(PropertyID _id, T _default, bool _inherited)
	{
		this._id = _id;
		this._default = _default;
		this._inherited = _inherited;
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

	void parse(StyleSheetParser parser, Style style)
	{
		style._fields.floats[id] = parser.curToken == "-" ? float.nan : parser.curToken.to!float();
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

	void parse(StyleSheetParser parser, Style style)
	{
		Vec2f r;
		r.x = parser.curToken == "-" ? float.nan : parser.curToken.to!float();
		parser.requireNextToken();
		r.y = parser.curToken == "-" ? float.nan : parser.curToken.to!float();
		style._fields.vec2fs[id] = r;
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

	void parse(StyleSheetParser parser, Style style)
	{
		Rectf r;
		r.x = parser.curToken == "-" ? float.nan : parser.curToken.to!float();
		parser.requireNextToken();
		r.y = parser.curToken == "-" ? float.nan : parser.curToken.to!float();
		parser.requireNextToken();
		r.w = parser.curToken == "-" ? float.nan : parser.curToken.to!float();
		parser.requireNextToken();
		r.h = parser.curToken == "-" ? float.nan : parser.curToken.to!float();
		style._fields.rects[id] = r;
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

struct StyleFields
{
	
	Rectf[PropertyID] rects;
	float[PropertyID] floats;
	Vec2f[PropertyID] vec2fs;

	Style.Position _position;
	RectfOffset _positionOffset;

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
		setInvalid(sf._positionOffset, _positionOffset);

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

	private StyleFields _fields; // Fields set on this style

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

		RectfOffset positionOffset() const
		{
			return _fields._positionOffset;
		}

		void positionOffset(RectfOffset offset)
		{
			_fields._positionOffset = offset;
		}

		float left() const
		{
			return _fields._positionOffset.left;
		}

		float top() const
		{
			return _fields._positionOffset.top;
		}

		float right() const
		{
			return _fields._positionOffset.right;
		}

		float bottom() const
		{
			return _fields._positionOffset.bottom;
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
		_fields._positionOffset = RectfOffset.init;
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
		_fields._positionOffset = s._fields._positionOffset;
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

import gui.widget;

class WidgetSelector
{
	string widgetTypeName;
	bool fullyQualifiedType;
	string widgetName;
	string className;
	
	enum PseudoClass : byte
	{
		none,
		hover,
		active,
		disabled,
		focus
	}

	PseudoClass pseudoClass;

	this(string wtype, string wname, string cname = null, string pseudoName = null)
	{
		widgetTypeName = wtype == "*" ? null : wtype;
		fullyQualifiedType = false;
		widgetName = wname;
		className = cname;
		switch (pseudoName)
		{
			case "hover":
				pseudoClass = PseudoClass.hover;
				break;
			case "active":
				pseudoClass = PseudoClass.active;
				break;
			case "disabled":
				pseudoClass = PseudoClass.disabled;
				break;
			case "focus":
				pseudoClass = PseudoClass.focus;
				break;
			default:
				pseudoClass = PseudoClass.none;
				break;
		}
	}

	Widget match(Widget w, string[] classNames)
	{
		auto nameMatch = widgetName.empty ? true : widgetName == w.name;
		auto typeMatch = widgetTypeName.empty;
		auto classMatch = className.empty ? true : classNames.canFind(className);
		auto pseudoMatch = true;
		
		final switch (pseudoClass)
		{
			case PseudoClass.none:
				break;
			case PseudoClass.hover:
				pseudoMatch = w.isMouseOver();
				break;
			case PseudoClass.active:
				pseudoMatch = w.isMouseDown();
				break;
			case PseudoClass.disabled:
				break;
			case PseudoClass.focus:
				break;
		}

		if (!(nameMatch && classMatch && pseudoMatch))
			return null;

		if (!typeMatch)
		{
			auto ci = w.classinfo;
			// Match class with widgetTypeName or descendants
			while (ci !is null && !matchName(ci))
				ci = ci.base;
			typeMatch = ci !is null;
		}
		return typeMatch ? w : null;
	}
	
	private bool matchName(TypeInfo_Class ci)
	{
		import std.string;
		string ciname = ci.name;
		if (!fullyQualifiedType)
		{
			auto idx = ciname.lastIndexOf('.');
			if (idx != -1)
				ciname = ciname[idx+1..$];
		}
		return ciname == widgetTypeName;
	}

}

unittest
{
	auto testWin = createTestWindow();

	// Wildcard match
	auto w1 = new Widget(testWin);
	auto sel1 = new WidgetSelector(null, null);
	AssertIs(sel1.match(w1, null), w1, "Wildcard WidgetSelector matches unnamed");
	w1.name = "testWidget";
	AssertIs(sel1.match(w1, null), w1, "Wildcard WidgetSelector matches named");

	// Name match
	auto w2 = new Widget(testWin);
	auto sel2 = new WidgetSelector(null, "testWidget");
	AssertIsNot(sel2.match(w2, null), w2, "TypeWildcard WidgetSelector does not match unnamed");
	w2.name = "testWidgetxx";
	AssertIsNot(sel2.match(w2, null), w2, "TypeWildcard WidgetSelector does not match mismatching name");
	w2.name = "testWidget";
	AssertIs(sel2.match(w2, null), w2, "TypeWildcard WidgetSelector matches name");

	// Type match
	auto w3 = new Widget(testWin);
	auto sel3 = new WidgetSelector("Widget",null);
	AssertIs(sel3.match(w3, null), w3, "NameWildcard WidgetSelector matches direct Widget");
	auto sel4 = new WidgetSelector("WidgetX",null);
	AssertIsNot(sel4.match(w3, null), w3, "NameWildcard WidgetSelector does not match direct WidgetX");

	class TestWidget1 : Widget { this(Widget w) { super(w); } }
	class TestWidget2 : TestWidget1 { this(Widget w) { super(w); } }

	auto w4 = new TestWidget2(testWin);
	auto sel5 = new WidgetSelector("Widget",null);
	AssertIs(sel5.match(w4, null), w4, "NameWildcard WidgetSelector matches decendant of Widget");
	auto sel6 = new WidgetSelector("TestWidget1",null);
	AssertIs(sel6.match(w4, null), w4, "NameWildcard WidgetSelector matches decendant of TestWidget1");
	auto sel7 = new WidgetSelector("TestWidget2",null);
	AssertIs(sel7.match(w4, null), w4, "NameWildcard WidgetSelector matches direct TestWidget2");
}

class ChildSelector : WidgetSelector
{
	this(string tname, string wname, string cname = null, string pseudoName = null)
	{
		super(tname, wname, cname, pseudoName);
	}

	override Widget match(Widget w, string[] classNames)
	{
		auto p = w.parent;
		if (p is null || super.match(p, classNames) is null)
			return null;

		return p;
	}
}

unittest
{
	auto win = createTestWindow();
	auto w1 = new Widget(win);
	w1.name = "testParent";
	auto w2 = new Widget(w1);
	w2.name = "testChild";
	auto w3 = new Widget(w2);
	w3.name = "testGrandChild";

	auto sel = new ChildSelector(null,"testParent");
	AssertIsNot(sel.match(w1, null), win, "Root widget does not match ChildSelector");
	AssertIs(sel.match(w2, null), w1, "Child of root widget matches ChildSelector");
	AssertIsNot(sel.match(w3, null), w2, "Grandchild of root widget does not match ChildSelector");
}

class DescendantSelector : WidgetSelector
{
	this(string tname, string wname, string cname = null, string pseudoName = null)
	{
		super(tname, wname, cname, pseudoName);
	}

	override Widget match(Widget w, string[] classNames)
	{
		auto p = w.parent;
		while (p !is null)
		{
			Widget res = super.match(p, classNames);
			if (res is null)
				p = p.parent;
			else
				return res;
		}
		return null;
	}
}

unittest
{
	auto win = createTestWindow();
	auto w1 = new Widget(win);
	w1.name = "testParent";
	auto w2 = new Widget(w1);
	w2.name = "testChild";
	auto w3 = new Widget(w2);
	w3.name = "testGrandChild";

	auto sel = new DescendantSelector(null,"testParent");
	AssertIsNot(sel.match(w1, null), win, "Root widget does not match DescendantSelector");
	AssertIs(sel.match(w2, null), w1, "Child of root widget matches DescendantSelector");
	AssertIs(sel.match(w3, null), w1, "Grandchild of root widget matches DescendantSelector");
}

/*
class SiblingSelectorOperator: SelectorOperator
{

}
*/

class Rule
{
	//
	// widgetSelector1 operator1 widgetSelector2 operator2 widgetSelector3
	// ie. 
	// operator.length == widgetSelectors.lenght - 1
	//
	WidgetSelector[] widgetSelectors;
	Style style;
	
	// 
	// http://www.w3.org/TR/CSS21/cascade.html#specificity
	// 0xFF_00_00_00 mask is the count of named selectors
	// 0x00_FF_00_00 mask is the sum of psuedo class selectors, class selectors and attribute selectors
	// 0x00_00_FF_00 mask is the sum of widget and subwidget selectors
	//
	uint specificity;

	bool match(Widget w, string[] classNames)
	{
		if (specificity == 0)
			calculateSpecificity();

		if (widgetSelectors.empty)
			return true;

		for (int i = widgetSelectors.length - 1; w !is null && i >= 0; i--)
			w = widgetSelectors[i].match(w, classNames);
		
		return w !is null;
	}

	void calculateSpecificity()
	{
		foreach (s;	widgetSelectors)
		{
			if (s.widgetName !is null)
				specificity += 0x01_00_00_00;
			if (s.className !is null)
				specificity += 0x00_01_00_00;
			if (s.pseudoClass != WidgetSelector.PseudoClass.none)
				specificity += 0x00_01_00_00;
			if (s.widgetTypeName !is null)
				specificity += 0x00_00_01_00;
		}
	}
}

unittest
{
	auto testWin = createTestWindow();
	auto sel1 = new Rule;
	sel1.widgetSelectors ~= new WidgetSelector("Widget", null);
	auto w1 = new Widget(testWin);
	w1.name = "testParent";
	auto w2 = new Widget(w1);
	w2.name = "testChild";

	Assert(sel1.match(w1, null), "Wildcard selector matches single");

	WidgetSelector[] ws = [new ChildSelector(null, "testParent")];
	sel1.widgetSelectors =  ws ~ sel1.widgetSelectors;
	Assert(!sel1.match(w1, null), "Child selector on parent does not match");
	Assert(sel1.match(w2, null), "Child selector on child does not match");
}

class StyleSheet : Resource!StyleSheet
{
	private 
	{
		//FontManager _fontManager;  // TODO: No need for managers I think. Let the ones why create styles know about that
		//MaterialManager _materialManager;
	}

	Rule[] rules;
	
	alias immutable(size_t)[] RuleSetID;
	Style[RuleSetID] styleCache;

	void clear()
	{
		rules.length = 0;
		styleCache = null;
	}

	void clearCache()
	{
	}

	void swap(StyleSheet other)
	{
		Rule[] r = rules;
		Style[RuleSetID] sc = styleCache;
		rules = other.rules;
		styleCache = other.styleCache;
		other.rules = r;
		other.styleCache = sc;
	}

	Style getStyleForWidget(Widget w, string[] classNames = null)
	{
		// Get matching selectors
		struct Match
		{
			Rule rule;
			int order; // order in sheet for conflict resolution on selectors with same specificity
		}

		Match[] matches;
		RuleSetID matchedRules;
		foreach (i, s; rules)
		{
			if (s.match(w, classNames))
			{
				matches ~= Match(s, i);
				matchedRules ~= s.toHash();
			}
		}

		//if (classNames.length != 0 && classNames[0] == "commandEntryField" )
		//if (w.name == "commandEntryField" || w.name == "command")
		//{
		//    string wname = w.name;
		//    int a = 3;
		//}

		if (matches.empty) 
			return null;
		
		if (matches.length == 1)
			return matches[0].rule.style;

		// Get cached or create style for this selector set (cascading)
		Style* cachedStyle = matchedRules in styleCache;
		if (cachedStyle)
		    return *cachedStyle;

		//std.stdio.writeln("hashes ", w.name, " ", matchedRules);

		// Resolve conflicts if any
		import std.algorithm;
		auto rng = matches.sort!((a,b) => a.rule.specificity > b.rule.specificity || (a.rule.specificity == b.rule.specificity && a.order >	b.order))();
		
		Style st = new Style(this); // createStyle(matching[0].style);
		// TODO: prime background material to make it unique
		StyleSheetManager mgr = cast(StyleSheetManager)manager;
		version(dunittest) {}
		else 
		{
			st.background = mgr.materialManager.declare(CustomMaterialLoader.singleton);
		}

		styleCache[matchedRules] = st;

		uint lastSpecificity = uint.max;
		foreach (m; rng)
		{
			if (lastSpecificity != m.rule.specificity)
			{
				st.overlay(m.rule.style);
				lastSpecificity = m.rule.specificity;
			}
		}

		return st;
	}

	Style createStyle(Style from)
	{
		auto st = new Style(this);
		st._fields = from._fields;
		return st;
	}

}

unittest
{
	auto win = createTestWindow();
	auto w1 = new Widget(win);
	w1.name = "testParent";
	auto w2 = new Widget(w1);
	w2.name = "testChild";
	auto w3 = new Widget(w2);
	w3.name = "testGrandChild";

	auto sheet = new StyleSheet;

	// WidgetSelector
	Rule sel1 = new Rule;
	sel1.widgetSelectors ~= new WidgetSelector("Widget", null);
	sel1.style = new Style(sheet);
	sel1.style.color = Color.red;
	// sel1.style.compute();		
	sheet.rules ~= sel1;

	Assert(sheet.getStyleForWidget(w1).color, Color.red, "Selector(Widget) w1 has color red");
	Assert(sheet.getStyleForWidget(w2).color, Color.red, "Selector(Widget) w2 has color red");
	Assert(sheet.getStyleForWidget(w3).color, Color.red, "Selector(Widget) w2 has color red");
	
	// ChildSelector
	Rule sel2 = new Rule;
	sel2.widgetSelectors ~= new ChildSelector(null,"testParent");
	sel2.style = new Style(sheet);
	sel2.style.color = Color.green;
	//sel2.style.compute();
	sheet.rules ~= sel2;

	Assert(sheet.getStyleForWidget(w1).color, Color.red, "Selector(#testParent Widget) w1 has color red");
	Assert(sheet.getStyleForWidget(w2).color, Color.green, "Selector(#testParent Widget) w2 has color green");
	Assert(sheet.getStyleForWidget(w3).color, Color.red, "Selector(#testParent Widget) w3 has color red");

	// DescendantSelector
	Rule sel3 = new Rule;
	sel3.widgetSelectors ~= new DescendantSelector(null,"testParent");
	sel3.style = new Style(sheet);
	sel3.style.color = Color.blue;
	//sel3.style.compute();
	sheet.rules ~= sel3;

	Assert(sheet.getStyleForWidget(w1).color, Color.red, "Selector(#testParent Widget) w1 has color red");
	Assert(sheet.getStyleForWidget(w2).color, Color.blue, "Selector(#testParent Widget) w2 has color blue");
	Assert(sheet.getStyleForWidget(w3).color, Color.blue, "Selector(#testParent Widget) w3 has color blue");
}

class StyleSheetManager : ResourceManager!StyleSheet
{
	private 
	{
		FontManager _fontManager;  // TODO: No need for managers I think. Let the ones why create styles know about that
		MaterialManager _materialManager;
		IPropertySpecification[PropertyID] _propertySpecifications;
		Handle builtinStyleSheetHandle;
	}

	@property 
	{

		FontManager fontManager()
		{
			return _fontManager;
		}

		MaterialManager materialManager()
		{
			return _materialManager;
		}

	}

	static StyleSheetManager create(IOManager ioManager, MaterialManager mm, FontManager fm)
	{
		import gui.resources;
		auto ssm = new StyleSheetManager;
		ssm._materialManager = mm;
		ssm._fontManager = fm;
		ssm.ioManager = ioManager;
		ssm.addSerializer(new StyleSheetSerializer(mm, fm));

		ssm.createBuiltinStyleSheet(mm, fm);
		
		ssm.addPropertySpecification!float("expand-duration", 0.10);
		ssm.addPropertySpecification!Vec2f("offset", Vec2f(0,0));

		return ssm;
	}

	private void createBuiltinStyleSheet(MaterialManager mm, FontManager fm)
	{
		StyleSheet ss = declare(new URI("builtin:default"));
		builtinStyleSheetHandle = ss.handle;

		Rule sel = new Rule;
		ss.rules ~= sel;

		Style lbase = new Style(ss); // ss.createStyle("builtin");
		lbase.font = fm.builtinFont;
		lbase.background = mm.builtinMaterial;
		lbase.color = Color.red;
		lbase.backgroundColor = Color.white;
		lbase.padding = RectfOffset(0, 0, 0, 0);
		lbase.backgroundSpriteBorder = RectfOffset(0, 0, 0, 0);
		lbase.backgroundSprite = Rectf.init;

		sel.style = lbase;
		sel.widgetSelectors ~= new WidgetSelector(null, null); // select all
		
		onResourceLoaded(ss, null);
	}

	void addPropertySpecification(IPropertySpecification spec)
	{
		_propertySpecifications[spec.id] = spec;
	}

	void addPropertySpecification(T)(PropertyID pid, T _default, bool inherited = false)
	{
		_propertySpecifications[pid] = new PropertySpecification!T(pid, _default, inherited);
	}

	IPropertySpecification lookupPropertySpecification(PropertyID pid)
	{
		auto ps = pid in _propertySpecifications;
		if (ps is null) return null;
		return *ps;
	}
}

class CustomMaterialLoader : IResourceLoader!Material
{
	static CustomMaterialLoader _the;
	static @property singleton()
	{
		if (_the is null)
		{
			_the = new CustomMaterialLoader;
		}
		return _the;
	}

	bool load(Material r, URI uri)
	{
		// TODO: Remove since tex and shader are lazy loaded as well
		//gui.resources.Texture tex = cast(gui.resources.Texture) r.texture;
		//if (tex !is null)
		//    tex.ensureLoaded();
		//
		//gui.resources.ShaderProgram sp = cast(gui.resources.ShaderProgram) r.shader;
		//if (sp !is null)
		//    sp.ensureLoaded();

		// There is no. Just make a callback to the manager that all is ok
		r.manager.onResourceLoaded(r, null);
		return true;
	}

	bool save(Material p, URI uri)
	{
		throw new Exception("Cannot save materials");
	}

}

class CustomFontLoader : IResourceLoader!Font
{
	static CustomFontLoader _the;
	static @property singleton()
	{
		if (_the is null)
		{
			_the = new CustomFontLoader;
		}
		return _the;
	}

	bool load(Font r, URI uri)
	{
		r.init();
		r.manager.onResourceLoaded(r, null);
		return true;
	}

	bool save(Font p, URI uri)
	{
		throw new Exception("Cannot save fonts");
	}
}

class StyleSheetParser
{
	import std.string;

	struct Error
	{
		int line;
		int column;
		string message;
	}

	alias Error[] Errors;
	Errors errors;

	int line = 1;
	string spaceChars = " \t\n\r";
	string nonSpaceChars = "^ \t\n\r";
	string tokenChars = "^ \t\n\r{}):;#\"'";
	
	string txt;
	string curToken;
	StyleSheet sheet;
	URI baseURI;
	FontManager fontManager;
	MaterialManager materialManager;
	
	@property bool hasErrors() const
	{
		return !errors.empty;
	}

	void addError(string msg, int line = -1, int col = -1)
	{
		errors ~= Error(line, col, msg);
	}

	this(string txt, StyleSheet sheet, URI baseURI, FontManager fontManager, MaterialManager materialManager)
	{
		this.txt = txt;
		this.sheet = sheet;
		this.baseURI = baseURI;
		this.fontManager = fontManager;
		this.materialManager = materialManager;
	}

	
	string nextToken(bool trimPrefixSpaces = true)
	{
		import std.algorithm;
		auto space = munch(txt, spaceChars);
		line += space.count('\n');
		//if (!txt.empty && (txt[0] == '}' || txt[0] == '{' || txt[0] == ';' || txt[0] == ':' || txt[0] == '#' || txt[0] == '\'' || txt[0] == '"' || txt[0] == ')'))
		if (!txt.empty && tokenChars.canFind(txt[0]))
		{
			curToken = txt[0..1];
			txt = txt[1..$];
		}
		else
		{
			curToken = munch(txt, tokenChars);
		}
		return curToken;
	}

	string requireNextToken(bool trimPrefixSpaces = true)
	{
		auto lastToken = curToken;
		if (nextToken(trimPrefixSpaces).empty)
		{
			addError("Incomplete style rule following " ~ lastToken ~ "'", line);
			throw new Exception("Premature end of file");
		}
		return curToken;
	}

	string parseOptionalQuotedString()
	{
		auto result = curToken;
		if (curToken.canFind("\"'"))
		{
			auto startQuoteChar = curToken;
			result = requireNextToken();
			if (requireNextToken() != startQuoteChar)
			{
				addError("Start quote char is not the same as end quote char after '" ~ result ~ "'", line);
				throw new Exception("Quote error");
			}
		}
		return result;
	}

	void parseFontPropertyValue(Style style)
	{
		string theStr = parseOptionalQuotedString();
		if (fontManager is null)
			return;

		if (theStr.extension == ".font")
		{
			// Let material manager handle this for us
			auto theURI = new URI(theStr);
			if (!theURI.isAbsolute)
				theURI.makeAbsolute(baseURI);

			style.font = fontManager.declare(theURI);
			requireNextToken();
		}
		else
		{
			// Create a custom font and use a dummy loader for that
			if (style._fields._font is null)
				style.font = fontManager.declare(CustomFontLoader.singleton);

			while (theStr != ";" && theStr != "}")
			{
				if (theStr.extension == ".ttf")
				{
					auto theURI = new URI(theStr);
					if (!theURI.isAbsolute)
						theURI.makeAbsolute(baseURI);
					style._fields._font.path = theURI.toString(); // TODO: make into URI instead?
				}
				else 
				{
					import std.format;
					int v;
					if (formattedRead(theStr, "%s", &v) == 0)
					{
						addError("Cannot parse font size", line);
						while (curToken != ";" && curToken != "}" && !curToken.empty)
							requireNextToken();
						return;
					}
					
					style._fields._font.size = v;
				}
		
				requireNextToken();	
				theStr = parseOptionalQuotedString();			
			}
		}
	}

	void parseBackgroundPropertyValue(Style style)
	{
		string theURIStr = parseOptionalQuotedString();
		if (materialManager is null)
			return;
	
		auto theURI = new URI(theURIStr);
		if (!theURI.isAbsolute)
			theURI.makeAbsolute(baseURI);

		if (theURI.extension == ".material")
		{
			// Let material manager handle this for us
			style.background = materialManager.declare(theURI);
			requireNextToken();
		}
		else 
		{
			// Create a custom material and use a dummy loader for that
			if (style._fields._background is null)
				style.background = materialManager.declare(CustomMaterialLoader.singleton);			
			
			while (theURIStr != ";" && theURIStr != "}")
			{

				if (theURI.extension == ".png")
					style._fields._background.texture = materialManager.textureManager.declare(theURI);
				else if (theURI.extension == ".shaderprogram")
					style._fields._background.shader = materialManager.shaderProgramManager.declare(theURI);
				else
				{
					addError("Unsupported file extension for background style " ~ theURI.extension, line);
				}
				requireNextToken();
				theURIStr = parseOptionalQuotedString();
				if (theURIStr == ";" || theURIStr == "}")
					break;
				
				theURI = new URI(theURIStr);
				if (!theURI.isAbsolute)
					theURI.makeAbsolute(baseURI);
			}
		}
	}

	void parseColorPropertyValue(ref Color color)
	{
		string c;
		// get all txt until ';'
		while (curToken != ";" && curToken != "}" && !curToken.empty)
		{
			c ~= curToken; 
			requireNextToken();
		}
		
		if (curToken.empty)
			addError("Invalid color string field", line);
		
		auto col = Color.fromCSSString(c);
		if (col[1])
		{
			color = col[0];
		}
		else
		{
			addError("Invalid color string format", line);
		}
	}

	void parseWordWrapPropertyValue(Style style)
	{
		style.wordWrap = curToken == "true";
	}
	
	void parseRectPropertyValue(ref Rectf r)
	{
		r.x = curToken == "-" ? float.nan : curToken.to!float();
		requireNextToken();
		r.y = curToken == "-" ? float.nan : curToken.to!float();
		requireNextToken();
		r.w = curToken == "-" ? float.nan : curToken.to!float();
		requireNextToken();
		r.h = curToken == "-" ? float.nan : curToken.to!float();
	}

	void parseRectOffsetPropertyValue(ref RectfOffset r)
	{
		r.left = curToken == "-" ? float.nan : curToken.to!float();
		requireNextToken();
		r.top = curToken == "-" ? float.nan : curToken.to!float();
		requireNextToken();
		r.right = curToken == "-" ? float.nan : curToken.to!float();
		requireNextToken();
		r.bottom = curToken == "-" ? float.nan : curToken.to!float();
	}

	void parsePositionPropertyValue(Style style)
	{
		switch (curToken)
		{
		case "static":
			style.position = Style.Position.static_;
			break;	
		case "fixed":
			style.position = Style.Position.fixed;
			break;	
		case "relative":
			style.position = Style.Position.relative;
			break;	
		case "absolute":
			style.position = Style.Position.absolute;
			break;	
		default:
			style.position = Style.Position.invalid;
			addError(text("Unknown position value '", curToken, "'"), line);
			break;
		}
	}

	// Parse into val and return true if curToken is consumed. 
	// E.g in case a search for unit specifier 'em' fails the curToken is not consumed
	bool parseUnitValue(ref float val)
	{
		string tok = curToken;
		bool consumed = false;
		switch (requireNextToken())
		{
			case "%":
				consumed = true;
				break;
			case "in":
				consumed = true;
				break;
			case "cm":
				consumed = true;
				break;
			case "mm":
				consumed = true;
				break;
			case "em":
				consumed = true;
				break;
			case "ex":
				consumed = true;
				break;
			case "pc":
				consumed = true;
				break;
			case "pt":
				consumed = true;
				break;
			case "px":
				goto default;
			default:
				consumed = true;
				break;
		}
		return consumed;
	}

	bool parsePositionOffsetPropertyValue(Style style, ref float val)
	{
		return parseUnitValue(val);
	}

	void parseProperties(Rule rule)
	{
		while (true)
		{
			if (curToken == ";")
				requireNextToken();

			if (curToken == "}")
				return;

			string key = curToken;
			if (requireNextToken() != ":")
			{
				addError("Expected ':' after style key '" ~ key ~ "'", line);
				while (curToken != ";" && curToken != "}" && !curToken.empty)
					requireNextToken();				
				continue;
			}

			requireNextToken();

			// TODO:
			// Reload on file change and not focus change since the we can use ded itself to live update sheets!
			// ninegrid padding and sprite size in texture (make ninegrid work for widget backgrounds!)
			// Make widget obey padding
			// When failing to load stylesheet do not exit() or use weird stylesheet. 
			//   Instead do not clear stylesheet on reload before it is successfully loaded and then replace
			// Do not throw in parser if possible. Just log.
			// Support for multiply stylesheets and cascading them maybe (e.g. for lang syntax specific sheets)
			switch (key)
			{
				case "font":
					parseFontPropertyValue(rule.style);
					continue;
				case "background":
					parseBackgroundPropertyValue(rule.style);
					continue;
				case "color":
					parseColorPropertyValue(rule.style._fields._color);
					rule.style._fields._nullFields |= 2;
					continue;
				case "background-color":
					parseColorPropertyValue(rule.style._fields._backgroundColor);
					rule.style._fields._nullFields |= 4;
					continue;
				case "wordWrap":
					parseWordWrapPropertyValue(rule.style);
					break;
				case "padding":
					parseRectOffsetPropertyValue(rule.style._fields._padding);
					break;
				case "background-sprite":
					parseRectPropertyValue(rule.style._fields._backgroundSprite);
					break;
				case "background-sprite-border":
					parseRectOffsetPropertyValue(rule.style._fields._backgroundSpriteBorder);
					break;
				case "position":
					parsePositionPropertyValue(rule.style);
					break;
				case "left":
					if (!parsePositionOffsetPropertyValue(rule.style, rule.style._fields._positionOffset.left))
						continue;
					break;
				case "top":
					if (!parsePositionOffsetPropertyValue(rule.style, rule.style._fields._positionOffset.top))
						continue;
					break;
				case "right":
					if (!parsePositionOffsetPropertyValue(rule.style, rule.style._fields._positionOffset.right))
						continue;
					break;
				case "bottom":
					if (!parsePositionOffsetPropertyValue(rule.style, rule.style._fields._positionOffset.bottom))
						continue;
					break;
				default:
					auto mgr = sheet.manager;
					auto spec = (cast(StyleSheetManager)mgr).lookupPropertySpecification(key);
					if (spec !is null)
					{
						spec.parse(this, rule.style);
					} 
					else
					{
						addError("Unknown style key '" ~ key ~ "'", line);
						while (curToken != ";" && curToken != "}" && !curToken.empty)
							requireNextToken();				
						continue;
					}
			}

			requireNextToken();
		}
	}

	void parseSelector(Rule rule)
	{
		while (true)
		{
			if (curToken == "{")
			{
				if (rule.widgetSelectors.empty)
				{
					addError("No selector specified for rule", line);
					throw new Exception("Missing selector on rule");
				}
			}
			string widgetTypeName = null;
			string widgetName = null;
			string className = null;
			string pseudoClassName = null;

			string token = curToken ~ munch(txt, nonSpaceChars);
			
			while (token.length)
			{
				// A segment can be either #id or .class or widgetname

				if (token[0] == '#')
				{
					token = token[1..$];
					widgetName = munch(token, "^.#:");
				}
				else if (token[0] == '.')
				{
					token = token[1..$];
					className = munch(token, "^.#:");
				}
				else if (token[0] == ':')
				{
					token = token[1..$];
					pseudoClassName = munch(token, "^.#:");
				}
				else
				{
					auto segment = munch(token, "^.#:");
					if (segment != "*")
						widgetTypeName = segment;
				}
			}

			requireNextToken();
			
			switch (curToken)
			{
				case "{":
					rule.widgetSelectors ~= new WidgetSelector(widgetTypeName, widgetName, className, pseudoClassName);
					return;
				case ">":
					rule.widgetSelectors ~= new ChildSelector(widgetTypeName, widgetName, className, pseudoClassName);
					requireNextToken();
					break;
				default:
					rule.widgetSelectors ~= new DescendantSelector(widgetTypeName, widgetName, className, pseudoClassName);
					break;
			}
		}
	}

	void parseRule()
	{
		Rule rule = new Rule;
		rule.style = new Style(sheet);
		parseSelector(rule);
		requireNextToken(); // skip {
		parseProperties(rule);
		nextToken();
		sheet.rules ~= rule;
	}

	bool parse()
	{
		try 
		{
			nextToken();
			while(!curToken.empty) 
			{
				parseRule();
			}
		}
		catch (Exception e)
		{
			addError(e.msg);
		}
		return !hasErrors;
	}
}

unittest
{
	StyleSheet sheet = new StyleSheet();
	
	auto parse = new StyleSheetParser("", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.empty, "No rules for empty sheet");

	parse = new StyleSheetParser("Widget {}", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 1 && 
		   sheet.rules[0].widgetSelectors.length == 1 &&
		   sheet.rules[0].widgetSelectors[0].widgetTypeName == "Widget", 
		   "Simple selector and no style definitions");

	parse = new StyleSheetParser("Widget { color: #FF0000 }", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 2 && 
		   sheet.rules[1].widgetSelectors.length == 1 &&
		   sheet.rules[1].widgetSelectors[0].widgetTypeName == "Widget" &&
		   sheet.rules[1].style.color == Color.red, 
		   "Simple selector and red color");

	parse = new StyleSheetParser("Widget { color: #FF0000; }", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 3 && 
		   sheet.rules[2].widgetSelectors.length == 1 &&
		   sheet.rules[2].widgetSelectors[0].widgetTypeName == "Widget" &&
		   sheet.rules[2].style.color == Color.red, 
		   "Simple selector and red color semicolor end");

	parse = new StyleSheetParser("Widget { color: #FF0000;\n padding : 1 2 3 4;\n wordWrap: true;\n }", sheet, new URI(""), null, null);
	parse.parse();
	Assert(sheet.rules.length == 4 && 
		   sheet.rules[3].widgetSelectors.length == 1 &&
		   sheet.rules[3].widgetSelectors[0].widgetTypeName == "Widget" &&
		   sheet.rules[3].style.color == Color.red &&
		   sheet.rules[3].style.wordWrap &&
		   sheet.rules[3].style.padding == RectfOffset(1,2,3,4),
		   "Simple selector and red color and rect and wordWrap	");
}

class StyleSheetSerializer : ResourceSerializer!StyleSheet
{
	@property
	{
		public FontManager fontManager()
		{
			return _fontManager;
		}

		public MaterialManager materialManager()
		{
			return _materialManager;
		}
	}

	this(MaterialManager materialManager, FontManager fontManager)
	{
		_materialManager = materialManager;
		_fontManager = fontManager;
	}	

	override bool canRead() pure const nothrow { return true; }

	override bool canHandle(URI uri)
	{
		return uri.extension == ".stylesheet";
	}

	override void deserialize(StyleSheet res, string str)
	{
		URI baseURI = res.uri.dirName;
		scope StyleSheet tmpSheet = new StyleSheet;
		tmpSheet.manager = res.manager;
		auto parser = new StyleSheetParser(str, tmpSheet, baseURI, fontManager, materialManager);
		if (parser.parse())
		{
			res.swap(tmpSheet);
			tmpSheet.clear();
			res.manager.onResourceLoaded(res, this);
		}
		else
		{
			import std.stdio;
			foreach (m; parser.errors)
				writeln(m.message);
		}
	}

	private MaterialManager _materialManager;
	private FontManager _fontManager;
}

/*

interface Serializer
{
	void serialize(T)(T s);
	T deserialize(T)() { return null; }
}

class JSONSerializer : Serializer
{
	private string _data;
	private string output;

	this(string data = "")
	{
		_data = data;
	}
	
	void serialize(T)(T s)
	{
		import jsonx;
		output ~= jsonEncode(s);
	}

	T deserialize(T)()
	{
		import jsonx;
		return jsonDecode!(T)(data);
	}
}

unittest 
{
	string d = q{

		{
			"styles1" : {
				"style1a": {
					"parent": "parent",
					"font": "font",
					"material": "material",
					"color" : "#8899aa",
					"padding" : "1 2 3 4.5"
				}
			}
		}
	};
	import std.stdio;
	import std.string;

	StydleSetManager mgr = StyleSedtManager.create(new IOManager(), new MaterialManager(), new FontManager());
	auto s = new JSONSerializer(strip(d));
	mgr.deserialize(s);
	
//	import test;
//	Assert(d, s.
	
}
*/
