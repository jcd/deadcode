module style;

import color;
import math;
import font; // : Font;
import graphics; // : Material;

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
			st._font = _font;
		if (sf._background is null)
			sf._background = _background;
		if (isNan(sf._color.r))
			sf._color = _color;
		if (_derived & 1)
			sf._wordWrap = _wordWrap;
		if (sf._padding.x.isNan())
			sf._padding.x = _padding.x; 
		if (sf._padding.y.isNan())
			sf._padding.y = _padding.y; 
		if (sf._padding.w.isNan())
			sf._padding.w = _padding.w; 
		if (sf._padding.h.isNan())
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
			if (_parent is null) return;
			_parent.compute();
			
			_computedFields = _fields;
			
			alias _computedFields f;
			
			if (f._font is null)
				f._font = _parent._computedFields._font;
			if (f._background is null)
				f._background = _parent._computedFields._background;
			
			import std.math;
			if (f._color.r.isNan())
				f._color = _parent._computedFields._color;
			if (_fields._derived & 1)
				f._wordWrap = _parent._computedFields._wordWrap;
			if (f._padding.x.isNan())
				f._padding.x = _parent._computedFields._padding.x; 
			if (f._padding.y.isNan())
				f._padding.y = _parent._computedFields._padding.y; 
			if (f._padding.w.isNan())
				f._padding.w = _parent._computedFields._padding.w; 
			if (f._padding.h.isNan())
				f._padding.h = _parent._computedFields._padding.h; 
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
			styleSet.compute(this);
		}
		
		StyleFields computedFields() const
		{
			return _computedFields;
		}
		
		Font font()
		{
			return _computedFields._font;
		}

		void font(Font f) 
		{
			_computedFields._font = f;
			styleSet.compute(this);
		}
		
		Material background()
		{
			return _computedFields._background;
		}

		void background(Material b)
		{
			_computedFields._background = b;
			styleSet.compute(this);
		}
		
		Color color()
		{
			return _computedFields._color;
		}

		void color(Color c)
		{
			_computedFields._color = c;
			styleSet.compute(this);
		}
		
		bool wordWrap()
		{
			return _computedFields._wordWrap;
		}
		
		void wordWrap(bool w)
		{
			_computedFields._wordWrap = w;
			styleSet.compute(this);
		}

		Rectf padding()
		{
			return _computedFields._padding;
		}
		
		// TODO: make a paddingX, paddingY etc. methods
		void padding(Rectf w)
		{
			_padding = w;
			styleSet.compute(this);
		}
		
	}
	
	string name;
	
	this(string name = "unnamed")
	{
		this.name = name;	
	}
	
	// Reset to init state ie. having all fields "null" values
	void clear()
	{
		_fields._font = null;
		_fields._background = null;
		_fields._color.x = NAN;
		_fields._derived = 1;
		_fields._padding.pos.x = NAN;
		_fields._padding.pos.y = NAN;
		_fields._padding.size.x = NAN;
		_fields._padding.size.y = NAN;
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
				import font;
				import graphics;
				StyleSet ss = new StyleSet();
				Style base = new Style();
				base.font = new Font("cour.ttf", 16);
				base.background = Material.builtIn;
				base.color = Color(1f,1f,1f);
				base.padding = Rectf(Vec2f(20,20), Vec2f(20,20));
				base.name = "";
				ss[0] = base; // default
	
				Style s = new Style();
				s.parent = base;
				s.color = Color(0.3f, 0f, 1f);
				s.name = "declaration";
				ss[1] = s;
				
				s = new Style();
				s.parent = base;
				s.color = Color(0.3f, 1f, 0.3f);
				s.name = "type";
				ss[2] = s;
	
				s = new Style();
				s.parent = base;
				s.color = Color(0.0f, 1f, 0.0f);
				s.name = "values";
				ss[3] = s;

				_defaultStyleSet = ss;
			}
			return _defaultStyleSet;
		}
	}
	
	// Compute computed fields for all styles
	private void compute()
	{
		foreach (n, style; styles)
		{
			style.compute();
		}
	}
}
