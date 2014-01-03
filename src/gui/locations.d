module gui.locations;

import gui.resource;

import io.iomanager;

import std.datetime;
import std.range;

struct Location
{
	URI uri;
	size_t size;
	SysTime lastModified;
}

class Locations : Resource!Locations
{
	private
	{
		// URI that can contain wildcards to support recursive and selecting scanning.
		// Using std.path.globMatch syntax
		string _uriPattern;
		URI _baseURI;
		Location[] _locations;
	}

	@property 
	{
		string uriPattern()
		{
			return _uriPattern;
		}

		private void uriPattern(string urip)
		{
			import std.algorithm;
			import std.string;

			// Base path is the part the does not contain glob chars or a partial name
			auto __baseURI = urip;

			auto idx = __baseURI.countUntil('*', '?', '[', '{');
			if (idx >= 0)
				__baseURI = __baseURI[0..idx];

			auto idx2 = __baseURI.lastIndexOf('/');
			if (idx2 < 0)
				__baseURI.length = 0;
			else
				__baseURI = __baseURI[0..idx2+1];

			_baseURI = new URI(__baseURI);
			_uriPattern = urip;
		}

		URI baseURI()
		{
			return _baseURI;
		}

		@safe nothrow bool empty() const
		{
			return _locations.empty;
		}

		@safe nothrow size_t length() const
		{
			return _locations.length;
		}

		Location front()
		{
			return _locations.front;
		}
	}

	override void load()
	{
		_manager.load(_handle);
	}

	override void unload()
	{
		_manager.load(_handle);
	}

	static struct LocationRange
	{
		Locations _locs;
		size_t _offset;
		string _uriPat;
	
		this(Locations l, string uriPat)
		{
			_locs = l;
			_uriPat = uriPat;
			_offset = -1;
		}

		@property @safe nothrow bool empty()
		{
			return _locs is null || _locs.empty || _locs.length <= _offset;
		}

		auto front()
		{
			return _locs._locations[_offset];
		}

		void popFront()
		{
			import std.path;
			++_offset;
			while (!empty)
			{
				if (globMatch!(CaseSensitive.no)(front.uri.toString(), _uriPat))
					return;
				++_offset;
			}
		}
	}

	/** Return a range of Location matching the uriPattern
		Using std.path.globMatch syntax
	*/
	auto find(string uriPat = "*")
	{
		return LocationRange(this, uriPat);
	}

	/** Scan using the uriPattern for new locations
	*/
	auto scan()
	{
		return manager.load(handle);
	}
}

class LocationsManager : ResourceManager!Locations
{
	private IResourceManager[] _listeners;

	static LocationsManager create(IOManager iom)
	{
		auto lm = new LocationsManager;
		auto s = new LocationsSerializer;
		lm.ioManager = iom;
		lm.addSerializer(s);
		return lm;
	}

	LocationsManager addListener(IResourceManager mgr)
	{
		_listeners ~= mgr;
		return this;
	}

	static struct LocationsRange
	{
		LocationsManager _mgr;
		Handle[] _keys;
		Locations.LocationRange _locs; // current location being iterated
		string _uriPattern;

		this(LocationsManager m, string pat)
		{
			_mgr = m;
			_keys = m._resourcesByHandle.keys;
			_uriPattern = pat;
			popFront();
		}

		@property bool empty()
		{
			return _locs.empty && _keys.empty;
		}

		@property Location front()
		{
			return _locs.front;
		}

		void popFront()
		{
			while (_locs.empty && !_keys.empty)
			{
				Handle h = _keys[0];
				_keys = _keys[1..$];
				auto l = _mgr.get(h);
				assert(l !is null);
				l.scan(); // make sure the Locations has been scanned for resources
				_locs = l.find(_uriPattern);
			}
		}
	}

	/** Find all Location instances matching a pattern.
	    
		The range returned is only valid as long as the manager and its locations are not
		modified.
	
	Params:
		A uriPattern that all the returned Location must match. Set to null to get all Locations.
	
	Returns:
		A range of Location which is a union of all Locations managed
	*/
	auto find(string uriPattern = "*")
	{
		return LocationsRange(this, uriPattern);
	}

	override void onResourceLoaded(Locations res, Serializer serializer)
	{
		super.onResourceLoaded(res, serializer);
		
		// Now callback all listeners
		foreach (listn; _listeners)
		{
			foreach (loc; res._locations)
				listn.onLocationFound(loc.uri);
		}
	}
}

class LocationsSerializer: ResourceSerializer!Locations
{
	enum char[4] globChars = ['*', '?', '[', '{' ];

	override bool canHandle(URI uri)
	{
		// TODO: restrict to local fs paths
		return true;
	}

	override void deserialize(Locations res, IO io)
	{
		import std.file;
		import std.array;
		import std.string;

		assert(res.uri.toString()[0..5] == "scan:");

		res.uriPattern = res.uri.toString()[5..$]; // strip "scan:"
		
		string baseURI = res._baseURI.toString();

		auto locs = appender!(Location[])();
	
		foreach (DirEntry e; dirEntries(baseURI, res._uriPattern[baseURI.length..$], SpanMode.depth, true))
		{
			if (!e.isFile)
				continue;
	
			string name = e.name.tr(r"\", "/");
			locs.put(Location(new URI(name), cast(uint)e.size, e.timeLastModified));
		}

		res._locations = locs.data;
		res.manager.onResourceLoaded(res, this);
	}
}
