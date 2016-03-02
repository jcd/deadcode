module extensions.highlight.d;

import edit.bufferview;
import gui.styledtext;

import math.region;

import std.d.lexer;
import std.d.parser;

import std.range;
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

	override bool canStyleFilename(string name) const pure
	{
		return name.endsWith(".d") || name.endsWith(".di");
	}

    override bool canStyleLanguageName(string name) const pure
    {
        return name == "D";
    }

	//void XXstyleRegion(Text)(Region r, Text text)
	override protected void styleBufferViewRegion(Region r, BufferView txt)
	{
		import std.array;
		import std.conv;
		import extensions.language.d;
		import std.d.lexer;

		if (!(r.b >= 0 && r.b <= txt.length))
			return;
		assert(r.a >= 0 && r.a <= txt.length);

		assert(r.b >= 0 && r.b <= txt.length, format("%s >= 0 && %s <= %s", r.b, r.b, txt.length) );
//		auto buf = array(txt[r.a..r.b]).to!string; // TODO: make request for adding string like support to std.regex

		_regionSet.clear();

		// prefer using existing tokens in buffer and not re-lexing
		int lastEnd = 0;
		// if (auto d = txt.dCodeModel)
		if (false)
		{
			// TODO: The tokens used for the parser does not include white space and attaches comments to decl tokens
			//auto toks = d.tokens;
			//styleBufferViewRegionHelper!(typeof(toks))(toks);
		}
		else
		{
			auto buf = array(txt[0..txt.length]).to!string; // TODO: make request for adding string like support to std.regex

			StringCache cache = StringCache(StringCache.defaultBucketCount);
			LexerConfig config;
			config.stringBehavior = StringBehavior.source;
			auto tokens = byToken(cast(ubyte[])buf, config, &cache);
			lastEnd = styleBufferViewRegionHelper!(typeof(tokens))(tokens);
		}
		if (lastEnd < txt.length)
			set(lastEnd, txt.length - lastEnd, DStyle.other);

	}

	private int styleBufferViewRegionHelper(Range)(ref Range tokens)
	{
		size_t lastEnd = 0;
		while (!tokens.empty)
		{
			auto t = tokens.front;
			tokens.popFront();

			// Untokenable chars
			if (t.index > lastEnd)
			    set(lastEnd, t.index - lastEnd, DStyle.other);

			if (isBasicType(t.type))
			{
				auto s = str(t.type);
				set(t.index, s.length, DStyle.type);
				lastEnd = t.index + s.length;
			}
			else if (isKeyword(t.type))
			{
				auto s = str(t.type);
				set(t.index, s.length, DStyle.keyword);
				lastEnd = t.index + s.length;
			}
			else if (t.type == tok!"identifier")
			{
				bool isString = t.text == "string";
				set(t.index, t.text.length, isString ? DStyle.type : DStyle.identifier);
				lastEnd = t.index + t.text.length;
			}
			else if (t.type == tok!"comment")
			{
				bool isDoc = t.text.startsWith("/**") || t.text.startsWith("/**") || t.text.startsWith("///");
				set(t.index, t.text.length, isDoc ? DStyle.doc : DStyle.comment);
				lastEnd = t.index + t.text.length;
			}
			else if (isStringLiteral(t.type) || t.type == tok!"characterLiteral")
			{
				set(t.index, t.text.length, DStyle.characterLiteral);
				lastEnd = t.index + t.text.length;
			}
			else if (isNumberLiteral(t.type))
			{
				set(t.index, t.text.length, DStyle.numberLiteral);
				lastEnd = t.index + t.text.length;
			}
			else if (isOperator(t.type))
			{
				auto s = str(t.type);
				set(t.index, s.length, DStyle.operator);
				lastEnd = t.index + s.length;
			}
			else if (t.type == tok!"specialTokenSequence" || t.type == tok!"scriptLine")
			{
				set(t.index, t.text.length, DStyle.other);
				lastEnd = t.index + t.text.length;
			}
			else
			{
				set(t.index, t.text.length, DStyle.other);

				// In case of invalid token the text is empty
				if (t.text.length)
					lastEnd = t.index + t.text.length;
			}
		}

		return cast(int)lastEnd;
	}

	void set(size_t a, size_t len, DStyle st)
	{
		// We can simply append since order it guaranteed
            _regionSet ~= Region(cast(int)a, cast(int)(a + len), st);

		//_regionSet.set(a, a + len, st);
		// _regionSet.merge(Region(a, a + len, st));
	}

	protected void xxxstyleBufferViewRegion(Region r, BufferView text)
	{
		import std.stdio;
		writefln("styling %s %s", r.a, r.b);
		// TODO: use ctRegex
		enum decls = [ "@property",
		"alias", "auto", "assert", "break", "case", "class", "const", "default", "do", "else", "enum", "extern", "for", "foreach", "goto", "if", "import", "in", "interface", "is", "!is",
		"module", "new", "nothrow", "null", "override", "package", "private", "public", "pure", "return", "safe", "scope",
		"static", "struct", "switch", "template", "this", "union", "unittest", "version", "while" ];
		enum types = [ "bool",
		"byte", "char", "dchar", "double", "dstring", "float", "int", "long", "short", "size_t", "string", "ubyte", "uint", "ulong",
		"ushort", "void", "wchar", "wstring" ];
		string re = "\\b(";
		string delim = "";
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

		int[string] templates;

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
                            _regionSet.set(cast(int)(offset + lastEndIdx), cast(int)(offset + begin), DStyle.other);
			_regionSet.set(cast(int)(offset + begin), cast(int)(offset + end), t);
			lastEndIdx = end;
		}

		if (lastEndIdx != r.b)
                    _regionSet.set(cast(int)(offset + lastEndIdx), cast(int)(r.b), DStyle.other);

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
