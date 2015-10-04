module gui.style.stylesheet;

import core.uri;

import gui.resource;

import gui.resources.material;
import gui.resources.font : Font, FontManager;

import gui.style.manager;
import gui.style.parser;
import gui.style.style;
import gui.style.types;

import std.algorithm;
import std.range;
import std.typecons;

version (unittest)
{
    import test;
    mixin registerUnittests;


	class TestStylable : Stylable
	{
		string n;
		Stylable _parent;

		@property
		{
			string name() const pure @safe { return n; }
			void name(string nn) { n = nn; }

			ubyte matchStylable(string stylableName) const pure nothrow @safe { return matchStylableImpl(this, stylableName); }
			const(string[]) classes() const pure nothrow @safe { return [""]; }
			bool hasKeyboardFocus() const pure nothrow @safe { return false; }
			bool isMouseOver() const pure nothrow @safe { return false; }
			bool isMouseDown() const pure nothrow @safe { return false; }
            bool isVisible() const nothrow @safe { return true; }
			Stylable parent() pure nothrow @safe { return _parent; }
		}

		this(Stylable p)
		{
			_parent = p;
		}
	}
}

enum maxStylableNameMatchLevel = cast(ubyte)10;

ubyte matchStylableImpl(S)(S styleable, string stylableName) pure nothrow @safe
{
	static bool matchName(string ciname, string stylableName) nothrow
	{
		return ciname.length > stylableName.length && ciname[$ - stylableName.length - 1] == '.' && ciname[$-stylableName.length..$] == stylableName;
	}

	auto ci = styleable.classinfo;
    ubyte level = 1;
	// Match class with StylableTypeName or descendants
	while (ci !is null && !matchName(ci.name, stylableName))
    {
		ci = ci.base;
        level++;
    }
    //assert(level < 11);
	return ci is null ? 0 : cast(ubyte)(maxStylableNameMatchLevel - level + 1);
}

interface Stylable
{
	@property
	{
		string name() const pure @safe;
		ubyte matchStylable(string stylableName) const pure nothrow @safe;
		const(string[]) classes() const pure nothrow @safe;
		bool hasKeyboardFocus() const pure nothrow @safe;
		bool isMouseOver() const pure nothrow @safe;
		bool isMouseDown() const pure nothrow @safe;
        bool isVisible() const nothrow @safe;
		Stylable parent() pure nothrow @safe;
	}
}

class StylableSelector
{
	string stylableTypeName;
	bool fullyQualifiedType;
	string stylableName;
	string[] classNames;

	enum PseudoClass : byte
	{
		none,
		hover,
		active,
		disabled,
		focus,
        visible
	}

	PseudoClass pseudoClass;

	this(string wtype, string wname, string[] cnames = null, string pseudoName = null)
	{
		stylableTypeName = wtype == "*" ? null : wtype;
		fullyQualifiedType = false;
		stylableName = wname;
		classNames = cnames;
		switch (pseudoName)
		{
			case "hover":
				pseudoClass = PseudoClass.hover;
				break;
			case "active":
				pseudoClass = PseudoClass.active;
				break;
			case "disabled":
				pseudoClass = PseudoClass.disabled;
				break;
			case "focus":
				pseudoClass = PseudoClass.focus;
				break;
			case "visible":
				pseudoClass = PseudoClass.visible;
				break;
			default:
				pseudoClass = PseudoClass.none;
				break;
		}
	}

	Tuple!(Stylable, ubyte) match(Stylable w)
	{
		auto nameMatch = stylableName.empty ? true : stylableName == w.name;
		ubyte typeMatchLevel = stylableTypeName.empty ? 1 : 0;
		const(string[]) widgetClassNames = w.classes;

		auto classMatch = true;
        foreach (cn; classNames)
            classMatch = classMatch && widgetClassNames.canFind(cn);

		auto pseudoMatch = true;

		final switch (pseudoClass)
		{
			case PseudoClass.none:
				break;
			case PseudoClass.hover:
				pseudoMatch = w.isMouseOver();
				break;
			case PseudoClass.active:
				pseudoMatch = w.isMouseDown();
				break;
			case PseudoClass.disabled:
				pseudoMatch = false; // TODO: implement
				break;
			case PseudoClass.focus:
				pseudoMatch = w.hasKeyboardFocus();
				break;
			case PseudoClass.visible:
				pseudoMatch = w.isVisible();
				break;
		}

		if (!(nameMatch && classMatch && pseudoMatch))
			return tuple(w, cast(ubyte)0);

		if (typeMatchLevel == 0)
			typeMatchLevel = w.matchStylable(stylableTypeName);

		return tuple(w, typeMatchLevel);
	}
}

