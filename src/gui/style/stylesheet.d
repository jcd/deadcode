module gui.style.stylesheet;

import core.uri;

import gui.resource;

import gui.resources.material;
import gui.resources.font : Font, FontManager;

import gui.style.manager;
import gui.style.parser;
import gui.style.style;
import gui.style.types;

version (unittest) import test;

import gui.widget;

import std.algorithm;
import std.range;

class WidgetSelector
{
	string widgetTypeName;
	bool fullyQualifiedType;
	string widgetName;
	string className;

	enum PseudoClass : byte
	{
		none,
		hover,
		active,
		disabled,
		focus
	}

	PseudoClass pseudoClass;

	this(string wtype, string wname, string cname = null, string pseudoName = null)
	{
		widgetTypeName = wtype == "*" ? null : wtype;
		fullyQualifiedType = false;
		widgetName = wname;
		className = cname;
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
			default:
				pseudoClass = PseudoClass.none;
				break;
		}
	}

	Widget match(Widget w, string[] classNames)
	{
		auto nameMatch = widgetName.empty ? true : widgetName == w.name;
		auto typeMatch = widgetTypeName.empty;
		auto classMatch = className.empty ? true : classNames.canFind(className);
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
				pseudoMatch = false; // TODO: implement
				break;
		}

		if (!(nameMatch && classMatch && pseudoMatch))
			return null;

		if (!typeMatch)
		{
			auto ci = w.classinfo;
			// Match class with widgetTypeName or descendants
			while (ci !is null && !matchName(ci))
				ci = ci.base;
			typeMatch = ci !is null;
		}
		return typeMatch ? w : null;
	}

	private bool matchName(TypeInfo_Class ci)
	{
		import std.string;
		string ciname = ci.name;
		if (!fullyQualifiedType)
		{
			auto idx = ciname.lastIndexOf('.');
			if (idx != -1)
				ciname = ciname[idx+1..$];
		}
		return ciname == widgetTypeName;
	}

}

unittest
{
	auto testWin = createTestWindow();

	// Wildcard match
	auto w1 = new Widget(testWin);
	auto sel1 = new WidgetSelector(null, null);
	AssertIs(sel1.match(w1, null), w1, "Wildcard WidgetSelector matches unnamed");
	w1.name = "testWidget";
	AssertIs(sel1.match(w1, null), w1, "Wildcard WidgetSelector matches named");

	// Name match
	auto w2 = new Widget(testWin);
	auto sel2 = new WidgetSelector(null, "testWidget");
	AssertIsNot(sel2.match(w2, null), w2, "TypeWildcard WidgetSelector does not match unnamed");
	w2.name = "testWidgetxx";
	AssertIsNot(sel2.match(w2, null), w2, "TypeWildcard WidgetSelector does not match mismatching name");
	w2.name = "testWidget";
	AssertIs(sel2.match(w2, null), w2, "TypeWildcard WidgetSelector matches name");

	// Type match
	auto w3 = new Widget(testWin);
	auto sel3 = new WidgetSelector("Widget",null);
	AssertIs(sel3.match(w3, null), w3, "NameWildcard WidgetSelector matches direct Widget");
	auto sel4 = new WidgetSelector("WidgetX",null);
	AssertIsNot(sel4.match(w3, null), w3, "NameWildcard WidgetSelector does not match direct WidgetX");

	class TestWidget1 : Widget { this(Widget w) { super(w); } }
	class TestWidget2 : TestWidget1 { this(Widget w) { super(w); } }

	auto w4 = new TestWidget2(testWin);
	auto sel5 = new WidgetSelector("Widget",null);
	AssertIs(sel5.match(w4, null), w4, "NameWildcard WidgetSelector matches decendant of Widget");
	auto sel6 = new WidgetSelector("TestWidget1",null);
	AssertIs(sel6.match(w4, null), w4, "NameWildcard WidgetSelector matches decendant of TestWidget1");
	auto sel7 = new WidgetSelector("TestWidget2",null);
	AssertIs(sel7.match(w4, null), w4, "NameWildcard WidgetSelector matches direct TestWidget2");
}

