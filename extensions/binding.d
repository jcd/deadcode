module extensions.binding;

import guiapplication;
import controls.textfield;
import gui.layout.gridlayout;
import gui.widget;

import std.typecons;
import std.typetuple;
import std.traits;

struct AutoControlInfo(Model)
{
    string field;
    Widget function(GUIApplication, Model) fp;
}

enum IsAutoControl(alias D) = !is(D == int) && !is(D == void);
enum IsAutoControl(D) = !is(D == int) && !is(D == void);

alias AutoControl(D, Model, string field) = void;
//enum AutoControl(D : int) = IntField;
//enum AutoControl(D : float) = FloatField;

Widget createAndBindTextField(Model, string field)(GUIApplication app, Model m)
{
    auto ctrl = new TextField(app.createBuffer());
    m.bind!field(m, ctrl);
    return cast(Widget) ctrl;
};
enum AutoControl(D : string, Model, string field) = AutoControlInfo!Model(field, &(createAndBindTextField!(Model, field)));

Widget createAndBindIntField(Model, string field)(GUIApplication app, Model m)
{
    auto ctrl = new TextField(app.createBuffer());
    m.bind!field(m, ctrl);
    return cast(Widget) ctrl;
};

enum AutoControl(D : int, Model, string field) = AutoControlInfo!Model(field, &(createAndBindIntField!(Model, field)));




template ToAutoControl(Obj)
{
    template ToAutoControl(string FieldName)
    {
        // static if (__traits(compiles, mixin("() { Obj o; return o."~FieldName~";}")))
        static if (is( typeof(() { mixin("Obj o; return o."~FieldName~";"); } ) ) )
        {
            // pragma(msg, "foo " ~ FieldName);
            alias ToAutoControl = AutoControl!(typeof(mixin("Obj." ~ FieldName)), Obj, FieldName);
        }
        else
        {
            // pragma(msg, "bar " ~ FieldName);
            alias ToAutoControl = int;
        }
    }
}

enum AutoControls(Obj) = Filter!(IsAutoControl, staticMap!(ToAutoControl!Obj, __traits(derivedMembers, Obj)));

class FieldContainer : Widget
{
    this(Widget parent = null)
    {
        auto l = new GridLayout(GridLayout.Direction.column, 2);
        l.cellVerticalSpacing = 4f;
        l.cellHorizontalSpacing = 0f;
        layout = l;
        if (parent !is null)
            this.parent = parent;
    }
}
