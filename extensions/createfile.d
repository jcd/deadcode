module extensions.createfile;

import extensionapi;
mixin registerCommands;

@MenuItem("New/Buffer")
@Shortcut("<ctrl> + n")
void newBuffer(Application app)
{
	auto b = app.createBuffer();
	app.showBuffer(b);
}

void newExtension(Application app)
{
	import dccore.language;
	auto b = app.createBuffer();

	import dccore.path;


	//auto base = buildNormalizedPath(app.resourceURI("./", ResourceBaseLocation.currentDir).uriString, "extensions/myext.d");
	//b.name = base;
	// b.name = "New extension";
	b.insert(q"{module extensions.myext;

import extensionapi;
mixin registerCommands;

void myextHello(BufferView v)
{
	v.insert("Hello");
}
}");

	ICodeIntel i = manager().lookup("D");
	ICodeModel m = i.createModel(b);
	b.codeModel = m;

	app.showBuffer(b);
}

void newWidget(Application app)
{
	import dccore.language;
	auto b = app.createBuffer();

	import dccore.path;


	//auto base = buildNormalizedPath(app.resourceURI("./", ResourceBaseLocation.currentDir).uriString, "extensions/myext.d");
	//b.name = base;
	// b.name = "New extension";
	b.insert(q"{module extensions.mywidget;

import extensionapi;
mixin registerCommands;

class MyWidget : BasicWidget
{
	Label label;
	Button button;

	override void init()
	{
		label = new Label("Hello");
		button = new Button("Click");
		button.onActivated ~- (b) { label.text = "World"; };
	}
}

}");

	ICodeIntel i = manager().lookup("D");
	ICodeModel m = i.createModel(b);
	b.codeModel = m;

	app.showBuffer(b);
}

