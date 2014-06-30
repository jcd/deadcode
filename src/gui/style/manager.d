module gui.style.manager;

import math._;

import gui.resource;
import gui.resources.material;
import gui.resources.font : Font, FontManager;

import gui.style.property;
import gui.style.style;
import gui.style.stylesheet;

import io.iomanager;

class StyleSheetManager : ResourceManager!StyleSheet
{
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

		// Transitions
		//import animation.interpolate;
		//ssm.addPropertySpecification!float("transition-delay", 0f);
		//ssm.addPropertySpecification!float("transition-duration", 0f);
		//ssm.addPropertySpecification!Interpolator("transition-timing", 0f);
		//ssm.addPropertySpecification!PropertyID("transition-property", 0f);
		//ssm.addPropertySpecificationShortHand("transition", "property", "duration", "timing", "delay");

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
		sel.widgetSelectors ~= new WidgetSelector(null, null); // select all

		onResourceLoaded(ss, null);
	}

	void addPropertySpecification(IPropertySpecification spec)
	{
		_propertySpecifications[spec.id] = spec;
	}

	void addPropertySpecification(T)(PropertyID pid, T _default, bool inherited = false)
	{
		_propertySpecifications[pid] = new PropertySpecification!T(pid, _default, inherited);
	}

	IPropertySpecification lookupPropertySpecification(PropertyID pid)
	{
		auto ps = pid in _propertySpecifications;
		if (ps is null) return null;
		return *ps;
	}
}
