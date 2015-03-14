module extensions.file;

import extensions;

mixin registerCommands;

import std.algorithm;

 auto filesystemCompletions(string path)
{
	import std.array;
	import std.file;
	import std.path;
	import std.string;

	string relDirPath = path;
	string filenamePrefix;
	if (!path.empty)
	{
		auto ch = path[$-1];
		if (!isDirSeparator(ch))
		{
			relDirPath = dirName(path);
			filenamePrefix = baseName(path);
		}

		if (relDirPath == ".")
			relDirPath = "";
	}

	//auto dirPath = dirName(absolutePath(path));
	//	auto filenamePrefix = baseName(path);

	debug std.stdio.writeln(path, " ", relDirPath, " : ", filenamePrefix, " ", dirEntries(relDirPath, SpanMode.shallow));

	auto paths = dirEntries(relDirPath, SpanMode.shallow)
		.filter!(a => a.name.baseName.startsWith(filenamePrefix))
		.map!(a => a.isDir ? tr(a.name, r"\", "/") ~ '/' : tr(a.name, r"\", "/"));

	return paths.map!(a => CompletionEntry(a,a)).array;


	//.filter!(a => a.name.baseName.startsWith(filenamePrefix))
	//.map!(a => a.isDir ? buildNormalizedPath(relDirPath, a.name.baseName, "") : a.name);
}


@InFiber()
void fileSave(BufferView buf, GUIApplication app)
{
	import std.algorithm;
	import std.file;
	import std.path;
	if (buf.isPersistant)
	{
		fileSaveAs(buf, app, buf.name);
	}
	else
	{
		string defaultPath = app.resourceURI("./", ResourceBaseLocation.currentDir).uriString;
		string dn = buf.name.dirName;
		if (dn.length && dn != "." && exists(buf.name.dirName))
		{
			if (!buf.name.isAbsolute())
				defaultPath = buildNormalizedPath(defaultPath, buf.name);
			else
				defaultPath = buf.name;
		}
		else if (auto h = buf.codeModel) // probably a d file so lets guess on that
		{
			import core.language;
			h.updateAST();
			auto spath = h.getSuggestedPath();
			if (spath.length)
			{
				if (!spath.isAbsolute())
					defaultPath = buildNormalizedPath(defaultPath, spath);
				else
					defaultPath = spath;
			}
		}


		auto p = app.yieldPrompt("Save as", defaultPath,
								 (string prefix) {
									 return filesystemCompletions(prefix);
									//CompletionEntry[] result;
									// result ~= CompletionEntry("foo1", "bar1");
									// result ~= CompletionEntry("foo2", "bar2");
									// result ~= CompletionEntry("foo3", "bar3");
									//return result;
								 }
								 );
		if (p.success)
			fileSaveAs(buf, app, p.answer);
	}
}

void fileSaveAs(BufferView buf, GUIApplication app, string filename)
{
	// handle encoding
	buf.name = filename;
	auto f = std.stdio.File(filename, "wb");
	buf.write(f);
	f.flush();
	f.close();
	app.addMessage("Wrote %s", buf.name);
}

@InFiber()
void fileOpen(GUIApplication app)
{
	auto p = app.yieldPrompt("Open", app.resourceURI("./", ResourceBaseLocation.currentDir).uriString,
							 (string prefix) {
								 return filesystemCompletions(prefix);
								 //CompletionEntry[] result;
								 // result ~= CompletionEntry("foo1", "bar1");
								 // result ~= CompletionEntry("foo2", "bar2");
								 // result ~= CompletionEntry("foo3", "bar3");
								 //return result;
							 }
							 );
	if (p.success)
		app.openFile(p.answer);
}

//class FileOpenCommand : BasicCommand
//{
//    void run(string path)
//    {
//        app.openFile(path);
//    }
//
//    CompletionEntry[] complete(string path)
//    {
//        return filesystemCompletions(path);
//    }
//}
