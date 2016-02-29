module dccore.uri;

import dccore.path;
import std.string;

class URI
{
	private
	{
		string _uri;
	}

	@property
	{
		string schema() const @safe
		{
			auto idx = _uri.indexOf(':');
			if (idx < 0)
				return null;
			return _uri[0..idx];
		}

		URI dirName()
		{
			auto idx = _uri.lastIndexOf('/');
			if (idx < 0)
				return new URI("");
			return new URI(_uri[0..idx+1]);
		}

		bool isAbsolute()
		{
			return _uri.indexOf("://") >= 0;
		}

		bool isDir()
		{
			import std.range;
			return _uri.empty || _uri[$-1] == '/';
		}

		override string toString() @safe nothrow const
		{
			return _uri;
		}

		string baseName()
		{
			return _uri.baseName;
		}

		string extension()
		{
			return _uri.extension;
		}

		string uriString()
		{
			return _uri;
		}
	}

	this(string uriString)
	{
		_uri = uriString;
	}

	void makeAbsolute(URI baseURI)
	{
		assert(!isAbsolute);
		assert(baseURI.isDir);
		_uri = baseURI._uri ~ _uri;
		normalize();
	}

	void normalize()
	{
		import std.array;
		import std.regex;
		_uri = _uri.replace("\\","/");
		auto com = regex(r"[^/]+/../","g");
		_uri = replaceAll(_uri, com, "");
	}

	override bool opEquals(Object other) pure const nothrow
	{
		URI o = cast(URI)other;
		return _uri == o._uri;
	}
}
