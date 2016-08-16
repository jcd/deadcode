module gui.resource;

import dccore.uri;

import std.datetime;
import std.exception;
import dccore.signals;
import std.typecons;

import io.iomanager;

import test;
mixin registerUnittests;

enum LoadState
{
	unknown,   // Previously declared but now removed resource or just never declared
	declared,  // Handle is known      (ie cannot be loaded)
	unloaded,  // Handle and URI is known (ie. can be loaded now)
	loading,   // Being loaded now
	loaded,    // Done loading the resource from disk, net, whatever
	preparing, // Processing, generating, converting resource before it is ready for use
	prepared,  // Ready to be used
	error,     // Could not be loaded
	unloading  // Unloading from system. Will result in resource going to unloaded state
}

interface IResource(T)
{
	alias ResourceManager!T Manager;
	alias Manager.Handle Handle;

	@property Handle handle() const pure nothrow @safe;
	@property Manager manager() pure nothrow @safe;
	@property const(Manager) manager() const pure nothrow @safe;
	final @property URI uri()
	{
		return manager.getURI(handle);
	}
	final @property LoadState loadState() const pure nothrow
	{
		return manager.loadStateForHandle(handle);
	}

	final void ensureLoaded()
	{
		manager.ensureLoaded(handle);
	}

	final const(Exception) getLastException() const pure nothrow
	{
		return manager.getLastExceptionForHandle(handle);
	}

	final void load()
	{
		manager.load(handle);
	}

	final void save()
	{
		manager.save(handle);
	}

	final void unload()
	{
		manager.unload(handle);
	}
}

/** Base class for a resource such as Texture or StyleSheet
A Resource can be in different load states:
* unknown  : an instance does not exists but this is the state for removed or unknown resources in a ResourceManager
* declared : known by a ResourceManager by handle but no Resource available to reference
* unloaded : A Resource is available to reference but has not been loaded
* loading  : loading
* loaded   : loaded and ready
*/
class Resource(T) : IResource!T
{
public:

	@property
	{
		public Handle handle() const pure nothrow @safe
		{
			return _handle;
		}

		private void handle(Handle h)
		{
			_handle = h;
		}

		Manager manager() pure nothrow @safe
		{
			return _manager;
		}

		const(Manager) manager() const pure nothrow @safe
		{
			return _manager;
		}

		void manager(Manager m)
		{
			_manager = m;
		}
	}

protected:
	Manager _manager;
	Handle _handle;
}

/** Resource specific exception
*/
class ResourceException : Exception
{
	this(string s, string file = __FILE__, size_t line = __LINE__) {
        super(s, file, line);
    }
}

enum NullHandle = 0;

interface IResourceManager
{
	void onLocationFound(URI uri, size_t size, SysTime lastModified);
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

	this()
	{
		_defaultLoader = new DefaultLoader;
	}

	// Declare a resource in the manager making it possible to get a reference to the unset/unloaded resource.
	// An optional URI can be provided.
	final T declare(URI uri, Loader loader = null)
	{
		auto r = declareImpl(uri)[0];
		r.loader = loader;
		return r.resource;
	}

	final T declare(string uriString, Loader loader = null)
	{
		return declare(new URI(uriString), loader);
	}

	final T declare(Loader loader = null)
	{
		return declare(cast(URI)null, loader);
	}

	final private ResourceState lookup(URI uri)
	{
		import std.stdio;
		foreach (k,v; _resourcesByHandle)
		{
			URI theURI = uri;

			if (v.uri !is null && v.uri == uri)
			{
				return v;
			}
		}

		return null;
	}

