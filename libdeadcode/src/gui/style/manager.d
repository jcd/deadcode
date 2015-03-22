module gui.style.manager;

import animation.interpolate;

import math;

import gui.resource;
import gui.resources.material;
import gui.resources.font : Font, FontManager;
import graphics.color : Color;

import gui.style.property;
import gui.style.style;
import gui.style.stylesheet;
import gui.style.types;

import io.iomanager;

class StyleSheetManager : ResourceManager!StyleSheet
{
	static void function(StyleSheetManager) onInitialized[];

    private
	{
		FontManager _fontManager;  // TODO: No need for managers I think. Let the ones why create styles know about that
		MaterialManager _materialManager;
		IPropertySpecification[PropertyID] _propertySpecifications;
		Handle builtinStyleSheetHandle;
	}

	@property
	{

		FontManager fontManager()
		{
			return _fontManager;
		}

		MaterialManager materialManager()
		{
			return _materialManager;
		}

	}

	static StyleSheetManager create(IOManager ioManager, MaterialManager mm, FontManager fm)
	{
		import gui.resources;
		auto ssm = new StyleSheetManager;
		ssm._materialManager = mm;
		ssm._fontManager = fm;
		ssm.ioManager = ioManager;
		ssm.addSerializer(new StyleSheetSerializer(mm, fm));

		ssm.createBuiltinStyleSheet(mm, fm);

		ssm.addPropertySpecification!float("expand-duration", 0.10);
		ssm.addPropertySpecification!Vec2f("offset", Vec2f(0,0));
		ssm.addPropertySpecification!float("page-down-speed", 0.10);

		// Transitions
		// import animation.interpolate;
		import std.datetime;
		ssm.addPropertySpecification!Duration("transition-delay", dur!"seconds"(0)).multi = true;
		ssm.addPropertySpecification!Duration("transition-duration", dur!"seconds"(0)).multi = true;
		auto ease = animation.interpolate.CubicBezierCurve!float.ease;
		ssm.addPropertySpecification!CubicCurveParameters("transition-timing", ease.dup[0..4]).multi = true;
		// ssm.addPropertySpecification!float("transition-timing", 0f);
		ssm.addPropertySpecification!PropertyID("transition-property", "all").multi = true;
		ssm.addPropertyShorthand("transition",
								 "property", "duration", "timing", "delay").multi = true;

		foreach (i; onInitialized)
            i(ssm);
        return ssm;
	}

	private void createBuiltinStyleSheet(MaterialManager mm, FontManager fm)
	{
		StyleSheet ss = declare(new URI("builtin:default"));
		builtinStyleSheetHandle = ss.handle;

		Rule sel = new Rule;
		ss.rules ~= sel;

		Style lbase = new Style(ss); // ss.createStyle("builtin");
		lbase.font = fm.builtinFont;
		lbase.background = mm.builtinMaterial;
		lbase.color = Color.red;
		lbase.backgroundColor = Color.white;
		lbase.padding = RectfOffset(0, 0, 0, 0);
		lbase.backgroundSpriteBorder = RectfOffset(0, 0, 0, 0);
		lbase.backgroundSprite = Rectf.init;

		sel.style = lbase;
		sel.selectors ~= new StylableSelector(null, null); // select all

		onResourceLoaded(ss, null);
	}

	void addPropertySpecification(IPropertySpecification spec)
	{
		_propertySpecifications[spec.id] = spec;
	}

	auto addPropertySpecification(T)(PropertyID pid, T _default, bool inherited = false)
	{
		auto v = new PropertySpecification!T(pid, _default, inherited);
		_propertySpecifications[pid] = v;
		return v;
	}

	auto addPropertyShorthand(PropNames...)(PropertyID base, PropNames propNames)
	{
		// rename to id-subprop
		// e.g. id == "background" and subprop is "color" becomes
		// "background-color"

		IPropertySpecification[] subProperties;

		foreach (p; propNames)
		{
			auto id = base ~ "-" ~ p;
			subProperties ~= _propertySpecifications[id];
		}

		auto v = new PropertyShorthand(base, subProperties);
		_propertySpecifications[base] = v;
		return v;
	}

	const(IPropertySpecification) lookupPropertySpecification(PropertyID pid) const pure nothrow @safe
	{
		auto ps = pid in _propertySpecifications;
		if (ps is null) return null;
		return *ps;
	}
}