unittest
{
	auto testWin = createTestWindow();

	// Wildcard match
	auto w1 = new TestStylable(testWin);
	auto sel1 = new StylableSelector(null, null);
	AssertIs(sel1.match(w1)[0], w1, "Wildcard StylableSelector matches unnamed");
	w1.name = "testStylable";
	AssertIs(sel1.match(w1)[0], w1, "Wildcard StylableSelector matches named");

	// Name match
	auto w2 = new TestStylable(testWin);
	auto sel2 = new StylableSelector(null, "testStylable");
	Assert(sel2.match(w2)[1], 0, "TypeWildcard StylableSelector does not match unnamed");
	w2.name = "testStylablexx";
	Assert(sel2.match(w2)[1], 0, "TypeWildcard StylableSelector does not match mismatching name");
	w2.name = "testStylable";
	AssertIs(sel2.match(w2)[0], w2, "TypeWildcard StylableSelector matches name");

	// Type match
	auto w3 = new TestStylable(testWin);
	auto sel3 = new StylableSelector("TestStylable",null);
	AssertIs(sel3.match(w3)[0], w3, "NameWildcard StylableSelector matches direct Stylable");
	auto sel4 = new StylableSelector("StylableX",null);
	Assert(sel4.match(w3)[1], 0, "NameWildcard StylableSelector does not match direct StylableX");

	class TestStylable1 : TestStylable { this(Stylable w) { super(w); } }
	class TestStylable2 : TestStylable1 { this(Stylable w) { super(w); } }

	auto w4 = new TestStylable2(testWin);
	auto sel5 = new StylableSelector("TestStylable",null);
	AssertIs(sel5.match(w4)[0], w4, "NameWildcard StylableSelector matches decendant of Stylable");
	auto sel6 = new StylableSelector("TestStylable1",null);
	AssertIs(sel6.match(w4)[0], w4, "NameWildcard StylableSelector matches decendant of TestStylable1");
	auto sel7 = new StylableSelector("TestStylable2",null);
	AssertIs(sel7.match(w4)[0], w4, "NameWildcard StylableSelector matches direct TestStylable2");
}

class ChildSelector : StylableSelector
{
	this(string tname, string wname, string[] cnames = null, string pseudoName = null)
	{
		super(tname, wname, cnames, pseudoName);
	}

	override Tuple!(Stylable, ubyte) match(Stylable w)
	{
		auto p = w.parent;
		if (p is null)
			return tuple(w, cast(ubyte)0);

        return super.match(p);
	}
}

unittest
{
	auto win = createTestWindow();
	auto w1 = new TestStylable(win);
	w1.name = "testParent";
	auto w2 = new TestStylable(w1);
	w2.name = "testChild";
	auto w3 = new TestStylable(w2);
	w3.name = "testGrandChild";

	auto sel = new ChildSelector(null,"testParent");
	Assert(sel.match(w1)[1], 0, "Root Stylable does not match ChildSelector");
	AssertIs(sel.match(w2)[0], w1, "Child of root Stylable matches ChildSelector");
	Assert(sel.match(w3)[1], 0, "Grandchild of root Stylable does not match ChildSelector");
}

class DescendantSelector : StylableSelector
{
	this(string tname, string wname, string[] cnames = null, string pseudoName = null)
	{
		super(tname, wname, cnames, pseudoName);
	}

	override Tuple!(Stylable, ubyte) match(Stylable w)
	{
		auto p = w.parent;
		while (p !is null)
		{
			auto res = super.match(p);
			if (res[1])
                return res;
            else
                p = p.parent;
		}
		return tuple(w, cast(ubyte)0);
	}
}

unittest
{
	auto win = createTestWindow();
	auto w1 = new TestStylable(win);
	w1.name = "testParent";
	auto w2 = new TestStylable(w1);
	w2.name = "testChild";
	auto w3 = new TestStylable(w2);
	w3.name = "testGrandChild";

	auto sel = new DescendantSelector(null,"testParent");
	Assert(sel.match(w1)[1], 0, "Root Stylable does not match DescendantSelector");
	AssertIs(sel.match(w2)[0], w1, "Child of root Stylable matches DescendantSelector");
	AssertIs(sel.match(w3)[0], w1, "Grandchild of root Stylable matches DescendantSelector");
}

/*
class SiblingSelectorOperator: SelectorOperator
{

}
*/

alias StylableSelector[] Selectors;

class Rule
{
	//
	// selector1 operator1 selector2 operator2 selector3
	// ie.
	// operator.length == selectors.lenght - 1
	//

	Selectors selectors;
	Style style;

