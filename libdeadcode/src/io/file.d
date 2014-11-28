module io.file;

import io.iomanager;

import std.algorithm;
import std.file;
import std.path;
import std.range;
import std.stdio : StdFile = File;

class File : IO
{
	static File open(string path, IOMode mode)
	{
		// debug std.stdio.writeln("Opening ", path);
		string modeString;
		
		final switch (mode)
		{
			case IOMode.read:
				modeString = "r";
				break;
			case IOMode.write:
				modeString = "w";
				if (!exists(path.dirName))
					mkdirRecurse(path.dirName);
				break;
			case IOMode.append:
				modeString = "a";
				break;
		}
		try
		{
			File f = new File;
			f._handle = StdFile(path, modeString);
			return f;
		}
		catch (Exception e)
		{
			debug std.stdio.writeln("Cannot open", path);
			return null;
		}
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
	void readText(OutputRange)(OutputRange r) if (isOutputRange!(OutputRange, immutable(char)))
	{
		auto sz = cast(size_t)_handle.size;
		if (sz == 0)
			return;

		static if( __traits(compiles, r.reserve(1)))
			r.reserve(sz);
		
		// TODO: Get rid of temp buf for reading and read directly into input range
		char[] buf;
		buf.length = sz;
		_handle.rawRead(buf);
		r.put(buf);
	}

	void writeText(InputRange)(InputRange r) if (isInputRange!InputRange)
	{
		static if (hasSlicing!InputRange)
		{
			_handle.rawWrite(r[]);
		}
		else
		{
			foreach (elm; r)
				_handle.write(elm);
		}
		_handle.flush();
	}

	//ubyte[] readAll();
	
	string readText()
	{
		import std.array;
		auto res = appender!string();
		readText(res);
		return res.data;
	}

	void writeText(string output)
	{
		writeText!string(output);
	}

	private StdFile _handle;
}


class FileProtocol : IOProtocol
{
	bool canHandle(URI url)
	{
		string schema = url.schema;
		version (Windows)
		{
			auto isAbsPath = url.uriString.length > 3 && schema.length == 1 && url.uriString[1..3] == ":/";
			return schema is null || schema == "file" || isAbsPath;
		}
		else
		{
			return schema is null || schema == "file";
		}
	}
	
	IO open(URI url, IOMode mode)
	{
		return File.open(uriToPath(url), mode);
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
		auto f = fp.open(new URI(p), IOMode.read);
		Assert(f.readText().startsWith("[Setup]"));
	}
}

