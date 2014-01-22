module gui.resource;

import core.uri;

import std.exception;

import io.iomanager;

interface IResource(T)
{
	alias ResourceManager!T Manager;
	alias Manager.Handle Handle;

	@property Handle handle();
	@property string name();
	@property Manager manager();
	void load();

	final void ensureLoaded()
	{
		manager.ensureLoaded(handle);
	}

	void unload();
}

/** Base class for a resource such as Texture or StyleSet
A Resource can be in different load states:
* unknown  : an instance does not exists but this is the state for removed or unknown resources in a ResourceManager
* declared : known by a ResourceManager by name/handle but no Resource available to reference
* unloaded : A Resource is available to reference but has not been loaded
* loading  : loading 
* loaded   : loaded and ready
*/
class Resource(T) : IResource!T
{
public:

	@property 
	{
		string name()
		{
			return _name;
		}

		private void name(string name)
		{
			_name = name;
		}
		
		public Handle handle()
		{
			return _handle;
		}

		private void handle(Handle h)
		{
			_handle = h;
		}

		URI uri()
		{
			return _manager.getURI(_handle);
		}

		Manager manager()
		{
			return _manager;
		}

		void manager(Manager m)
		{
			_manager = m;
		}
	}

	void load()
	{
		_manager.load(_handle);
	}

	void unload()
	{
		_manager.unload(_handle);
	}

protected:
	Manager _manager;
	Handle _handle;
	string _name;
}

/** Resource specific exception
*/
class ResourceException : Exception
{
	this(string s, string file = __FILE__, int line = __LINE__) {
        super(s, file, line);
    }
}

enum NullHandle = 0;

interface IResourceManager
{
	void onLocationFound(URI uri);
}


/** Base class for managing resources such as Textures and StylesSets
*/
class ResourceManager(T) : IResourceManager
{
public:
	alias int Handle;
	alias ResourceSerializer!T Serializer;
	alias IResourceLoader!T Loader;

	@property
	{
		IOManager ioManager()
		{
			return _ioManager;
		}

		void ioManager(IOManager iom)
		{
			_ioManager = iom;
		}
	}
	
	// Declare a resource in the manager making it possible to get a reference to the unset/unloaded resource.
	// If name is null a name will be generated
	// An optional URI can be provided.
	final T declare(string name = null, URI uri = null, Loader loader = null)
	{
		auto r = declareImpl(name, uri);
		r.loader = loader;
		return r.resource;
	}
	
	final private ResourceState lookup(URI uri)
	{
		foreach (k,v; _resourcesByHandle)
		{
			if (v.uri == uri)
				return v;
		}
		return null;
	}

	final private ResourceState declareImpl(string name = null, URI uri = null)
	{
		Handle h = NullHandle;
		ResourceState* rs = null;
		if (name is null)
		{
			if (uri !is null)
			{
				auto uriMatchingResourceState = lookup(uri);
				if (uriMatchingResourceState !is null)
					rs = &uriMatchingResourceState;
			}

			if (rs is null)
			{
				h = createHandle();
				int subItem = 0;
				while (name is null || (name in _resourcesByName) !is null)
				{
					if (subItem == 0)
						name = std.string.format("%s_%s", ResourceManager!T.stringof, h);
					else
						name = std.string.format("%s_%s_%s", ResourceManager!T.stringof, h, subItem++);
				}
			}
		}
		else
		{
			rs = name in _resourcesByName;
		}

		if (rs is null)
		{
			auto newT = allocate();
			auto newRs = new ResourceState(uri, newT, uri is null ? LoadState.declared : LoadState.unloaded);
			rs = &newRs;
			h = h == NullHandle ? createHandle() : h;
			_resourcesByHandle[h] = newRs;
			_resourcesByName[name] = newRs;
			newT.handle = h;
			newT.name = name;
			newT.manager = this;
		}
		else if (uri !is null)
		{
			rs.uri = uri;
			if (rs.state == LoadState.declared)
				rs.state = LoadState.unloaded;
		}
		return *rs;
	}

	/*
	// Set the named resource to be identified by the URI
	void set(string name, URI uri)
	{
		ResourceState* rs = name in _resourcesByName;
		enforceEx!ResourceException(rs !is null, "Cannot set URI on unknown named resource in manager");
		rs.uri = uri;
	}
*/