	final private auto declareImpl(URI uri = null)
	{
		bool newlyDeclared = false;
		ResourceState* rs = null;

		if (uri !is null)
		{
			auto uriMatchingResourceState = lookup(uri);
			if (uriMatchingResourceState !is null)
				rs = &uriMatchingResourceState;
		}

		if (rs is null)
		{
			newlyDeclared = true;
			Handle h = createHandle();
			auto newT = allocate();
			auto newRs = new ResourceState(uri, newT, uri is null ? LoadState.declared : LoadState.unloaded);
			rs = &newRs;
			_resourcesByHandle[h] = newRs;
			newT.handle = h;
			newT.manager = this;
		}
		else if (uri !is null)
		{
			rs.uri = uri;
			if (rs.state == LoadState.declared)
				rs.state = LoadState.unloaded;
		}
		return tuple(*rs, newlyDeclared);
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
	class DefaultLoader : IResourceLoader!T
	{
		bool load(T r, URI uri)
		{
			import std.string : format;
            enforceEx!ResourceException(_ioManager, format("IOManager not set on %s", this.stringof));

			if (uri is null)
				return false;

			// TODO: Maybe just store a pointer to the serializer in ResourceState?
			foreach (s; _serializers)
			{
				if (s.canRead() && s.canHandle(uri))
				{
					IO io = _ioManager.open(uri, IOMode.read);
					if (io is null)
						continue;
					s.deserialize(r, io);
					io.close();
					return true;
				}
			}
			return false;
		}

		bool save(T r, URI uri)
		{
			import std.string : format;
            enforceEx!ResourceException(_ioManager, format("IOManager not set on %s", this.stringof));

			if (uri is null)
				return false;

			// TODO: Maybe just store a pointer to the serializer in ResourceState?
			foreach (s; _serializers)
			{
				if (s.canWrite() && s.canHandle(uri))
				{
					IO io = _ioManager.open(uri, IOMode.write);
					if (io is null)
						continue;
					s.serialize(r, io);
					io.close();
					return true;
				}
			}
			return false;
		}
	}

	protected bool load(ResourceState state)
	{
		LoadState preState = state.state;
		state.state = LoadState.loading;

		if (state.loader is null)
			state.loader = _defaultLoader;

		bool ok = true;
		try
		{
			if (!state.loader.load(state.resource, state.uri))
			{
				state.state = preState;
				ok = false;
			}
		}
		catch (Exception e)
		{
			// state.state = preState;
			import std.stdio;
			writeln("resource exception: ", e);
			state.state = LoadState.error;
			ok = false;
			setLastExceptionForHandle(state.resource.handle, e);
		}

		return ok;
	}

	const(LoadState) loadStateForHandle(Handle h) const pure nothrow
	{
		auto s = h in _resourcesByHandle;
		if (s is null)
			return LoadState.unknown;
		return s.state;
	}

	private final void setLastExceptionForHandle(Handle h, Exception e)
	{
		_resourceExceptions[h] = e;
	}

	final const(Exception) getLastExceptionForHandle(Handle h) const pure nothrow
	{
		auto e = h in _resourceExceptions;
		if (e is null)
			return null;
		return *e;
	}

	final T load(URI uri, Loader loader = null)
	{
		auto res = declareImpl(uri);
		ResourceState rs = res[0];
		rs.loader = loader;
		bool newlyDeclared = res[1];

		if (!load(rs))
		{
			//// Unsuccessful load
			//if (newlyDeclared)
			//{
			//    // Just remove resource if it has been newly declared because we don't care about it.
			//    remove(rs.resource.handle);
			//    return null;
			//}
		}

		// Is null in case of newlyDeclared and unsuccessfull because of remove() above
		return rs.resource;
	}

	final T load(string uriString)
	{
		return load(new URI(uriString));
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
		if (rs.state == LoadState.error)
			return false;
		return load(*rs);
	}

	final bool save(Handle h)
	{
		ResourceState* rs = h in _resourcesByHandle;
		enforceEx!ResourceException(rs, "Cannot save " ~ T.stringof ~ " resource from unknown handle");

		if (rs.loader is null)
			rs.loader = _defaultLoader;

		return rs.loader.save(rs.resource, rs.uri);
	}

	// Unload the specified resource from system. The resource can be loaded again using load().
	final private bool unload(ResourceState rs)
	{
		if (rs.resource is null)
			return true;

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
				rs.state = LoadState.unloading;
				rs.resource.unload();
				rs.state = LoadState.unloaded;
				success = true;
				break;
			case LoadState.preparing:
				break;
			case LoadState.prepared:
				rs.state = LoadState.unloading;
				rs.resource.unload();
				rs.state = LoadState.unloaded;
				success = true;
				break;
			case LoadState.error:
			case LoadState.unloading:
				success = true;
				break;
		}
		return success;
	}

	bool unload(Handle h)
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

	protected void deallocate(ref T res)
	{
		// default dealloc from GC
		if (res is null) return;
		destroy(res);
		res = null;
	}