	//
	// http://www.w3.org/TR/CSS21/cascade.html#specificity
	// 0xFF_00_00_00 mask is the count of named selectors
	// 0x00_FF_00_00 mask is the sum of psuedo class selectors, class selectors and attribute selectors
	// 0x00_00_FF_00 mask is the sum of Stylable and subStylable selectors
	//
	//uint specificity;

	// Returns the actual specifity for the match taking into consideration
    // the class hierarchy matchLevel
    uint match(Stylable w)
	{
        uint specificity = 0;

		if (selectors.empty)
			return 0;

        //if (specificity == 0)
        //    calculateSpecificity();
		for (int i = cast(int)selectors.length - 1; i >= 0; i--)
        {
            auto s = selectors[i];
            Tuple!(Stylable, ubyte) matchLevel = s.match(w);
            if (matchLevel[1] == 0)
                return 0;

            // Change the specificity
			if (s.stylableName !is null)
				specificity += 0x01_00_00_00;
			if (s.classNames.length)
				specificity += 0x00_01_00_00 * s.classNames.length;
			if (s.pseudoClass != StylableSelector.PseudoClass.none)
				specificity += 0x00_01_00_00;
			//if (s.stylableTypeName !is null)

            // The greater the ancestor in the inheritance hierarchy the lower the specificity
            specificity += 0x00_00_01_00 * matchLevel[1];
            w = matchLevel[0];
        }

        return specificity;
	}

    //void calculateSpecificity()
    //{
    //    foreach (s;	selectors)
    //    {
    //        if (s.stylableName !is null)
    //            specificity += 0x01_00_00_00;
    //        if (s.className !is null)
    //            specificity += 0x00_01_00_00;
    //        if (s.pseudoClass != StylableSelector.PseudoClass.none)
    //            specificity += 0x00_01_00_00;
    //        if (s.stylableTypeName !is null)
    //            specificity += 0x00_00_01_00;
    //    }
    //}
}

unittest
{
	auto testWin = createTestWindow();
	auto sel1 = new Rule;
	sel1.selectors ~= new StylableSelector("TestStylable", null);
	auto w1 = new TestStylable(testWin);
	w1.name = "testParent";
	auto w2 = new TestStylable(w1);
	w2.name = "testChild";

	Assert(sel1.match(w1), 2560, "Wildcard selector matches single");

	Selectors ws = [new ChildSelector(null, "testParent")];
	sel1.selectors =  ws ~ sel1.selectors;
	Assert(sel1.match(w1), 0, "Child selector on parent does not match");
	Assert(sel1.match(w2), 16780032, "Child selector on child does not match");
}

class StyleSheet : Resource!StyleSheet
{
	private
	{
		//FontManager _fontManager;  // TODO: No need for managers I think. Let the ones why create styles know about that
		//MaterialManager _materialManager;

        static class NamedStylable : Stylable
        {
            private string _styleName;

            @property
            {
                string name() const pure @safe { return null; }
                ubyte matchStylable(string stylableName) const pure nothrow @safe { return stylableName == _styleName ? 10 : 0; }
                const(string[]) classes() const pure nothrow @safe { return null; }
                bool hasKeyboardFocus() const pure nothrow @safe { return false; }
                bool isMouseOver() const pure nothrow @safe { return false; }
                bool isMouseDown() const pure nothrow @safe { return false; }
                bool isVisible() const nothrow @safe { return true; }
                Stylable parent() pure nothrow @safe { return null; }

                @property void styleName(string n)
                {
                    _styleName = n;
                }
            }

            this(string styleName)
            {
                _styleName = styleName;
            }
        }

        NamedStylable _tempStylable;
	}

	Rule[] rules;
	Animation[] animations;

	alias size_t[] RuleSetID;
	Style[RuleSetID] styleCache;

    this()
    {
        _tempStylable = new NamedStylable("");
    }

	void clear()
	{
		rules.length = 0;
		styleCache = null;
	}

	void clearCache()
	{
	}

	void swap(StyleSheet other)
	{
		Rule[] r = rules;
		Style[RuleSetID] sc = styleCache;
		rules = other.rules;
		styleCache = other.styleCache;
		other.rules = r;
		other.styleCache = sc;
	}

    Style getStyle(string styleName)
    {
        _tempStylable.styleName = styleName;
        return getStyle(_tempStylable);
    }

