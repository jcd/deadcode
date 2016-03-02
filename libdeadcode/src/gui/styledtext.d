module gui.styledtext;

import edit.bufferview;
import edit.buffer : InvalidIndex;
import gui.style;
import math.region;
import std.container;
import dccore.signals;
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

	TextStyler hasTextStyler(Text)(BufferView bv)
	{
		TextStyler styler;
        string name = bv.name;
		foreach (s; s_Stylers)
		{
			if (s.canStyleFilename(name))
                return true;
		}
        return false;
    }

	TextStyler createTextStyler(Text)(Text text, string name)
	{
		TextStyler styler;

		if (text.codeModel !is null)
        {
            string languageName = text.codeModel.name;
            foreach (s; s_Stylers)
		    {
                if (s.canStyleLanguageName(languageName))
                {
                    styler = instantiate(s);
                }
            }
        }

        if (styler is null)
        {
		    foreach (s; s_Stylers)
		    {
			    if (s.canStyleFilename(name))
			    {
				    styler = instantiate(s);
				    break;
			    }
		    }

		    if (styler is null)
			    styler = new TextStyler();
        }

		static if ( is(Text : BufferView) )
		{
			text.onChanged.connect(&styler.textChangedCallback);
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
	bool canStyleFilename(string name) const pure
	{
		return true;
	}

    bool canStyleLanguageName(string name) const pure
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
	protected void textChangedCallback(BufferView b, int from, int count, bool addOrRemove)
	{
		if (addOrRemove)
        {
            // Inserts
            // Update region set
           _regionSet.entriesInserted(from, count);

            import std.stdio;
		    //writefln("Insert styler %s from %s", str.length, from);
		    scheduleRegion(Region(from, from + count));
        }
        else
        {
            // Removes
            // Update region set
            _regionSet.entriesRemoved(from, count);

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
            r = r.clip(0, cast(int)text.length);

		// Look for the preceeding and succeeding whitespace and form a region using that
		// to use for restyling.
		// Restyle entire lines
		static if ( is(Text : BufferView) )
		{
			int a = text.buffer.findOneOfReverse(r.a, "\r\n");
			int b = text.buffer.findOneOf(r.b, "\r\n");
			a = a == InvalidIndex ? 0 : a;
			b = b == InvalidIndex ? text.length : b;
			styleRegion(Region(a, b), text);
			//styleRegion(Region(0, text.length));
		}
		else
		{
                    styleRegion(Region(0, cast(int)text.length), text);
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

	override bool canStyleFilename(string name) const pure
	{
		return name.endsWith(".stylesheet");
	}

    override bool canStyleLanguageName(string name) const pure
    {
        return name == "CSS";
    }

	protected override void styleBufferViewRegion(Region r, BufferView text)
	{
		// TODO: use ctRegex
		enum keys = [ "background", "color", "font", "padding", "transition", "position",
					  "left", "right", "top", "bottom", "width", "height", "offset" ];
		enum types = [ "#", "\\\\." ];

		string re = "\\b(";
		string delim = "";
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

		int[string] templates;

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
                            _regionSet.merge(cast(int)(offset + lastEndIdx), cast(int)(offset + begin), StyleSheetStyle.other);
			_regionSet.merge(cast(int)(offset + begin), cast(int)(offset + end), t);
			lastEndIdx = end;
		}

		if (lastEndIdx != text.length)
                    _regionSet.merge(cast(int)(offset + lastEndIdx), r.b, StyleSheetStyle.other);

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

	override bool canStyleFilename(string name) const pure
	{
		return name.toLower.startsWith("changelog");
	}

    override bool canStyleLanguageName(string name) const pure
    {
        return false;
    }

	private void setStyleByRegex(Text)(Region r, string re, Styling styling, Text text)
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
			_regionSet.merge(cast(int)(offset + begin), cast(int)(offset + end), styling);
		}
	}

	protected override void styleBufferViewRegion(Region r, BufferView text)
	{
		import std.stdio;
		_regionSet.set(r.a, r.b, Styling.other);
		setStyleByRegex(r, r"^()(Changes:|Overview:)\s*$", Styling.subTitle, text);
		setStyleByRegex(r, r"^()(Release.*?\s+[\.0-9]+\s.*)$", Styling.releaseTitle, text);
		setStyleByRegex(r, r"^(\s+)([0-9a-f]+)\s", Styling.changeset, text);
		setStyleByRegex(r, r"(\s)(\*)\s", Styling.bullet, text);
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