	// Remove resource from manager. After this the resource needs to be re-declared using declare(), set() or load().
	final void remove(Handle h)
	{
		if (h == NullHandle)
			return;
		ResourceState* rs = h in _resourcesByHandle;
		enforceEx!ResourceException(rs, "Cannot remove " ~ T.stringof ~ " resource with unknown handle");
		unload(*rs);
		_resourceExceptions.remove(rs.resource.handle);
		deallocate(rs.resource);
		_resourcesByHandle.remove(h);
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
        import std.string : format;
		return enforceEx!ResourceException(get(h, null),
										   format("No %s with handle %s in manager", T.stringof, h));
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
			case LoadState.error:
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
	auto loc = locationsManager.declare("file://foobar/dd/*");

	// Make instance of MyManager get onLocationFound callbacks
	loc.addListener(new MyManager);
	loc.load(); // force Location to scan for files and in turn callback the manager
	---
	*/
	void onLocationFound(URI uri, size_t size, SysTime lastModified)
	{
		// Maybe the resource is already registered and we need to update
		foreach (k, v; _resourcesByHandle)
		{
			if (v.uri == uri && v.lastModified != lastModified)
			{
				onSourceChanged.emit(v.resource);
				v.lastModified = lastModified;
				return;
			}
		}

		import dccore.path;


		foreach (s; _serializers)
		{
			if (s.canRead() && s.canHandle(uri))
			{
				auto r = declare(uri);
				auto rstate = _resourcesByHandle[r.handle];
				rstate.lastModified = lastModified;
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

	//void detectSourceChanges()
	//{
	//    foreach (k, v; _resourcesByHandle)
	//    {
	//        v.loader
	//    }
	//}

	// The resource manager will detect if source has changed and emit this signal.
	// It will not reload the resource since that could possible break current users
	// of the resource. It is up to the signal listener to do that if needed by calling
	// T.load().
	// emit(T)
	mixin Signal!(T) onSourceChanged;

protected:

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
		SysTime lastModified;
	}

	Handle _nextHandle;
	Handle createHandle()
	{
		return _nextHandle++;
	}

	Exception[Handle] _resourceExceptions;
	ResourceState[Handle] _resourcesByHandle;
	Serializer[] _serializers;
	DefaultLoader _defaultLoader;
	IOManager _ioManager; // Need an IO manager because resources can be loaded/unloaded at will
}

interface IResourceLoader(T)
{
	/** Custom loading of resources
	*/
	bool load(T r, URI uri);
	bool save(T r, URI uri);
}

class ResourceSerializer(T)
{
	import std.array;

	/** Serialization
	Returns:
	false if the IO cannot handle the required resource
	*/
	bool canHandle(URI uri) { return false; }

	bool canRead() pure const nothrow { return false; }
	bool canWrite() pure const nothrow { return false; }

	void serialize(T res, Appender!string output)
	{
		throw new ResourceException("No string serializer implemeted");
	}

	void serialize(T res, IO io)
	{
		auto output = appender!string();
		serialize(res, output);
		io.writeText(output.data);
	}

	void serialize(OutputRange)(T res, OutputRange or)
	{
		auto output = appender!string();
		deserialize(res, output);
		or.put(output.data);
	}

	void deserialize(T res, string input)
	{
		throw new ResourceException("No string deserializer implemeted");
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
		this() { loaded = false; saved = false;}
		public bool loaded;
		public bool saved;
	}

	class DummyManager : ResourceManager!Dummy
	{
	}

	class DummyLoader : IResourceLoader!Dummy
	{
		public bool load(Dummy r, URI uri)
		{
			r.manager.onResourceLoaded(r, null);
			r.loaded = true;
			return true;
		}
		public bool save(Dummy r, URI uri)
		{
			r.saved = true;
			return true;
		}
	}

	class DummySerializer : ResourceSerializer!Dummy
	{
		import std.array;

		override bool canRead() pure const nothrow { return true; }

		override bool canHandle(URI uri)
		{
			return true;
		}

		override void serialize(Dummy res, Appender!string output)
		{

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

	auto r = m.declare(cast(string)null, loader);
	Assert(m.get(r.handle) is r, "Resource from declare same as resource gotten by handle from manager");
	//Assert(m.get(r.name) is r, "Resource from declare same as resource gotten by name from manager");
	//auto r2 = m.declare("dummy1", null, loader);
	//Assert(r is r2, "Redeclaring with same name results in same resource");
	//auto r3 = m.declare("dummy1", new URI("resources/dummies/dummy1.dummy"), loader);
	//Assert(r is r3, "Redeclaring with same name and a uri results in same resource");
	Assert(r.loaded, false, "Resource is not loaded before calling load");
	m.load(r.handle);
	Assert(r.loaded, true, "Resource is loaded after calling load");
	r.save();
	Assert(r.saved, true, "Resource is loaded after calling load");
}
