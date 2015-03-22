module io.iomanager;

import std.exception;

public import core.uri;


/** IO specific exception
*/
class IOException : Exception
{
	this(string s, string file = __FILE__, int line = __LINE__) {
        super(s, file, line);
    }
}

interface IO
{
	void close();

	//void readAll(InputRange)(InputRange r);
	void readText(OutputRange)(OutputRange r);
	void writeText(InputRange)(InputRange r);

	//ubyte[] readAll();
	string readText();
	void writeText(string output);
}

enum IOMode
{
	read,
	write,
	append
}

interface IOProtocol
{
	bool canHandle(URI uri);
	IO open(URI uri, IOMode mode);
}

//class ScanProtocol : IOProtocol
//{
//    bool canHandle(URI uri)
//    {
//        import std.algorithm;
//        return uri.schema == "scan";
//    }
//
//    IO open(URI uri)
//    {
//        return null;
//    }
//}

class IOManager
{
	IO open(URI uri, IOMode mode)
	{
		auto iop = getProtocol(uri);
		return iop.open(uri, mode);
	}

	IOProtocol getProtocol(URI uri)
	{
		auto iop = getProtocolImpl(uri);
		if (iop is null)
        {
        	import std.string : format;
        	throw new IOException(format("No handler for URI '%s'", uri));
        }
		return iop;
	}

	private IOProtocol getProtocolImpl(URI uri)
	{
		IOProtocol io = null;
		foreach (k,v; _factories)
		{
			if (v.canHandle(uri))
				return v;
		}
		return null;
	}

	void add(IOProtocol p)
	{
		_factories ~= p;
	}

	IOProtocol[] _factories;
}
