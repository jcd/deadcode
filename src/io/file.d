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
		import util.system;
		_handle = StdFile(buildNormalizedPath(getRunningExecutablePath() ~ "/" ~ path), "r");
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
		return new File(url.toString());
	}

	string readText(URI inUrl)
	{
		auto url = inUrl.toString();

		string origURL = url;
		
		if (url.startsWith("file://"))
		{
			url = url[7..$]; // strip
			if (!url.empty && url[0] != '/')
			{
				// uri was file://hostname/path/to/file and hostname needs to go
				ptrdiff_t d = std.string.indexOf(url, '/', 1);
				if (d <= 0)
					throw new IOException(std.string.format("Only host part of file URL present '%s'", origURL));
				url = url[d..$];
			}
		}

		return std.file.readText(url);
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
		Assert(fp.readText(p).startsWith("[Setup]"));
	}

	// ditto but through allocated File
	foreach (p; paths)
	{
		auto f = fp.open(p);
		Assert(f.readText(p).startsWith("[Setup]"));
	}
}

