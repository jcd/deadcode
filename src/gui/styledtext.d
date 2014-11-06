module gui.styledtext;

import core.bufferview;
import gui.style;
import math.region;
import std.container;
import std.signals;
import std.string;

class TextStyler(Text)
{
	Text text;

	protected RegionSet _regionSet;
	private Region _dirtyRegion;

	@property RegionSet regionSet()
	{
		if (!_dirtyRegion.empty)
		{
			update(_dirtyRegion);
			_dirtyRegion.a = _dirtyRegion.b;
		}
		return _regionSet;
	}

	mixin Signal!() onChanged;

	this(Text text)
	{
		this.text = text;
		this._regionSet = new RegionSet();
		
		static if ( is(Text : BufferView) )
		{
			text.onInsert.connect(&textInsertedCallback);
			text.onRemove.connect(&textRemovedCallback);
		}
	}

	static if ( is(Text : BufferView) )
	{
		protected void textInsertedCallback(BufferView b, BufferView.BufferString str,int from)
		{
			// Update region set
			_regionSet.entriesInserted(from, str.length);

			scheduleRegion(Region(from, from + str.length));
		}

		protected void textRemovedCallback(BufferView b, BufferView.BufferString str,int from)
		{
			// Update region set
			_regionSet.entriesRemoved(from, str.length);
			
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
	}

	void scheduleRegion(Region r)
	{
		_dirtyRegion = _dirtyRegion.cover(r);
		if (_dirtyRegion.b > text.length)
			_dirtyRegion.b = text.length;
	}

	void scheduleAll()
	{
		_dirtyRegion.a = 0;
		_dirtyRegion.b = text.length;
	}

	string styleIDToName(int id)
	{
		return null;
	}

	protected void styleRegion(Region r)
	{
		_regionSet.merge(r.a, r.b, 0);
	}

	protected void update(Region r)
	{
		// Look for the preceeding and succeeding whitespace and form a region using that 
		// to use for restyling.
		// Restyle entire lines
		static if ( is(Text : BufferView) )
		{
			
			int a = text.buffer.findOneOfReverse(r.a, "\r\n");
			int b = text.buffer.findOneOf(r.b, "\r\n");
			a = a == int.max ? 0 : a;
			b = b == int.max ? text.length : b;
			styleRegion(Region(a, b));
			//styleRegion(Region(0, text.length));
		}
		else
		{
			styleRegion(Region(0, text.length));
		}
	}

	protected void update()
	{
		_regionSet.clear();
		update(Region(0, text.length, 0));
	}
}

class DSourceStyler(Text) : TextStyler!Text
{
	enum DStyle
	{
		other = 0,
		declaration = 1,
		type = 2
	};
	
	this(Text text)
	{
		super(text);
	}
	
	override protected void styleRegion(Region r)
	{
		// TODO: use ctRegex
		enum decls = [ "@property"d, 
			"alias", "auto", "assert", "break", "case", "class", "const", "default", "do", "else", "enum", "extern", "for", "foreach", "goto", "if", "import", "in", "interface", "is", "!is",
			"module", "new", "nothrow", "null", "override", "package", "private", "public", "pure", "return", "safe", "scope", 
			"static", "struct", "switch", "template", "this", "union", "unittest", "version", "while" ];
		enum types = [ "bool"d, 
			"byte", "char", "dchar", "double", "dstring", "float", "int", "long", "short", "size_t", "string", "ubyte", "uint", "ulong", 
			"ushort", "void", "wchar", "wstring" ];
		dstring re = "\\b(";
		dstring delim = "";
		foreach (tt; decls)
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

		foreach (d; decls)
			templates[d] = DStyle.declaration;
		foreach (t; types)
			templates[t] = DStyle.type;

		import std.array;
		auto buf = array(text[r.a..r.b]); // TODO: make request for adding string like support to std.regex

		size_t lastEndIdx = 0;
		size_t offset = r.a;

		foreach (m; match(buf, ctr))
		{
			auto t = templates[m.hit];
			auto begin = m.pre.length;
			auto end = begin + m.hit.length;
			if (begin != lastEndIdx)
				_regionSet.set(offset + lastEndIdx, offset + begin, DStyle.other);
			_regionSet.set(offset + begin, offset + end, t);
			lastEndIdx = end;
		}

		if (lastEndIdx != r.b)
			_regionSet.set(offset + lastEndIdx, r.b, DStyle.other);

		onChanged.emit();
	}
		
	override string styleIDToName(int id)
	{
		DStyle styleID = cast(DStyle)id;
		final switch(styleID)
		{
		case DStyle.other:
			return "dsource-other";
		case DStyle.declaration:
			return "dsource-declaration";
		case DStyle.type:
			return "dsource-type";
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
	
class StyleSheetStyler(Text) : TextStyler!Text
{
	enum StyleSheetStyle
	{
		other = 0,
		styleKey = 1,
		type = 2
	};

	this(Text text)
	{
		super(text);
	}

	protected override void styleRegion(Region r)
	{
		// TODO: use ctRegex
		enum keys = [ "background"d, "color", "font", "padding" ];
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

class ChangeLogStyler(Text) : TextStyler!Text
{
	enum Styling
	{
		other,
		releaseTitle,
		subTitle,
		changeset,
		bullet
	};

	this(Text text)
	{
		super(text);
	}

	private void setStyleByRegex(Region r, dstring re, Styling styling)
	{
		import std.regex;		
		//auto ctr = regex(r"\s+([a-f0-9]+)\*?\s+ ", "mg");		
		auto ctr = regex(re, "mg");		

		import std.array;
		auto buf = array(text[r.a .. r.b]);
		size_t offset = r.a;

		foreach (m; match(buf, ctr))
		{
			auto begin = m.pre.length + m[1].length;
			auto end = begin + m[2].length;
			_regionSet.merge(offset + begin, offset + end, styling);
		}
	}

	protected override void styleRegion(Region r)
	{
		import std.stdio;
		_regionSet.set(r.a, r.b, Styling.other);
		setStyleByRegex(r, r"^()(Changes:|Overview:)\s*$"d, Styling.subTitle);
		setStyleByRegex(r, r"^()(Release.*?\s+[\.0-9]+\s.*)$"d, Styling.releaseTitle);	
		setStyleByRegex(r, r"^(\s+)([0-9a-f]+)\s"d, Styling.changeset);
		setStyleByRegex(r, r"(\s)(\*)\s"d, Styling.bullet);
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