	// Set the named resource to be identified by the URI
	final void set(Handle h, URI uri)
	{
		ResourceState* rs = h in _resourcesByHandle;
		enforceEx!ResourceException(rs !is null, "Cannot set URI on unknown resource in manager");
		
		if (rs.state == LoadState.declared && uri !is null)
			rs.state = LoadState.unloaded;
		else if (rs.state != LoadState.declared && rs.state != LoadState.unloaded)
			enforceEx!ResourceException(uri !is null, "Cannot set " ~ T.stringof ~ " resource URI to null when loaded");
		
		rs.uri = uri;
	}

	/*
	// Set the named resource to res, optionally providing a uri overriding any existing uri for the named resource 
	// that may exist.
	// This may create a new resource or update a predeclared (using declare()) resource.
	// Method is protected since only managers themselves are allowed to set 
	protected void set(string name, T res, URI uri = null)
	{
		ResourceState* rs = name in _resourcesByName;
		set(rs, res, uri);
	}

	// ditto
	protected void set(Handle h, T res, URI uri = null)
	{
		ResourceState* rs = h in _resourcesByHandle;
		enforceEx!ResourceException(rs, std.string.format("Cannot set resource by handle %s for handle unknown by %s manager", 
														  h, T.stringof));
		set(rs, res, uri);
	}

	// Helper
	private Handle set(ResourceState* state, T res, URI uri)
	{
		if (state is null)
		{
			ResourceState newState = { uri, res, LoadState.prepared };

			auto h = createHandle();
			_resourcesByHandle[h] = newState;
			_resourcesByName[name] = newState;
			return h;
		}
		else
		{
			state.resource = res;
			state.state = LoadState.prepared;
			if (uri !is null)
				state.uri = uri;
		}
		return NullHandle;
	}
*/
	
	protected bool load(ResourceState state)
	{
		state.state = LoadState.loading;
		
		if (state.loader !is null)
			return state.loader.load(state.resource, state.uri);

		enforceEx!ResourceException(_ioManager, std.string.format("IOManager not set on %s", this.stringof));
		
		if (state.uri is null)
			return false;

		// TODO: Maybe just store a pointer to the serializer in ResourceState?
		foreach (s; _serializers)
		{
			if (s.canHandle(state.uri))
			{
				IO io = _ioManager.open(state.uri);
				s.deserialize(state.resource, io);
				return true;
			}
		}
		return false;
	}

	final bool load(string name, URI uri = null)
	{
		ResourceState rs = declareImpl(name, uri);
		return load(rs);
	}

	final bool load(Handle h)
	{
		ResourceState* rs = h in _resourcesByHandle;
		enforceEx!ResourceException(rs, "Cannot load " ~ T.stringof ~ " resource from unknown handle");
		return load(*rs);
	}

	/// Load resource if not already loaded ie. not reload is performed
	final bool ensureLoaded(Handle h)
	{
		ResourceState* rs = h in _resourcesByHandle;
		enforceEx!ResourceException(rs, "Cannot load " ~ T.stringof ~ " resource from unknown handle");
		if (rs.state >= LoadState.loading && rs.state <= LoadState.prepared)
			return true; // already loaded => noop
		return load(*rs);
	}

	// Unload the specified resource from system. The resource can be loaded again using load().
	final private bool unload(ResourceState rs)
	{
		bool success = false;
		final switch (rs.state)
		{
			case LoadState.unknown:
			case LoadState.declared:
			case LoadState.unloaded:
				success = true;
				break;
			case LoadState.loading:
				break;
			case LoadState.loaded:
				rs.resource.unload();
				success = true;
				break;
			case LoadState.preparing:
				break;
			case LoadState.prepared:
				rs.resource.unload();
				success = true;
				break;
			case LoadState.unloading:
				success = true;
				break;
		}
		return success;
	}

	final bool unload(string name)
	{
		ResourceState* rs = name in _resourcesByName;
		enforceEx!ResourceException(rs, "Cannot unload " ~ T.stringof ~ " resource of unknown name '" ~ name ~ "'");
		return unload(*rs);
	}

