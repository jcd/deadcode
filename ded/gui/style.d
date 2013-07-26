module gui.style;

import math._;
import graphics._; // : Material; Font Color

import std.math;

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
			_parent.compute();

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
			return _computedFields._font;
		}

		void font(Font f) 
		{
			_fields._font = f;

			styleSet.compute(parent);
		}
		
		Material background()
		{
			return _computedFields._background;
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
	}
	
	string name;
	
	this(StyleSet styleSet, string name = "unnamed")
	{
		this.styleSet = styleSet;
		this.name = name;	
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
	
	void merge(Style s)
	{
		
	}
	
	void SetFromCSS(string cssString)
	{
	
	}
}

class StyleSet
{
	Style[uint] styles;
	alias styles this;

	private static StyleSet _defaultStyleSet;
	private static StyleSet _base;
	
	static @property
	{
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
	
		StyleSet builtin()
		{		
			if (_defaultStyleSet is null)
			{
				import graphics._;
				import system;
				StyleSet ss = new StyleSet();
				Style lbase = new Style(ss);
				lbase.font = new Font(getRunningExecutablePath() ~ "cour.ttf", 16);
				lbase.background = Material.builtIn;
				lbase.color = Color(1f,1f,1f);		
				lbase.padding = Rectf(20, 20, 20 ,20);
				lbase.name = "";
				ss[0] = lbase; // default
	
				Style s = new Style(ss);
				s.parent = lbase;
//				s.color = Color(0.3f, 0f, 1f);
				s.color = Color(1.0f, 0f, 0f);
				s.font = new Font(getRunningExecutablePath() ~ "cour.ttf", 32);
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
				s.background =  Material.create(getRunningExecutablePath() ~ "bg3.png");
				s.name = "bg";
				ss[4] = s;

				_defaultStyleSet = ss;

			}
			return _defaultStyleSet;
		}
	}
	
	// Compute computed fields for all styles
	private void compute(Style root)
	{
		foreach (n, style; styles)
		{
			if (style.parent is root)
				style.compute();
		}
	}
}
