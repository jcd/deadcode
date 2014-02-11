module gui.style;

import core.uri;

import math._;

import graphics.color : Color, stringToColor;

import gui.gui;
import gui.locations;
import gui.resource;
import gui.resources.material;
import gui.resources.font : Font, FontManager;

import io.iomanager;

import std.file;
import std.math;
import std.path;
import std.range;

version (unittest) import test;

alias string StyleID;

immutable StyleID NullStyleName = "";
immutable StyleID DefaultStyleName = "default";

struct StyleFields
{
	// ref types
	Font _font;
	Material _background;

	// value types
	Color _color;
	bool _wordWrap;  // bit 0
	Rectf _padding;  
	// float _glyphPadding; etc....

	// bitmask. One bit set for each by value property that does not support fake null values and derived
	// from parents style. The fields are:
	// * wordWrap bit 0
	ubyte _derived;

	StyleFields overlay(StyleFields sf)
	{
		if (sf._font is null)
			sf._font = _font;
		if (sf._background is null)
			sf._background = _background;
		if (isNaN(sf._color.r))
			sf._color = _color;
		if (_derived & 1)
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
}

class Style
{
	StyleSet styleSet; // StyleSet that this style is a member of

	private 
	{
		enum Field
		{
			font,
			background,
			color,
			wordWrap,
			padding
		}
		
		Style _parent;      // Parent style or null if root style
		StyleFields _fields; // Fields set on this style
		StyleFields _computedFields; // Computed fields from 'fields' and inherited fields from parent
		
		
		// Compute the computed fields
		void compute()
		{
			_computedFields = _fields;

			if (_parent is null) return;
			// _parent.compute();

			alias _computedFields f;
			
			if (f._font is null)
				f._font = _parent._computedFields._font;
			if (f._background is null)
				f._background = _parent._computedFields._background;
			
			import std.math;
			if (f._color.r.isNaN())
				f._color = _parent._computedFields._color;
			if (_fields._derived & 1)
				f._wordWrap = _parent._computedFields._wordWrap;
			if (f._padding.x.isNaN())
				f._padding.x = _parent._computedFields._padding.x; 
			if (f._padding.y.isNaN())
				f._padding.y = _parent._computedFields._padding.y; 
			if (f._padding.w.isNaN())
				f._padding.w = _parent._computedFields._padding.w; 
			if (f._padding.h.isNaN())
				f._padding.h = _parent._computedFields._padding.h; 
		
			styleSet.compute(this);
		}
	}

	@property 
	{
		Style parent() 
		{
			return _parent;
		}
		
		void parent(Style p)
		{
			_parent = p;
			styleSet.compute(p);
		}
		
		StyleFields computedFields() // const
		{
			return _computedFields;
		}
		
		Font font()
		{
			auto f = _computedFields._font;
			f.ensureLoaded();
			return f;
		}

		void font(Font f) 
		{
			_fields._font = f;

			styleSet.compute(parent);
		}
		
		Material background()
		{
			auto b = _computedFields._background;
			b.ensureLoaded();
			return b;
		}

		void background(Material b)
		{
			_fields._background = b;
			_computedFields._background = b;
			styleSet.compute(parent);
		}
		
		Color color()
		{
			return _computedFields._color;
		}

		void color(Color c)
		{
			_fields._color = c;
			styleSet.compute(parent);
		}
		
		bool wordWrap()
		{
			return _computedFields._wordWrap;
		}
		
		void wordWrap(bool w)
		{
			_fields._wordWrap = w;
			styleSet.compute(parent);
		}

		Rectf padding()
		{
			return _computedFields._padding;
		}
	
		// TODO: make a paddingX, paddingY etc. methods
		void padding(Rectf w)
		{
			_fields._padding = w;
			styleSet.compute(parent);
		}
	
		string name()
		{
			return _name;
		}
	}
	
	string _name;
	
	this(StyleSet styleSet, string name)
	{
		this.styleSet = styleSet;
		this._name = name;	
	}
	
	// Reset to init state ie. having all fields "null" values
	void clear()
	{
		_fields._font = null;
		_fields._background = null;
		_fields._color.r = float.nan;
		_fields._derived = 1;
		_fields._padding.pos.x = float.nan;
		_fields._padding.pos.y = float.nan;
		_fields._padding.size.x = float.nan;
		_fields._padding.size.y = float.nan;
	}
	
	// reset in the same state as s
	void reset(Style s)
	{
		_fields._font = s._fields._font;
		_fields._background = s._fields._background;
		_fields._color = s._fields._color;
		_fields._derived = s._fields._derived;
		_fields._padding = s._fields._padding;
	}

	void merge(Style s)
	{
		
	}
	
	void SetFromCSS(string cssString)
	{
	
	}
}

class StyleSet : Resource!StyleSet
{
	Style[string] styles; // name => style 
	alias styles this;
	string name;
	private bool[string] _missingStyles;

