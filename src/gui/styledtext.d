module gui.styledtext;

import gui.style;
import math.region;
import std.container;

interface TextStyler(Text)
{
	void update(RegionSet rset, Text text);
}

class DefaultStyler(Text) : TextStyler!Text
{
	private static DefaultStyler!Text _the;
	static @property DefaultStyler!Text the()
	{
		if (_the is null)
			_the = new DefaultStyler!Text;
		return _the;
	}

	override void update(RegionSet rset, Text text)
	{
		rset.clear();
		rset.add(0, text.length, 0);
	}
}

class DSourceStyler(Text) : TextStyler!Text
{
	enum defaultID = 0;
	enum declarationID = 1;
	enum typeID = 2;
	
	override void update(RegionSet rset, Text text)
	{
		rset.clear();

		// TODO: use ctRegex
		enum decls = [ 
			"alias"d, "auto", "assert", "class", "const", "enum", "extern", "for", "if", "import", 
			"module", "new", "nothrow", "private", "public", "pure", "return", "safe", "scope", 
			"static", "struct", "template", "this", "union", "unittest", "version", "while" ];
		enum types = [ 
			"byte"d, "char", "dchar", "int", "long", "short", "size_t", "ubyte", "uint", "ulong", 
			"ushort", "void", "wchar" ];
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
			templates[d] = declarationID;
		foreach (t; types)
			templates[t] = typeID;

		import std.array;
		auto buf = array(text[0..text.length]);

		size_t lastEndIdx = 0;

		foreach (m; match(buf, ctr))
		{
			auto t = templates[m.hit];
			auto begin = m.pre.length;
			auto end = begin + m.hit.length;
			if (begin != lastEndIdx)
				rset.add(lastEndIdx, begin, 0);
			rset.add(begin, end, t);
			lastEndIdx = end;
		}

		if (lastEndIdx != text.length)
			rset.add(lastEndIdx, text.length, 0);

	
		return;

		//rset.add(0, text.length, 0);
	//	return;


/*
		// just cycle the first three styles
		foreach (i; 1 .. text.length)
		{
			if (i % 3 == 0)
			{
				rset.add(i - 3, i, (i / 3) % 3);
			}
		}
		*/
	}
		
}
/*
	Heap buildKeywordTokens()
	{
		Token[dstring] templates;
		// = { 
//			"alias" = Token(0, 0, Vec3f(0,1,0))
		//};
		
		// TODO: use ctRegex
		enum decls = [ "alias"d, "auto", "assert", "class", "const", "enum", "extern", "for", "if", "import", "module", "new", "nothrow"
			"private", "public", "pure", "return", "safe", "scope", "static", "struct", "template", "this", "union", "unittest", "version",
			"while" ];
		enum types = [ "byte"d, "char", "dchar", "int", "long", "short", "ubyte", "uint", "ulong", "ushort", "void", "wchar" ];
		dstring re = "(";
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
		re ~= ")";
		
		import std.regex;		
		auto ctr = regex(re, "mg");
		
		foreach (d; decls)
			templates[d] = Token(0, 0, Vec3f(0.3,0.3,1));
		foreach (t; types)
			templates[t] = Token(0, 0, Vec3f(0.3,1,0.3));
		
		dstring[] names = templates.keys();
		Token[] toks;
		
		import std.array;
		auto buf = array(buffer[bufferOffset..buffer.length]);
		
		foreach (m; match(buf, ctr))
		{
			auto t = templates[m.hit];
			t.begin = m.pre.length;
			t.end = t.begin + m.hit.length;
			toks ~= t;

		}

		Heap h;
		h.acquire(toks);
		return h;
	}
	*/
class StyledText(Text)
{
	private TextStyler!Text _textStyler;
	public RegionSet regionSet;
	StyleSet styleSet;
	public Text _text;

	@property
	{
		ref Text text()
		{
			return _text;
		}

		ref TextStyler!Text textStyler()
		{
			return _textStyler;
		}
	}

	this(Text textIn, TextStyler!Text styler /*, StyleSet styleSet */)
	{
		this._textStyler = styler;
		this._text = textIn;
		this.styleSet = null; // styleSet;
		this.regionSet = new RegionSet();
		this.regionSet.add(0, uint.max);
	}
	
	// A Region specifying the composed style of several styles 
	static struct StyledRegion
	{
		Region _reg;
		alias _reg this;
		StyleFields styleFields;
		this(uint a, uint b, StyleFields styleFields)
		{
			this.a = a;
			this.b = b;
			this.styleFields = styleFields;
		}
	}
	
	string styleIDToName(int id)
	{
		if (id == 0)
			return "default";
		else if (id == DSourceStyler!Text.declarationID)
			return "dsource-declaration";
		else if (id == DSourceStyler!Text.typeID)
			return "dsource-type";
		else
			return "default";
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
				StyleSet styleSet_;
				RegionSet regionSet_;
			}
				
			this(uint f, uint t, StyleSet sset, RegionSet rset)
			{
				styleSet_ = sset;
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
							//curRegion_.styleFields = styleSet[r.id].computedFields;
						}
						break;
					}
					else if (r.b > f) // implicit r.a < f 
					{
						// Region r overlaps f 
						StyleFields sf = curRegion_.styleFields.overlay(styleSet_.styles[r.id].computedFields);
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
					StyleFields sf = curRegion_.styleFields.overlay(styleSet[r.id].computedFields);
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
			
		return Range(from, to, styleSet, regionSet);
	}
	+/
	void update(StyleSet styleSet)
	{
		if (_textStyler !is null)
			_textStyler.update(regionSet, _text);
		
		//{
		//    regionSet.clear();
		//    regionSet.add(0, text.length, 0);
		//}
		//else
		//{
//		}
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
	