class ChildSelector : WidgetSelector
{
	this(string tname, string wname, string cname = null, string pseudoName = null)
	{
		super(tname, wname, cname, pseudoName);
	}

	override Widget match(Widget w, string[] classNames)
	{
		auto p = w.parent;
		if (p is null || super.match(p, classNames) is null)
			return null;

		return p;
	}
}

unittest
{
	auto win = createTestWindow();
	auto w1 = new Widget(win);
	w1.name = "testParent";
	auto w2 = new Widget(w1);
	w2.name = "testChild";
	auto w3 = new Widget(w2);
	w3.name = "testGrandChild";

	auto sel = new ChildSelector(null,"testParent");
	AssertIsNot(sel.match(w1, null), win, "Root widget does not match ChildSelector");
	AssertIs(sel.match(w2, null), w1, "Child of root widget matches ChildSelector");
	AssertIsNot(sel.match(w3, null), w2, "Grandchild of root widget does not match ChildSelector");
}

class DescendantSelector : WidgetSelector
{
	this(string tname, string wname, string cname = null, string pseudoName = null)
	{
		super(tname, wname, cname, pseudoName);
	}

	override Widget match(Widget w, string[] classNames)
	{
		auto p = w.parent;
		while (p !is null)
		{
			Widget res = super.match(p, classNames);
			if (res is null)
				p = p.parent;
			else
				return res;
		}
		return null;
	}
}

unittest
{
	auto win = createTestWindow();
	auto w1 = new Widget(win);
	w1.name = "testParent";
	auto w2 = new Widget(w1);
	w2.name = "testChild";
	auto w3 = new Widget(w2);
	w3.name = "testGrandChild";

	auto sel = new DescendantSelector(null,"testParent");
	AssertIsNot(sel.match(w1, null), win, "Root widget does not match DescendantSelector");
	AssertIs(sel.match(w2, null), w1, "Child of root widget matches DescendantSelector");
	AssertIs(sel.match(w3, null), w1, "Grandchild of root widget matches DescendantSelector");
}

/*
class SiblingSelectorOperator: SelectorOperator
{

}
*/

class Rule
{
	//
	// widgetSelector1 operator1 widgetSelector2 operator2 widgetSelector3
	// ie. 
	// operator.length == widgetSelectors.lenght - 1
	//
	WidgetSelector[] widgetSelectors;
	Style style;

	// 
	// http://www.w3.org/TR/CSS21/cascade.html#specificity
	// 0xFF_00_00_00 mask is the count of named selectors
	// 0x00_FF_00_00 mask is the sum of psuedo class selectors, class selectors and attribute selectors
	// 0x00_00_FF_00 mask is the sum of widget and subwidget selectors
	//
	uint specificity;

	bool match(Widget w, string[] classNames)
	{
		if (specificity == 0)
			calculateSpecificity();

		if (widgetSelectors.empty)
			return true;

		for (int i = widgetSelectors.length - 1; w !is null && i >= 0; i--)
			w = widgetSelectors[i].match(w, classNames);

		return w !is null;
	}

	void calculateSpecificity()
	{
		foreach (s;	widgetSelectors)
		{
			if (s.widgetName !is null)
				specificity += 0x01_00_00_00;
			if (s.className !is null)
				specificity += 0x00_01_00_00;
			if (s.pseudoClass != WidgetSelector.PseudoClass.none)
				specificity += 0x00_01_00_00;
			if (s.widgetTypeName !is null)
				specificity += 0x00_00_01_00;
		}
	}
}

unittest
{
	auto testWin = createTestWindow();
	auto sel1 = new Rule;
	sel1.widgetSelectors ~= new WidgetSelector("Widget", null);
	auto w1 = new Widget(testWin);
	w1.name = "testParent";
	auto w2 = new Widget(w1);
	w2.name = "testChild";

	Assert(sel1.match(w1, null), "Wildcard selector matches single");

	WidgetSelector[] ws = [new ChildSelector(null, "testParent")];
	sel1.widgetSelectors =  ws ~ sel1.widgetSelectors;
	Assert(!sel1.match(w1, null), "Child selector on parent does not match");
	Assert(sel1.match(w2, null), "Child selector on child does not match");
}

