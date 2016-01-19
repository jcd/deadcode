module extensionapi.widget;

import extensionapi.common;

// Convenience public imports for extensions to have available per default
public import controls.menu;
public import controls.button;
public import controls.textfield;
public import gui.control.scrollview;
public import gui.widget;
public import gui.window;
public import gui.event;
public import gui.label;
public import gui.layout.constraintlayout;
public import gui.layout.gridlayout;
public import gui.widgetfeature.dragger;
public import gui.widgetfeature.ninegridrenderer;
public import gui.widgetfeature.textrenderer;
public import gui.styledtext;
public import gui.style;

private static TypeInfo_Class[] g_Widgets;
private static IBasicWidget[] g_BasicWidgets;

import std.traits;
import std.typetuple;

Exception[] initWidgets(Application app)
{
    Exception[] exceptions;

    foreach (wi; g_Widgets)
	{
		try
        {
            auto w = cast(IBasicWidget)(wi.create());
		    g_BasicWidgets ~= w;
		    w.app = app;
		    // app.guiRoot.activeWindow.register(w);
		    w.parent = app.guiRoot.activeWindow;
		    w.layout = new GridLayout(GridLayout.Direction.column, 1);
            w.init();
        }
        catch (Exception e)
            exceptions ~= e;
	}
    return exceptions;
}

void finiWidgets(Application app)
{
    foreach (w; g_BasicWidgets)
	{
		w.fini();
	}
}

/// The preferred location of a widget
struct PreferredLocation
{
	string widgetName;          /// Name of widget that the subject should be relative to or null if window
	RelativeLocation location;  /// The location relative to the names widget
}

/**

*/
class IBasicWidget : Widget
{
	Application app;
	this() nothrow {}
	abstract void init();
	abstract void fini();
	abstract void onStart();
	abstract void onStop();
	abstract @property PreferredLocation preferredLocation();
}

/** Widget to derive from when extending editor with a new widget type

*/
class BasicWidget : IBasicWidget
{
    private IBinder[] _fieldBindings;

	override void init()
	{
		// no-op
	}

	override void fini()
	{
		// no-op
	}

	override void onStart()
	{
		// no-op
	}

	override void onStop()
	{
		// no-op
	}

	override @property PreferredLocation preferredLocation()
	{
		return PreferredLocation(null, RelativeLocation.bottomOf);
	}

    WT getChildByIndex(WT = Widget)(int idx)
    {
        if (idx >= children.length)
            return null;
        return cast(WT)children[idx];
    }

    WT get(WT = Widget)(string name)
    {
        return cast(WT)app.getWidget(name);
    }

    void addFields(W, Model)(W parent, Model model)
    {
        import std.string;
        import extensions.binding : FieldContainer, AutoControls;
        auto container = new FieldContainer(parent);

        foreach (ctrlFactory; AutoControls!Model)
        {

            string fullName = ctrlFactory.field;
            string delim = "";
            string labelStr = "";
            while (fullName.length)
            {
                labelStr ~= delim;

                string n = fullName.munch("^[a-z0-9_]");
                if (n.length > 1)
                {
                    labelStr ~= n; // This is an Achronym
                }
                else if (n.length == 1)
                {
                    labelStr ~= n;
                    labelStr ~= fullName.munch("[a-z0-9_]");
                }
                else // n.length == 0
                {
                    labelStr ~= fullName.munch("[a-z0-9_]").capitalize();
                }
                delim = " ";
            }
            new Label(labelStr).parent = container;
            auto ctrl = ctrlFactory.fp(app, model);
            ctrl.parent = container;
        }
    }

    void addFields(W)(W parentAndModel)
    {
        addFields(parentAndModel, parentAndModel);
    }

    auto bind(string fieldName, Cls, Ctrl)(Cls cls, Ctrl ctrl)
    {
        auto b = new Binder!(fieldName, Cls, Ctrl)(cls, ctrl);
        assumeSafeAppend(_fieldBindings);
        _fieldBindings ~= b; // TODO: make unbinding as well
    }

    void updateField(string fieldName)
    {
        foreach (f; _fieldBindings)
            f.updateFromModel();
    }

	Data loadSessionData(Data)()
	{
		auto r = app.get("extensions/widgets/" ~ this.classinfo.name);
		if (r is null)
			return null;
		auto data = r.get!Data();
		if (data is null)
		{
			data = new Data();
			r.set(data);
		}
		return data;
	}

	// If data is null then the data returned by loadSessionData will be saved
	void saveSessionData(Data)(Data data = null)
	{
		auto r = app.get("extensions/widgets/" ~ this.classinfo.name);
		if (r is null)
			return;
		if (data !is null)
			r.set(data);
		r.save();
	}
}

class BasicWidgetWrap(T) : T
{
	import dccore.attr;
    static this()
	{
		//auto w = new T;
		//T.widgetID = w.id;
		g_Widgets ~= BasicWidgetWrap!T.classinfo;
	}

    static if (!hasDerivedMember!(T, "init"))
    override void init()
    {
        addFields(cast(T)this);
    }
}

interface IBinder
{
    void updateFromModel();
}

class Binder(string fieldName, Cls, Ctrl) : IBinder
{
    import animation.mutator;
    import std.conv;
    private Cls  _model;
    private Ctrl _ctrl;
    alias FieldProxy!(fieldName, Cls) FP;
    alias FP.FieldType FieldType;

    // std.signals does not support delegates so we create a special class for the purpose
    this(Cls m, Ctrl c)
    {
        _model = m;
        _ctrl = c;
        updateFromModel();
        _ctrl.onChanged.connect(&fieldChanged);
    }

    void fieldChanged()
    {
        FP.set(_model, _ctrl.value.to!(FP.FieldType));
    }

    void updateFromModel()
    {
        _ctrl.value = FP.get(_model).to!(typeof(_ctrl.value));
    }

    private ref FieldType value()
    {
        return mixin("_model." ~ fieldName);
    }
}

