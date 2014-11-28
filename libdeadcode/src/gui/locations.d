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

/**
Following happens:

1, LocationsManager.scan get called with an uri pattern
2, A new Locations resource is declared
4, The LocationsManager scans the URI of the resource
5, Files are added the the Locations resource
6, Runs through files found and send a onLocationFound on all listeners (e.g. other ResourceManagers)
7, Other ResourceManagers check if they support the file URI
8, If supported then onSourceChanged is emitted in case URI is already known or the URI is declared with the ResourceManager
*/
class LocationsManager : ResourceManager!Locations
{
	private IResourceManager[] _listeners;
	
	enum char[4] globChars = ['*', '?', '[', '{' ];
	
	static LocationsManager create(IOManager iom)
	{
		auto lm = new LocationsManager;
	//	auto s = new LocationsSerializer;
		lm.ioManager = iom;
		//		lm.addSerializer(s);
		return lm;
	}

	void scan(URI uriPattern)
	{
		// This will declare the Locations resource if needed
		// Then call load(ResourceState) below
		super.load(uriPattern); 
	}

	override protected bool load(ResourceState state)
	{
		if (state.uri is null)
			return false;
		
		state.state = LoadState.loading;
		scanIntoLocations(state.resource);
		onResourceLoaded(state.resource, null);
		return true;
	}

	void scanIntoLocations(Locations res)
	{
		import std.file;
		import std.array;
		import std.string;

		//assert(res.uri.toString()[0..5] == "scan:");

		// res.uriPattern = res.uri.toString()[5..$]; // strip "scan:"
		res.uriPattern = res.uri.toString();
		string baseURI = res._baseURI.toString();

		auto locs = appender!(Location[])();

		// debug std.stdio.writeln("Scanning location ", baseURI);

		foreach (DirEntry e; dirEntries(baseURI, res._uriPattern[baseURI.length..$], SpanMode.depth, true))
		{
			if (!e.isFile)
				continue;

			string name = e.name.tr(r"\", "/");
			locs.put(Location(new URI(name), cast(uint)e.size, e.timeLastModified));
		}

		res._locations = locs.data;
		res.manager.onResourceLoaded(res, null);
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
				listn.onLocationFound(loc.uri, loc.size, loc.lastModified);
		}
	}
}

//class LocationsSerializer: ResourceSerializer!Locations
//{
//    
//
//    override bool canHandle(URI uri)
//    {
//        // TODO: restrict to local fs paths
//        return true;
//    }
//
//
//}
