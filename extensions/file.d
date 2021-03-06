module extensions.file;

import extensionapi;

mixin registerCommands;

import std.algorithm;

auto filesystemCompletions(string path)
{
	import dccore.path;

	import std.array;
	import std.file;
	import std.string;
    import std.typecons;
	import util.string;

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

    debug {
        static import std.stdio;
        version (linux)
            std.stdio.writeln(path, " ", relDirPath, " : ", filenamePrefix, " ", dirEntries(relDirPath, SpanMode.shallow));
    }

	auto r1 = dirEntries(relDirPath, SpanMode.shallow)
            .map!(a => tuple(filenamePrefix.empty ? 1.0 : baseName(a).rank(filenamePrefix), a.isDir ? tr(a.name, r"\", "/") ~ '/' : tr(a.name, r"\", "/")))
            .filter!(a => a[0] > 0.0)
            .array;
        auto r2 = r1
            .sort!((a,b) => a[0] > b[0])
            .map!(a => CompletionEntry(a[1], a[1]))
            .array;
    return r2;


/*
	auto paths = dirEntries(relDirPath, SpanMode.shallow)
		.filter!(a => a.name.baseName.startsWith(filenamePrefix))
		.map!(a => a.isDir ? tr(a.name, r"\", "/") ~ '/' : tr(a.name, r"\", "/"));

	return paths.map!(a => CompletionEntry(a,a)).array;
*/

	//.filter!(a => a.name.baseName.startsWith(filenamePrefix))
	//.map!(a => a.isDir ? buildNormalizedPath(relDirPath, a.name.baseName, "") : a.name);
}


@InFiber()
@MenuItem("File/Save Quick")
void fileSave(BufferView buf, Application app)
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
		string defaultPath = app.resourceURI("./", PathBase.currentDir).uriString;
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
			import edit.language;
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
                                    import std.file;
                                    return !exists(prefix);
                                 },
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
        {
			fileSaveAs(buf, app, p.answer);
			if (buf.codeModel is null)
            {
				import edit.language;
				auto dinfo = manager().lookupByFileExtension(extension(buf.name));
				if (dinfo !is null)
					buf.codeModel = dinfo.createModel(buf);
            }
        }
	}
}

@InFiber()
@MenuItem("File/Save")
void fileSaveNativeDialog(BufferView buf, Application app)
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
		string defaultPath = app.resourceURI("./", PathBase.currentDir).uriString;
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
			import edit.language;
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
									 import std.file;
									 return !exists(prefix);
                                 },
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
        {
			fileSaveAs(buf, app, p.answer);
			if (buf.codeModel is null)
            {
				import edit.language;
				auto dinfo = manager().lookupByFileExtension(extension(buf.name));
				if (dinfo !is null)
					buf.codeModel = dinfo.createModel(buf);
            }
        }
	}
}


void fileSaveAs(BufferView buf, Application app, string filename)
{
    static import std.stdio;
	// handle encoding
	buf.name = filename;
	auto f = std.stdio.File(filename, "wb");
	buf.write(f);
	f.flush();
	f.close();
	app.addMessage("Wrote %s", buf.name);
}

@InFiber()
@MenuItem("File/Open Quick")
void fileOpen(Application app)
{
	auto filePath = app.resourceURI("./", PathBase.currentDir).uriString ~ "/";
	auto p = app.yieldPrompt("Open", filePath,
							 (string prefix) {
                                 import std.file;
                                 return exists(prefix) &&  isFile(prefix);
                             },
                             (string prefix) {
								 return filesystemCompletions(prefix);
							 }
							 );
	if (p.success)
		app.openFile(p.answer);
}

@MenuItem("File/Open")
void fileOpenNativeDialog(Application app)
{
	import platform.dialog;
	import std.file;

	auto filePath = app.resourceURI("./", PathBase.currentDir).uriString ~ "/";
	auto p = showSelectFolderDialogBasic(filePath);
	if (p !is null && exists(p) && isFile(p))
		app.openFile(p);
}
