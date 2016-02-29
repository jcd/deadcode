module dccore.path;

import std.file : getcwd;
import std.range.primitives : ElementEncodingType, ElementType, isInputRange;
import std.string;
import std.traits : isSomeChar, isSomeString;

public import std.path : extension, baseName, CaseSensitive, defaultExtension, dirName, driveName, expandTilde, globMatch, isAbsolute, isDirSeparator, pathSplitter, setExtension, stripDrive, stripExtension;

immutable(ElementEncodingType!(ElementType!Range))[] buildPath(Range)(Range segments)
if (isInputRange!Range && isSomeString!(ElementType!Range))
{
	version (Windows)
		return std.path.buildPath(segments).tr(r"\","/");
	else
		return std.path.buildPath(segments);
}

pure @safe immutable(C)[] buildPath(C)(const(C)[][] paths...)
if (isSomeChar!C)
{
	version (Windows)
		return std.path.buildPath(paths).tr(r"\","/");
	else
		return std.path.buildPath(paths);
}

pure @trusted immutable(C)[] buildNormalizedPath(C)(const(C[])[] paths...)
{
	version (Windows)
		return std.path.buildNormalizedPath(paths).tr(r"\","/");
	else
		return std.path.buildNormalizedPath(paths);
}

pure @safe string absolutePath(string path, lazy string base = getcwd())
{
	version (Windows)
		return std.path.absolutePath(path, base).tr(r"\","/");
	else
		return std.path.absolutePath(path, base);
}

auto rootName(R)(R path)
{
	version (Windows)
		return std.path.rootName(path).tr(r"\","/");
	else
		return std.path.rootName(path);
}