	final bool unload(Handle h)
	{
		ResourceState* rs = h in _resourcesByHandle;
		enforceEx!ResourceException(rs, "Cannot unload " ~ T.stringof ~ " resource with unknown handle");
		return unload(*rs);
	}

	protected T allocate()
	{
		// default allocation on GC
		return new T;
	}

	protected void deallocate(T res)
	{
		// default dealloc from GC
		destroy(res);
	}

	// Remove resource from manager. After this the resource needs to be re-declared using declare(), set() or load().
	final void remove(string name)
	{
		ResourceState* rs = name in _resourcesByName;
		enforceEx!ResourceException(rs, "Cannot remove " ~ T.stringof ~ " resource of unknown name '" ~ name ~ "'");
		unload(*rs);
		deallocate(rs.resource);
	}

	final void remove(Handle h)
	{
		ResourceState* rs = h in _resourcesByHandle;
		enforceEx!ResourceException(rs, "Cannot remove " ~ T.stringof ~ " resource with unknown handle");
		unload(*rs);
		deallocate(rs.resource);
	}

	final T get(string name, T def)
	{
		auto i = name in _resourcesByName;
		if (i is null)
			return def;
	//	if (!prepare(*i))
	//		return null;
		return i.resource;
	}

	final T get(string name)
	{
		return enforceEx!ResourceException(get(name, null), 
										   std.string.format("No %s named '%s' in manager", T.stringof, name));
	}
	
	final T get(Handle h, T def)
	{
		auto i = h in _resourcesByHandle;
		if (i is null)
			return null;
		//if (!prepare(*i))
		//	return null;
		return i.resource;
	}

	final T get(Handle h)
	{
		return enforceEx!ResourceException(get(h, null), 
										   std.string.format("No %s with handle %s in manager", T.stringof, h));
	}

	final URI getURI(Handle h)
	{
		auto i = h in _resourcesByHandle;
		if (i is null)
			return null;
		//if (!prepare(*i))
		//	return null;
		return i.uri;		
	}

	bool prepare(ResourceState rs)
	{
		bool success = true;
		final switch (rs.state)
		{
			case LoadState.unknown:
			case LoadState.declared:
				success = false;
				break;
			case LoadState.unloaded:
				return load(rs);
			case LoadState.loading:
			case LoadState.loaded:
			case LoadState.preparing:
			case LoadState.prepared:
				break;
			case LoadState.unloading:
				success = false;
				break;
		}		
		return success;
	}

	void addSerializer(Serializer serializer)
	{
		_serializers ~= serializer;
	}
	
	/**
	Callback for LocationManager when it finds an URI that this manager may be interested in.
	You need to register the manager with a Locations instance to get callbacks. 
	You probably want to reimplement this in a derived manager.

	Example:
	---
	auto loc = locationsManager.declare("name", "file://foobar/dd/*");

	// Make instance of MyManager get onLocationFound callbacks
	loc.addListener(new MyManager);
	loc.load(); // force Location to scan for files and in turn callback the manager
	---
	*/
	void onLocationFound(URI uri)
	{
		import std.path;
		foreach (s; _serializers)
		{
			if (s.canHandle(uri))
			{
				declare(uri.baseName.stripExtension, uri);
				break;
			}
		}
	}

	void onResourceLoaded(T res, Serializer serializer)
	{
		auto i = res.handle in _resourcesByHandle;
		enforceEx!ResourceException(i.state == LoadState.loading || serializer is null, "Got " ~ T.stringof ~ " resource loaded callback for non-loading resource");
		i.state = LoadState.loaded;
	}

	/+
	/** Find resources in locations configured matching the uriPattern.
	    This may scan file directories or access net sockets depending on what
	    locations are configured because some scanning maybe have to be performed.
	*/
	void findByURI(string uriPattern)
	{
		// derived classes can use the locationManager to scan for resources and declare them.
		locationManager.find(uriPattern);
	}

	void findByName(string namePattern)
	{
		// derived classes can use the locationManager to scan for resources and declare them.
		locationManager.find(uriPattern);
	}
	+/

protected:
	