class StyleSheet : Resource!StyleSheet
{
	private 
	{
		//FontManager _fontManager;  // TODO: No need for managers I think. Let the ones why create styles know about that
		//MaterialManager _materialManager;
	}

	Rule[] rules;
	Animation[] animations;

	alias immutable(size_t)[] RuleSetID;
	Style[RuleSetID] styleCache;

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

	Style getStyleForWidget(Widget w, string[] classNames = null)
	{
		// Get matching selectors
		struct Match
		{
			Rule rule;
			int order; // order in sheet for conflict resolution on selectors with same specificity
		}

		Match[] matches;
		RuleSetID matchedRules;
		foreach (i, s; rules)
		{
			if (s.match(w, classNames))
			{
				matches ~= Match(s, i);
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
		auto rng = matches.sort!((a,b) => a.rule.specificity > b.rule.specificity || (a.rule.specificity == b.rule.specificity && a.order >	b.order))();

		Style st = new Style(this); // createStyle(matching[0].style);
		// TODO: prime background material to make it unique
		StyleSheetManager mgr = cast(StyleSheetManager)manager;
		version(dunittest) {}
		else 
		{
			st.background = mgr.materialManager.declare(CustomMaterialLoader.singleton);
		}

		styleCache[matchedRules] = st;

		uint lastSpecificity = uint.max;
		foreach (m; rng)
		{
			if (lastSpecificity != m.rule.specificity)
			{
				st.overlay(m.rule.style);
				lastSpecificity = m.rule.specificity;
			}
		}

		return st;
	}

	Style createStyle(Style from)
	{
		auto st = new Style(this);
		st._fields = from._fields;
		return st;
	}

}

unittest
{
	auto win = createTestWindow();
	auto w1 = new Widget(win);
	w1.name = "testParent";
	auto w2 = new Widget(w1);
	w2.name = "testChild";
	auto w3 = new Widget(w2);
	w3.name = "testGrandChild";

	auto sheet = new StyleSheet;

	// WidgetSelector
	Rule sel1 = new Rule;
	sel1.widgetSelectors ~= new WidgetSelector("Widget", null);
	sel1.style = new Style(sheet);
	sel1.style.color = Color.red;
	// sel1.style.compute();		
	sheet.rules ~= sel1;

	Assert(sheet.getStyleForWidget(w1).color, Color.red, "Selector(Widget) w1 has color red");
	Assert(sheet.getStyleForWidget(w2).color, Color.red, "Selector(Widget) w2 has color red");
	Assert(sheet.getStyleForWidget(w3).color, Color.red, "Selector(Widget) w2 has color red");

	// ChildSelector
	Rule sel2 = new Rule;
	sel2.widgetSelectors ~= new ChildSelector(null,"testParent");
	sel2.style = new Style(sheet);
	sel2.style.color = Color.green;
	//sel2.style.compute();
	sheet.rules ~= sel2;

	Assert(sheet.getStyleForWidget(w1).color, Color.red, "Selector(#testParent Widget) w1 has color red");
	Assert(sheet.getStyleForWidget(w2).color, Color.green, "Selector(#testParent Widget) w2 has color green");
	Assert(sheet.getStyleForWidget(w3).color, Color.red, "Selector(#testParent Widget) w3 has color red");

	// DescendantSelector
	Rule sel3 = new Rule;
	sel3.widgetSelectors ~= new DescendantSelector(null,"testParent");
	sel3.style = new Style(sheet);
	sel3.style.color = Color.blue;
	//sel3.style.compute();
	sheet.rules ~= sel3;

	Assert(sheet.getStyleForWidget(w1).color, Color.red, "Selector(#testParent Widget) w1 has color red");
	Assert(sheet.getStyleForWidget(w2).color, Color.blue, "Selector(#testParent Widget) w2 has color blue");
	Assert(sheet.getStyleForWidget(w3).color, Color.blue, "Selector(#testParent Widget) w3 has color blue");
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
