module gui.styledtext;

import core.bufferview;
import gui.style;
import math.region;
import std.container;
import core.signals;
import std.string;

T instantiate(T)(T o)
{
	import std.stdio;
	T result = cast(T) o.classinfo.create();
	// writefln("Instantiating %s", result.classinfo.name);
	return result;
}

static 
{
	TextStyler[] s_Stylers;

	void register(TextStyler styling)
	{
		s_Stylers ~= styling;	
	}

	TextStyler createTextStyler(BufferView text)
	{
		return createTextStyler(text, text.name);
	}

	TextStyler createTextStyler(Text)(Text text, string name)
	{
		TextStyler styler;
		
		foreach (s; s_Stylers)
		{
			if (s.canStyle(name))
			{
				styler = instantiate(s);
				break;
			}
		}

		if (styler is null)
			styler = new TextStyler();

		static if ( is(Text : BufferView) )
		{
			text.onInsert.connect(&styler.textInsertedCallback);
			text.onRemove.connect(&styler.textRemovedCallback);
		}
		return styler;
	}
}

static this()
{
	register(new StyleSheetStyler());
	register(new ChangeLogStyler());
}

class TextStyler
{
//	protected Text _text;
	protected RegionSet _regionSet;
	protected RegionSet _regionSetUpdateThread;
	private Region _dirtyRegion;


	//@property Text text()
	//{
	//    return _text;
	//}
	
	@property RegionSet regionSet()
	{
		//if (!_dirtyRegion.empty)
		//{
		//    update(_dirtyRegion);
		//    _dirtyRegion.a = _dirtyRegion.b;
		//}
		return _regionSet;
	}

	mixin Signal!() onChanged;

	this()
	{
		this._regionSet = new RegionSet();
	}

	/** Returns true if the name can be styled
	
		The name should be either a filename or a full file path.

		Returns: true if this styler can handle the file type
	*/
	bool canStyle(string name) const pure
	{
		return true;
	}

//    void initialize(Text text)
//    {
//        if (_regionSet !is null)
//            throw new Exception("Double initialization of ", typeof(this).stringof);
//
////		this.text = text;
//        this._regionSet = new RegionSet();
//        
//        //static if ( is(Text : BufferView) )
//        //{
//        //    text.onInsert.connect(&textInsertedCallback);
//        //    text.onRemove.connect(&textRemovedCallback);
//        //}
//    }

	// In case a bufferview is hooked up to this styling
	protected void textInsertedCallback(BufferView b, BufferView.BufferString str,int from)
	{
		// Update region set
		_regionSet.entriesInserted(from, str.length);
		import std.stdio;
		//writefln("Insert styler %s from %s", str.length, from);
		scheduleRegion(Region(from, from + str.length));
	}

	// In case a bufferview is hooked up to this styling
	protected void textRemovedCallback(BufferView b, BufferView.BufferString str,int from)
	{
		// Update region set
		_regionSet.entriesRemoved(from, str.length);
		
		import std.stdio;
		// writefln("Removed styler %s from %s", str.length, from);

		// Just dirty something on the same line
		if (from > 0)
		{
			scheduleRegion(Region(from-1, from));
		}
		else if (b.length)
		{
			scheduleRegion(Region(0, 1));
		}
		else
		{
			// Empty buffer. We can clear the regions set and dirty area
			_regionSet.clear();
			_dirtyRegion.a = _dirtyRegion.b;
		}
	}

	void scheduleRegion(Region r)
	{
		_dirtyRegion = _dirtyRegion.cover(r);
		//if (_dirtyRegion.b > text.length)
		//    _dirtyRegion.b = text.length;
	}

	void scheduleAll()
	{
		_dirtyRegion.a = 0;
		_dirtyRegion.b = int.max;
	}

	string styleIDToName(int id)
	{
		return null;
	}

	/// This should overridden in derived classes to do the actual styling
	private void styleRegion(Text)(Region r, Text text)
	{
		assert(r.a >= 0 && r.a <= text.length);
		assert(r.b >= 0 && r.b <= text.length);
		import std.stdio;
		// writeln("styler.styleRegion() ", _dirtyRegion);
		static if (is(Text : BufferView))
			styleBufferViewRegion(r, text);
		else
			styleStringRegion(r, text);
	}

	protected void styleBufferViewRegion(Region r, BufferView text)
	{
		_regionSet.merge(r.a, r.b, 0);
	}

	protected void styleStringRegion(Region r, string text)
	{
		_regionSet.merge(r.a, r.b, 0);
	}

	private void forceUpdate(Text)(Region r, Text text)
	{
		// Sanitize the region
		r = r.clip(0, text.length);
		
		// Look for the preceeding and succeeding whitespace and form a region using that 
		// to use for restyling.
		// Restyle entire lines
		static if ( is(Text : BufferView) )
		{		
			int a = text.buffer.findOneOfReverse(r.a, "\r\n");
			int b = text.buffer.findOneOf(r.b, "\r\n");
			a = a == int.max ? 0 : a;
			b = b == int.max ? text.length : b;
			styleRegion(Region(a, b), text);
			//styleRegion(Region(0, text.length));
		}
		else
		{
			styleRegion(Region(0, text.length), text);
		}
	}

	private void updateAll(Text)(Text text)
	{
		_regionSet.clear();
		forceUpdate(Region(0, text.length, 0), text);
	}

