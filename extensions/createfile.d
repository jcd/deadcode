module extensions.createfile;

import extensions.attr;
mixin registerCommands;

@MenuItem("New/Buffer") 
@Shortcut("<ctrl> + n")
void newBuffer(GUIApplication app)
{
	auto b = app.createBuffer();
	app.showBuffer(b);
}

void newExtension(GUIApplication app)
{
	import core.language;
	auto b = app.createBuffer();
	
	import std.path;
	
	//auto base = buildNormalizedPath(app.resourceURI("./", ResourceBaseLocation.currentDir).uriString, "extensions/myext.d");
	//b.name = base;
	// b.name = "New extension";
	b.insert(q"{module extensions.myext;

import extensions.attr;
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