	// private static StyleSet _defaultStyleSet;
	// private static StyleSet _base;
	
	static @property
	{
		/*
		StyleSet base()
		{
			if (_base is null)
				_base = builtin;
			return _base;
		}
	
		void base(StyleSet ss)
		{
			_base = ss;
		}
	
		@property string basePath()
		{
			import util.system;
			return getRunningExecutablePath() ~ "/resources/themes/default/";
		}

		StyleSet builtin()
		{		
			if (_defaultStyleSet is null)
			{
				import util.system;
				StyleSet ss = new StyleSet("builtin");
				Style lbase = new Style(ss);
				
				lbase.font = GUI.the.fontManager.get("default"); // new Font(getRunningExecutablePath() ~ "cour.ttf", 16);
				lbase.background = GUI.the.materialManager.get("default"); // Material.builtIn;
				lbase.color = Color(1f,1f,1f);		
				lbase.padding = Rectf(20, 20, 20 ,20);
				lbase.name = "";
				ss[0] = lbase; // default
	
				Style s = new Style(ss);
				s.parent = lbase;
//				s.color = Color(0.3f, 0f, 1f);
				s.color = Color(1.0f, 0f, 0f);
				s.font = GUI.the.fontManager.get("default"); // new Font(getRunningExecutablePath() ~ "cour.ttf", 16);
				s.name = "declaration";
				ss[1] = s;

				s = new Style(ss);
				s.parent = lbase;
				s.color = Color(0.3f, 1f, 0.3f);
				s.name = "type";
				ss[2] = s;
	
				s = new Style(ss);
				s.parent = lbase;
				s.color = Color(0.0f, 1f, 0.0f);
				s.name = "values";
				ss[3] = s;

				s = new Style(ss);
				s.parent = lbase;
				//s.color = Color(1f,1f,1f);
				s.background = GUI.the.materialManager.get("edit-background"); // Material.create(basePath ~ "edit-background.png");
				s.name = "bg";
				ss[4] = s;

				_defaultStyleSet = ss;

			}
			return _defaultStyleSet;
		}
		*/
	}
	
	this(string name = "")
	{
		this.name = name;
	}

	Style getStyle(string name)
	{
		foreach (k, v; styles)
		{
			if (v.name == name)
				return v;
		}

		if (name !in _missingStyles)
		{
			std.stdio.writeln(std.conv.text("Cannot locate style named ", name, ". Falling back to builtin"));
			_missingStyles[name] = true;
		}

		StyleSetManager m = cast(StyleSetManager) manager;
		return m.builtinStyleSet.getStyle("builtin");
	}

	public Style createStyle(string name = "")
	{
		if (name == null)
		{
			Style getStyleHelper(string name)
			{
				foreach (k, v; styles)
				{
					if (v.name == name)
						return v;
				}
				return null;
			}
			
			int i = 1;
			name = std.string.format("style_%s", i++);
			while ( getStyleHelper(name) !is null )
				name = std.string.format("style_%s", i++);
		}
		auto s = new Style(this, name);
		styles[name] = s;
		return s;
	}

	// Compute computed fields for all styles
	private void compute(Style root)
	{
		foreach (style; styles)
		{
			if (style.parent is root)
				style.compute();
		}
	}
}


unittest
{
	auto ss = new StyleSet;
	auto parent = ss.createStyle;
	parent.color = Color(0,1,0);
	parent.padding = Rectf(1,2,3,4);
	
	auto child1 = ss.createStyle;
	child1.parent = parent;
	child1.color = Color(1,0,0);
	Assert(child1.color, Color(1,0,0));
	Assert(parent.color, Color(0,1,0));
	Assert(child1.padding, parent.padding);
	Assert(child1.padding, Rectf(1,2,3,4));

	auto child2 = ss.createStyle;
	child2.parent = parent;
	child2.padding = Rectf(2,2,2,2);

	Assert(child2.color, parent.color);
	Assert(child2.padding != parent.padding);
	Assert(child2.padding, Rectf(2,2,2,2));
}


class StyleSetManager : ResourceManager!StyleSet
{
	private 
	{
		FontManager _fontManager;  // TODO: No need for managers I think. Let the ones why create styles know about that
		MaterialManager _materialManager;
	}

	@property 
	{
/*
		FontManager fontManager()
		{
			return _fontManager;
		}

		MaterialManager materialManager()
		{
			return _materialManager;
		}
	*/
		StyleSet builtinStyleSet()
		{
			return get("builtin");
		}
	}

	static StyleSetManager create(IOManager ioManager, MaterialManager mm, FontManager fm)
	{
		import gui.resources;
		auto ssm = new StyleSetManager;
		ssm.ioManager = ioManager;
		ssm.addSerializer(new StyleSetSerializer(mm, fm));

		ssm.createBuiltinStyleSet(mm, fm);

		return ssm;
	}

