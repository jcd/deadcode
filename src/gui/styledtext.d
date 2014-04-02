module gui.styledtext;

import core.bufferview;
import gui.style;
import math.region;
import std.container;
import std.signals;
import std.string;

class TextStyler(Text)
{
	RegionSet regionSet;
	Text text;

	mixin Signal!() onChanged;

	this(Text text)
	{
		this.text = text;
		this.regionSet = new RegionSet();
		//this.regionSet.add(0, uint.max);
		static if ( is(Text : BufferView) )
		{
			text.onInsert.connect(&textChangedCallback);
			text.onRemove.connect(&textChangedCallback);
		}
	}

	static if ( is(Text : BufferView) )
	{
		protected void textChangedCallback(BufferView b, BufferView.BufferString,uint)
		{
			update();
		}
	}

	// A Region specifying the composed style of several styles 
	//static struct StyledRegion
	//{
	//    Region _reg;
	//    alias _reg this;
	//    StyleFields styleFields;
	//    this(uint a, uint b, StyleFields styleFields)
	//    {
	//        this.a = a;
	//        this.b = b;
	//        this.styleFields = styleFields;
	//    }
	//}

	string styleIDToName(int id)
	{
		return null;
	}
	/+
	// This slice can be used to iterate over composed style regions lazyly. 
	auto opSlice(uint from, uint to)
	{
	struct Range
	{
	// The regionSet must be non-partial overlapping ie. like xml markup is since this
	// makes it possible to keep the style state in stack form with the top item being the
	// current active styled region.
	private
	{
	RegionSet.Range regionSetRange;
	Array!StyledRegion stack_;
	StyledRegion curRegion_;
	uint to_;
	StyldeSet stdyleSet_;
	RegionSet regionSet_;
	}

	
	{
	styleSdet_ = sset;
	regionSet_ = rset;
	curRegion_.a = f;
	curRegion_.b = t;
	stack_.insertBack(curRegion_);

	regionSetRange = regionSet_.regions[];

	while (!regionSetRange.empty)
	{
	auto r = regionSetRange.front;

	if (r.a >= f)
	{
	// Reached or exceeded the start point
	if (!stack_.empty)
	{
	// f is not within a region and the upcoming region is the current one
	curRegion_.b = r.a;
	popFront(); // prime

	//stack_.insertBack(StyledRegion(r.a, r.b, curRegion_.styleFields));
	//curRegion_.a = r.a;
	//curRegion_.b = r.b;
	//curRegion_.styleFields = styledSet[r.id].computedFields;
	}
	break;
	}
	else if (r.b > f) // implicit r.a < f 
	{
	// Region r overlaps f 
	StyleFields sf = curRegion_.styleFields.overlayUnset(stdyleSet_.styles[r.id].computedFields);
	stack_.insertBack(StyledRegion(r.a, r.b, sf));
	curRegion_.styleFields = sf;
	curRegion_.b = r.b;
	}

	//t					regionsSetRange.popFront();						
	}
	/*t				
	if (_curRegion.b >= t)
	{
	// No regions
	stack_.clear();
	}
	*/
	}

	void popFront()
	{
	/*t
	assert(!empty);

	uint curEnd = curRegion_.b;	
	curRegion_.a = curEnd;

	while (!stack.empty && stack_.back().b == curEnd)
	stack.popBack();

	if (stack.empty) return; // reached the end since the bottom stack Region ends at destination

	// Now the next region is either from the end of curRegion to the
	// end of the region of the top of the stack. Or from the curRegion to
	// the next item in the range.

	if (regionSetRange.empty || stack.back().b <= regionSetRange.front.a)
	{
	// Definitely the stack that should be used for the next region
	curRegion_.styleFields = stack_.back().styleFields;
	curRegion_.b = stack_.back().b;
	return;
	}


	auto r = regionSetRange.front;
	if (r.a == curEnd)
	{
	// The last region is right next to the next region
	regionSetRange.popFront();
	StyleFields sf = curRegion_.styleFields.overlayUnset(stydleSet[r.id].computedFields);
	stack.insertBack(StyledRegion(r.a, r.b, sf));
	curRegion_.b = regionSetRange.empty || regionSetRange.front.a > r.b ? r.b : regionSetRange.front.a;
	}
	else
	{
	curRegion_.b =  r.a;
	}
	curRegion_.styleFields = stack_.back().styleFields;
	*/
	}

	@property 
	{
	bool empty() const 
	{
	return stack_.empty;
	}

	@safe StyledRegion front() nothrow
	{
	//t					assert(!empty);
	return curRegion_;
	}
	}
	}

	return Range(from, to, styledSet, regionSet);
	}
	+/
	void update()
	{
		regionSet.clear();
		regionSet.merge(0, text.length, 0);
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
	
	override void update()
	{
		regionSet.clear();

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
		auto buf = array(text[0..text.length]);

		size_t lastEndIdx = 0;

		foreach (m; match(buf, ctr))
		{
			auto t = templates[m.hit];
			auto begin = m.pre.length;
			auto end = begin + m.hit.length;
			if (begin != lastEndIdx)
				regionSet.set(lastEndIdx, begin, DStyle.other);
			regionSet.set(begin, end, t);
			lastEndIdx = end;
		}

		if (lastEndIdx != text.length)
			regionSet.set(lastEndIdx, text.length, DStyle.other);

	
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

	override void update()
	{
		regionSet.clear();

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
		auto buf = array(text[0..text.length]);

		size_t lastEndIdx = 0;

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
				regionSet.set(lastEndIdx, begin, StyleSheetStyle.other);
			regionSet.set(begin, end, t);
			lastEndIdx = end;
		}

		if (lastEndIdx != text.length)
			regionSet.set(lastEndIdx, text.length, StyleSheetStyle.other);

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

	private void setStyleByRegex(dstring re, Styling styling)
	{
		import std.regex;		
		//auto ctr = regex(r"\s+([a-f0-9]+)\*?\s+ ", "mg");		
		auto ctr = regex(re, "mg");		

		import std.array;
		auto buf = array(text[0..text.length]);

		foreach (m; match(buf, ctr))
		{
			auto begin = m.pre.length + m[1].length;
			auto end = begin + m[2].length;
			regionSet.set(begin, end, styling);
		}
	}

	override void update()
	{
		import std.stdio;
		regionSet.clear();
		regionSet.set(0, text.length, Styling.other);
		setStyleByRegex(r"^()(Changes:|Overview:)\s*$"d, Styling.subTitle);
		setStyleByRegex(r"^()(Release.*?\s+[\.0-9]+\s.*)$"d, Styling.releaseTitle);	
		setStyleByRegex(r"^(\s+)([0-9a-f]+)\s"d, Styling.changeset);
		setStyleByRegex(r"(\s)(\*)\s"d, Styling.bullet);
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