	enum LoadState
	{
		unknown,   // Previously declared but now removed resource
		declared,  // Name and handle is known      (ie cannot be loaded)
		unloaded,  // Name, handle and URI is known (ie. can be loaded now)
		loading,   // Being loaded now
		loaded,    // Done loading the resource from disk, net, whatever
		preparing, // Processing, generating, converting resource before it is ready for use
		prepared,  // Ready to be used
		unloading  // Unloading from system. Will result in resource going to unloaded state
	}
	
	class ResourceState 
	{
		// The URI needs to point to something that contains enough info to actually be able to construct
		// the resource. E.g. for a font it would need to be info about the font file and the size of the font 
		// (ie. some kind of font spec). For a texture a simple path to a .png file may be enough.
		
		// URI is the universal identifier for this resource.
		// If the URI is on URL form it also specifies how to obtain the resource. E.g. an image 
		// could be file:data/theimage.ong
		// In other cases the URL point to a resource spec file that describes how to create a resource. E.g. a
		// font can have a file:data/thefont.font file which specifies a font size of 16dpi and contains another URI
		// to a .ttf file.
		// All resources are loaded from a URI by a ResourceProvider, and for the URL subset the URLResourceProvider
		// will handle that. 
		this(URI u, T res, LoadState s)
		{
			uri = u;
			resource = res;
			state = s;
		}
		URI uri; // e.g http://foobar.com/foobar.spec#" or "ded:74837189348"
		T resource;
		LoadState state;
		Loader loader;
	}
	
	Handle _nextHandle;
	Handle createHandle()
	{
		return _nextHandle++;
	}

	ResourceState[Handle] _resourcesByHandle;
	ResourceState[string] _resourcesByName;
	Serializer[] _serializers;
	IOManager _ioManager; // Need an IO manager because resources can be loaded/unloaded at will
}

interface IResourceLoader(T)
{
	/** Custom loading of resources
	*/
	bool load(T r, URI uri);
}

interface IResourceSerializer(T)
{
	/** Serialization
	Returns: 
	false if the IO cannot handle the required resource
	*/
	bool canHandle(URI uri);

	// void serialize(OuputRange)(T res, OutputRange or);
	void deserialize(InputRange)(T res, InputRange ir);
}

class ResourceSerializer(T) : IResourceSerializer!T
{
	bool canHandle(URI uri) { return false; }

	void deserialize(T res, string str)
	{
		throw new ResourceException("No string serializer implemeted");
	}

	void deserialize(T res, IO io)
	{
		auto str = io.readText();
		deserialize(res, str);
	}

	void deserialize(InputRange)(T res, InputRange ir)
	{
		import std.array;
		char[] str = array(ir);
		deserialize(res, str);
	}
}

version(unittest)
{
	class Dummy : Resource!Dummy
	{
		this() { loaded = false; }
		public bool loaded;
	}

	class DummyManager : ResourceManager!Dummy
	{
	}

	class DummyLoader : IResourceLoader!Dummy
	{
		public bool load(Dummy r, URI uri)
		{
			r.manager.onResourceLoaded(r, null);
			return true;
		}
	}

	class DummySerializer : ResourceSerializer!Dummy
	{
		override bool canHandle(URI uri)
		{
			return true;
		}

		override void deserialize(Dummy res, IO io)
		{
			res.manager.onResourceLoaded(res, this);
		}
	}
}

unittest
{
	DummyManager m = new DummyManager;
	//DummySerializer p = new DummySerializer;
	//m.addSerializer(p);
	DummyLoader loader = new DummyLoader;

	import test;
	auto r = m.declare("dummy1", null, loader);
	Assert(m.get(r.handle) is r, "Resource from declare same as resource gotten by handle from manager");
	Assert(m.get(r.name) is r, "Resource from declare same as resource gotten by name from manager");
	auto r2 = m.declare("dummy1", null, loader);
	Assert(r is r2, "Redeclaring with same name results in same resource");
	auto r3 = m.declare("dummy1", new URI("resources/dummies/dummy1.dummy"), loader);
	Assert(r is r3, "Redeclaring with same name and a uri results in same resource");
	Assert(r.loaded, false, "Resource is not loaded before calling load");
	m.load(r.handle);
	Assert(r.loaded, true, "Resource is loaded after calling load");
}