	Style getStyle(Stylable w)
	{
		// Get matching selectors
		struct Match
		{
			Rule rule;
			int order; // order in sheet for conflict resolution on selectors with same specificity
            uint specificity;
		}

		static Match[] matches;
		static RuleSetID matchedRules;
        matches.length = 0;
        matchedRules.length = 0;
        assumeSafeAppend(matches);
        assumeSafeAppend(matchedRules);
		foreach (i, s; rules)
		{
            uint specificity = s.match(w);
			if (specificity)
			{
                            matches ~= Match(s, cast(int)i, specificity);
				matchedRules ~= s.toHash();
			}
		}

		//if (classNames.length != 0 && classNames[0] == "commandEntryField" )
		//if (w.name == "commandEntryField" || w.name == "command")
		//{
		//    string wname = w.name;
		//    int a = 3;
		//}

		if (matches.empty)
			return null;

		if (matches.length == 1)
			return matches[0].rule.style;

		// Get cached or create style for this selector set (cascading)
		Style* cachedStyle = matchedRules in styleCache;
		if (cachedStyle)
		    return *cachedStyle;

		//std.stdio.writeln("hashes ", w.name, " ", matchedRules);

		// Resolve conflicts if any
		import std.algorithm;
		auto rng = matches.sort!((a,b) => a.specificity > b.specificity || (a.specificity == b.specificity && a.order >	b.order))();

		Style st = new Style(this); // createStyle(matching[0].style);
		// TODO: prime background material to make it unique
		StyleSheetManager mgr = cast(StyleSheetManager)manager;
		version(dunittest) {}
		else
		{
			if (mgr !is null)
				st.background = mgr.materialManager.declare(CustomMaterialLoader.singleton);
		}

		styleCache[matchedRules.idup] = st;

        string stName = w.name;

		uint lastSpecificity = uint.max;
		foreach (m; rng)
		{
            //if (lastSpecificity != m.specificity)
            //{
				st.overlay(m.rule.style);
				lastSpecificity = m.specificity;
			// }
		}
		st.rebuildTransitionCache();
		return st;
	}

	Style createStyle(Style from)
	{
		auto st = from.clone();
		st.styleSheet = this;
		return st;
	}

}

unittest
{
	auto win = createTestWindow();
	auto w1 = new TestStylable(win);
	w1.name = "testParent";
	auto w2 = new TestStylable(w1);
	w2.name = "testChild";
	auto w3 = new TestStylable(w2);
	w3.name = "testGrandChild";

	auto sheet = new StyleSheet;

	// StylableSelector
	Rule sel1 = new Rule;
	sel1.selectors ~= new StylableSelector("TestStylable", null);
	sel1.style = new Style(sheet);
	sel1.style.color = Color.red;
	// sel1.style.compute();
	sheet.rules ~= sel1;

	Assert(sheet.getStyle(w1).color, Color.red, "Selector(Stylable) w1 has color red");
	Assert(sheet.getStyle(w2).color, Color.red, "Selector(Stylable) w2 has color red");
	Assert(sheet.getStyle(w3).color, Color.red, "Selector(Stylable) w2 has color red");

	// ChildSelector
	Rule sel2 = new Rule;
	sel2.selectors ~= new ChildSelector(null,"testParent");
	sel2.style = new Style(sheet);
	sel2.style.color = Color.green;
	//sel2.style.compute();
	sheet.rules ~= sel2;

	Assert(sheet.getStyle(w1).color, Color.red, "Selector(#testParent Stylable) w1 has color red");
	Assert(sheet.getStyle(w2).color, Color.green, "Selector(#testParent Stylable) w2 has color green");
	Assert(sheet.getStyle(w3).color, Color.red, "Selector(#testParent Stylable) w3 has color red");

	// DescendantSelector
	Rule sel3 = new Rule;
	sel3.selectors ~= new DescendantSelector(null,"testParent");
	sel3.style = new Style(sheet);
	sel3.style.color = Color.blue;
	//sel3.style.compute();
	sheet.rules ~= sel3;

	Assert(sheet.getStyle(w1).color, Color.red, "Selector(#testParent Stylable) w1 has color red");
	Assert(sheet.getStyle(w2).color, Color.blue, "Selector(#testParent Stylable) w2 has color blue");
	Assert(sheet.getStyle(w3).color, Color.blue, "Selector(#testParent Stylable) w3 has color blue");
}

class StyleSheetSerializer : ResourceSerializer!StyleSheet
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

	override bool canRead() pure const nothrow { return true; }

	override bool canHandle(URI uri)
	{
		return uri.extension == ".stylesheet";
	}

	override void deserialize(StyleSheet res, string str)
	{
		URI baseURI = res.uri.dirName;
		scope StyleSheet tmpSheet = new StyleSheet;
		tmpSheet.manager = res.manager;
		auto parser = new StyleSheetParser(str, tmpSheet, baseURI, fontManager, materialManager);
		if (parser.parse())
		{
			res.swap(tmpSheet);
			tmpSheet.clear();
			res.manager.onResourceLoaded(res, this);
		}
		else
		{
			import std.stdio;
			foreach (m; parser.errors)
				writeln(m.message);
		}
	}

	private MaterialManager _materialManager;
	private FontManager _fontManager;
}