	private void createBuiltinStyleSet(MaterialManager mm, FontManager fm)
	{
		auto ss = declare("builtin");
		Style lbase = ss.createStyle("builtin");
		lbase.font = fm.builtinFont;
		lbase.background = mm.builtinMaterial;
		lbase.color = Color.red;
		lbase.padding = Rectf(0, 0, 0, 0);
		onResourceLoaded(ss, null);
	}

/*
	this(FontManager fontMgr, MaterialManager matMgr)
	{
		_fontManager = fontMgr;
		_materialManager = matMgr;

		// createBuiltinStyleSet();
	}
	*/
	/*
	void createBuiltinStyleSet(FontManager fontManager, MaterialManager materialManager)
	{
		import util.system;
		StyleSet ss = new StyleSet("builtin");
		Style lbase = new Style(ss);
		lbase.font = fontManager.get("default"); // new Font(getRunningExecutablePath() ~ "cour.ttf", 16);
		lbase.background = materialManager.get("default");
		lbase.color = Color(1f,1f,1f);		
		lbase.padding = Rectf(20, 20, 20 ,20);
		lbase.name = "";
		ss[0] = lbase; // default

		Style s = new Style(ss);
		s.parent = lbase;
		//				s.color = Color(0.3f, 0f, 1f);
		s.color = Color(1.0f, 0f, 0f);
		s.font = fontManager.get("default"); // new Font(getRunningExecutablePath() ~ "cour.ttf", 16);
		s.name = "declaration";
		ss[1] = s;

		s = new Style(ss);
		s.parent = lbase;
		s.color = Color(0.3f, 1f, 0.3f);
		s.name = "type";
		ss[2] = s;

		s = new Style(ss);
		s.parent = lbase;
		s.color = Color(0.0f, 1f, 0.0f);
		s.name = "values";
		ss[3] = s;

		s = new Style(ss);
		s.parent = lbase;
		//s.color = Color(1f,1f,1f);
		s.background = materialManager.get("edit-background"); // Material.create(basePath ~ "edit-background.png");
		s.name = "bg";
		ss[4] = s;

		// _defaultStyleSet = ss;		
	}
*/

	/*
	StyleSet[] loadStyleSets(string path)
	{
		import std.file;
		return deserialize(new JSONSerializer(readText(path)));
	}

	void serialize(Serializer s)
	{
		
	}

	StyleSet[] deserialize(Serializer s)
	{
		struct MaterialData
		{
			string name;
		}

		struct FontData
		{
			string name;
			int size;
		}

		struct StyleData
		{
			string parent;
			FontData font;
			MaterialData material;
			string color;
			string padding;
		}

		struct StyleSetData
		{
			StyleData[string] styles;
		}

		auto styleSets = s.deserialize!(StyleSetData[string])(); 
		StyleSet[] result;

		foreach (k, v; styleSets)
		{
			auto ss = new StyleSet(k);
			_styleSets[k] = ss;
			result ~= ss;
			Style lbase = ss.createStyle();

			foreach (sk, sv; v.styles)
			{
				Style lbase = ss.createStyle(sk);
				//lbase.name = sk;
				lbase.parent = ss.getStyle(sv.parent);
				lbase.font = null; // _fontManager.create(sv.font.name, sv.font.size);
				lbase.background = null; // _materialManager.create(sv.material.name);
				lbase.color = stringToColor(sv.color);
				lbase.padding = stringToRectf(sv.padding);
			}
		}
		return result;
	}
	*/
}


class StyleSetSerializer : ResourceSerializer!StyleSet
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

	override bool canHandle(URI uri)
	{
		return uri.extension == ".styleset";
	}

	override void deserialize(StyleSet res, string str)
	{
		struct StyleSpec
		{
			string parent;
			string font;
			string material;
			string color;
			string padding;
		}

		struct StyleSetSpec
		{
			StyleSpec[string] styles;
		}

		import jsonx;
		auto spec = jsonDecode!(StyleSpec[string])(str);

		URI baseURI = res.uri.dirName;

		foreach (sk, sv; spec)
		{
			auto fontURI = new URI(sv.font);
			if (!fontURI.isAbsolute)
				fontURI.makeAbsolute(baseURI);
			auto matURI = new URI(sv.material);
			if (!matURI.isAbsolute)
				matURI.makeAbsolute(baseURI);

			Style lbase = res.createStyle(sk);
			lbase.parent = res.getStyle(sv.parent);
			lbase.font = _fontManager.declare(null, fontURI);
			lbase.background = _materialManager.declare(null, matURI);
			lbase.color = stringToColor(sv.color);
			lbase.padding = stringToRectf(sv.padding);
		}

		res.manager.onResourceLoaded(res, this);
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

	StyleSetManager mgr = StyleSetManager.create(new IOManager(), new MaterialManager(), new FontManager());
	auto s = new JSONSerializer(strip(d));
	mgr.deserialize(s);
	
//	import test;
//	Assert(d, s.
	
}
*/