	private void update(Text)(Text text)
	{
		//import std.stdio;
		//writeln("styler.update() ", _dirtyRegion);
		if (!_dirtyRegion.empty)
		{
			//writeln("styler.update()... ");
		    forceUpdate(_dirtyRegion, text);
		    _dirtyRegion.a = _dirtyRegion.b;
		}
	}
}




unittest
{
//t	std.stdio.writeln("Styles white %x, black %x, yellow %x", &white, &black, &yellow); 
/*t	
	auto text = new StyledText!dchar("yellow white      black yellow"d);
	auto rs = new RegionSet();
	
	uint yellow = 1;
	uint white = 2;
	uint black = 3;	
	
	rs.add(0, 6, yellow); 
	rs.add(7, 12, white);
	rs.add(18, 23, black);
	rs.add(24, 100, yellow); 

	auto r = text[1..text.text.length];
	
	// Print out the styles
	foreach (sr; r)
	{
		std.stdio.writeln("Range %i %i: %s", sr.a, sr.b, sr.styleFields);
	}			
*/
}
	
class StyleSheetStyler : TextStyler
{
	enum StyleSheetStyle
	{
		other = 0,
		styleKey = 1,
		type = 2
	};

	override bool canStyle(string name) const pure
	{
		return name.endsWith(".stylesheet");
	}

	protected override void styleBufferViewRegion(Region r, BufferView text)
	{
		// TODO: use ctRegex
		enum keys = [ "background"d, "color", "font", "padding", "transition", "position",
					  "left", "right", "top", "bottom", "width", "height", "offset" ];
		enum types = [ "#"d, "\\\\." ];

		dstring re = "\\b(";
		dstring delim = "";
		foreach (tt; keys)
		{
			re ~= delim;
			re ~= tt;
			delim = "|";
		}
		foreach (tt; types)
		{
			re ~= delim;
			re ~= tt;
		}
		re ~= ")\\b";

		import std.regex;		
		auto ctr = regex(re, "mg");

		int[dstring] templates;

		foreach (d; keys)
			templates[d] = StyleSheetStyle.styleKey;
		foreach (t; types)
			templates[t] = StyleSheetStyle.type;

		import std.array;
		assert(r.a >= 0 && r.a <= text.length);
		assert(r.b >= 0 && r.b <= text.length);
		auto buf = array(text[r.a .. r.b]);
		
		size_t lastEndIdx = 0;
		size_t offset = r.a;

		foreach (m; match(buf, ctr))
		{
			auto t = templates[m.hit];
			auto begin = m.pre.length;
			auto end = begin + m.hit.length;
			if (m.hit == "#")
			{
				auto kk = buf[end..$].indexOf('{');
				end += kk == -1 ? 0 : kk; 
			}

			if (begin != lastEndIdx)
				_regionSet.merge(offset + lastEndIdx, offset + begin, StyleSheetStyle.other);
			_regionSet.merge(offset + begin, offset + end, t);
			lastEndIdx = end;
		}

		if (lastEndIdx != text.length)
			_regionSet.merge(offset + lastEndIdx, r.b, StyleSheetStyle.other);

		onChanged.emit();
	}

	override string styleIDToName(int id)
	{
		StyleSheetStyle styleID = cast(StyleSheetStyle)id;
		final switch(styleID)
		{
			case StyleSheetStyle.other:
				return "stylesheet-other";
			case StyleSheetStyle.styleKey:
				return "stylesheet-style-key";
			case StyleSheetStyle.type:
				return "stylesheet-type";
		}
	}
}

class ChangeLogStyler : TextStyler
{
	enum Styling
	{
		other,
		releaseTitle,
		subTitle,
		changeset,
		bullet
	};

	override bool canStyle(string name) const pure 
	{
		return name.toLower.startsWith("changelog");
	}

	private void setStyleByRegex(Text)(Region r, dstring re, Styling styling, Text text)
	{
		import std.regex;		
		//auto ctr = regex(r"\s+([a-f0-9]+)\*?\s+ ", "mg");		
		auto ctr = regex(re, "mg");		

		import std.array;
		assert(r.a >= 0 && r.a <= text.length);
		assert(r.b >= 0 && r.b <= text.length);
		auto buf = array(text[r.a .. r.b]);
		size_t offset = r.a;

		foreach (m; match(buf, ctr))
		{
			auto begin = m.pre.length + m[1].length;
			auto end = begin + m[2].length;
			_regionSet.merge(offset + begin, offset + end, styling);
		}
	}

	protected override void styleBufferViewRegion(Region r, BufferView text)
	{
		import std.stdio;
		_regionSet.set(r.a, r.b, Styling.other);
		setStyleByRegex(r, r"^()(Changes:|Overview:)\s*$"d, Styling.subTitle, text);
		setStyleByRegex(r, r"^()(Release.*?\s+[\.0-9]+\s.*)$"d, Styling.releaseTitle, text);	
		setStyleByRegex(r, r"^(\s+)([0-9a-f]+)\s"d, Styling.changeset, text);
		setStyleByRegex(r, r"(\s)(\*)\s"d, Styling.bullet, text);
		onChanged.emit();
	}

	override string styleIDToName(int id)
	{
		auto styleID = cast(Styling)id;
		final switch(styleID)
		{
			case Styling.other:
				return "changelog-other";
			case Styling.releaseTitle:
				return "changelog-releasetitle";
			case Styling.subTitle:
				return "changelog-subtitle";
			case Styling.changeset:
				return "changelog-changeset";
			case Styling.bullet:
				return "changelog-bullet";
		}
	}
}
