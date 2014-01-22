module io.file;

import io.iomanager;

import std.algorithm;

import std.path;
import std.range : empty;
import std.stdio : StdFile = File;

class File : IO
{
	this(string path)
	{
		_handle = StdFile(path, "r");
	}
	
	~this()
	{
		close();
	}

	void close()
	{
		_handle.close();
	}

	//void readAll(InputRange)(InputRange r);
	void readText(InputRange)(InputRange r)
	{
		auto sz = cast(size_t)_handle.size;
		
		static if( __traits(compiles, r.reserve(1)))
			r.reserve(sz);
		
		// TODO: Get rid of temp buf for reading and read directly into input range
		char[] buf;
		buf.length = sz;
		_handle.rawRead(buf);
		r.put(buf);
	}

	//ubyte[] readAll();
	
	string readText()
	{
		import std.array;
		auto res = appender!string();
		readText(res);
		return res.data;
	}

	private StdFile _handle;
}


class FileProtocol : IOProtocol
{
	bool canHandle(URI url)
	{
		string schema = url.schema;
		return schema is null || schema == "file";
	}
	
	IO open(URI url)
	{
		return new File(uriToPath(url));
	}

	string readText(URI inUrl)
	{
		return std.file.readText(uriToPath(inUrl));
	}

	static string uriToPath(URI inUrl)
	{
		import util.system;
		auto url = inUrl.toString();

		string origURL = url;

		if (url.startsWith("file:"))
			url = url[5..$];

		string base;
		if (url.startsWith("//"))
		{
			base = getRunningExecutablePath();
			url = url[2..$];
		}

		if (url.startsWith("/"))
		{
			// Relative to base path 
			url = buildPath(base, url);
		}
		else 
		{
			url = buildPath(getRunningExecutablePath, url);
		}
		return buildNormalizedPath(url);
	}
}

unittest
{
	import test;
	auto fp = new FileProtocol;
	
	string[] paths = [ "file:///install.ini", "file://c:/install.ini", "/install.ini" ];
	
	// Convenience protocol method for reading all text in a file
	foreach (p; paths)
	{
		Assert(fp.readText(new URI(p)).startsWith("[Setup]"));
	}

	// ditto but through allocated File
	foreach (p; paths)
	{
		auto f = fp.open(new URI(p));
		Assert(f.readText().startsWith("[Setup]"));
	}
}

