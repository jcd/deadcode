module gui.resources.font;

import graphics.font : GFont = Font;
import gui.locations;
import gui.resource;

import io.iomanager;

import jsonx;

import std.path;

class Font : GFont, IResource!Font
{
	private static @property Font builtIn() { return null; } // hide

	public this()
	{
		
	}

	private this(string path, size_t size)
	{
		super(path, size);
	}
	
	@property 
	{
		string name()
		{
			return _name;
		}

		void name(string name)
		{
			_name = name;
		}

		Handle handle()
		{
			return _handle;
		}

		void handle(Handle h)
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
		_manager.load(handle);
	}

	void unload()
	{
		_manager.unload(handle);
	}

private:
	Manager _manager;
	Handle _handle;
	string _name;
}

version(Windows)
{
	private immutable string builtinFontPath = r"C:\Windows\Fonts\verdana.ttf";
}

class FontManager : ResourceManager!Font
{
	@property Font builtinFont()
	{
		return get("builtin");
	}
	
	static FontManager create(IOManager ioManager)
	{
		auto fm = new FontManager;
		auto fp = new JsonFontSerializer;
		fm.ioManager = ioManager;
		fm.addSerializer(fp);
		
		fm.createBuiltinFont();
		
		return fm;
	}
	
	private void createBuiltinFont()
	{
		declare("builtin", new URI(builtinFontPath));
	}

	Font create(string name, string path, size_t size = 16)
	{
		auto f = declare(name);
		f.init(path, size);
		return f;
	}
}

class JsonFontSerializer : ResourceSerializer!Font
{
	override bool canHandle(URI uri)
	{
		return uri.extension == ".font";
	}
	
	override void deserialize(Font res, string str)
	{
		struct FontSpec
		{
			string uri;
			int size;
		}

		auto spec = jsonDecode!FontSpec(str);

		// TODO: make Font accept an IO or databuffer
		res.init(spec.uri, spec.size);
		res.manager.onResourceLoaded(res, this);
	}
}


unittest
{
	FontManager m = new FontManager;
	auto p = new JsonFontSerializer;
	m.addSerializer(p);

	import test;
	auto r = m.declare("font1");
	AssertIs(m.get(r.handle), r, "Resource from declare same as resource gotten by handle from manager");
	AssertIs(m.get(r.name), r, "Resource from declare same as resource gotten by name from manager");
	auto r2 = m.declare("font1");
	AssertIs(r, r2, "Redeclaring with same name results in same resource");
	auto r3 = m.declare("font1", new URI("resources/fonts/default.font"));
	AssertIs(r, r3, "Redeclaring with same name and a uri results in same resource");
}
