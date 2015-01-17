module extensions.highlight.d;

import core.bufferview;
import gui.styledtext;

import math.region;

import std.d.lexer;
import std.d.parser;

import std.string;

static this()
{	
	register(new DSourceStyler());
}

class DSourceStyler : TextStyler
{
	enum DStyle
	{
		other,
		keyword,
		comment,
		doc,
		characterLiteral,
		numberLiteral,
		operator,
		type,
		identifier,
	};

	override bool canStyle(string name) const pure
	{
		return name.endsWith(".d") || name.endsWith(".di");
	}

	//void XXstyleRegion(Text)(Region r, Text text)
	override protected void styleBufferViewRegion(Region r, BufferView txt)
	{
		import std.array;
		import std.conv;
		if (!(r.b >= 0 && r.b <= txt.length))
			return;
		assert(r.a >= 0 && r.a <= txt.length);

		assert(r.b >= 0 && r.b <= txt.length, format("%s >= 0 && %s <= %s", r.b, r.b, txt.length) );
//		auto buf = array(txt[r.a..r.b]).to!string; // TODO: make request for adding string like support to std.regex
		
		_regionSet.clear();
		auto buf = array(txt[0..txt.length]).to!string; // TODO: make request for adding string like support to std.regex

		StringCache cache = StringCache(StringCache.defaultBucketCount);
		LexerConfig config;
		config.stringBehavior = StringBehavior.source;
		auto tokens = byToken(cast(ubyte[])buf, config, &cache);

		while (!tokens.empty)
		{
			auto t = tokens.front;
			tokens.popFront();

			if (isBasicType(t.type))
			{
				auto s = str(t.type);
				set(t.index, s.length, DStyle.type);
			}
			else if (isKeyword(t.type))
			{
				auto s = str(t.type);
				set(t.index, s.length, DStyle.keyword);
			}
			else if (t.type == tok!"identifier")
			{
				bool isString = t.text == "string";
				set(t.index, t.text.length, isString ? DStyle.type : DStyle.identifier);
			}
			else if (t.type == tok!"comment")
			{
				bool isDoc = t.text.startsWith("/**") || t.text.startsWith("/**") || t.text.startsWith("///");
				set(t.index, t.text.length, isDoc ? DStyle.doc : DStyle.comment);
			}
			else if (isStringLiteral(t.type) || t.type == tok!"characterLiteral")
				set(t.index, t.text.length, DStyle.characterLiteral);
			else if (isNumberLiteral(t.type))
				set(t.index, t.text.length, DStyle.numberLiteral);
			else if (isOperator(t.type))
			{
				auto s = str(t.type);
				set(t.index, s.length, DStyle.operator);
			}
			else if (t.type == tok!"specialTokenSequence" || t.type == tok!"scriptLine")
				set(t.index, t.text.length, DStyle.other);
			else
				set(t.index, t.text.length, DStyle.other);
		}
	}

	void set(int a, int len, DStyle st)
	{
		_regionSet.set(a, a + len, st);
	}

	protected void xxxstyleBufferViewRegion(Region r, BufferView text)
	{
		import std.stdio;
		writefln("styling %s %s", r.a, r.b);
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
			templates[d] = DStyle.other;
		foreach (t; types)
			templates[t] = DStyle.type;

		import std.array;
		assert(r.a >= 0 && r.a <= text.length);
		assert(r.b >= 0 && r.b <= text.length);
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
			case DStyle.keyword:
				return "dsource-keyword";
			case DStyle.comment:
				return "dsource-comment";
			case DStyle.doc:
				return "dsource-doc";
			case DStyle.characterLiteral:
				return "dsource-character-literal";
			case DStyle.numberLiteral:
				return "dsource-number-literal";
			case DStyle.operator:
				return "dsource-operator";
			case DStyle.type:
				return "dsource-type";
			case DStyle.identifier:
				return "dsource-identifier";
		}
	}
}