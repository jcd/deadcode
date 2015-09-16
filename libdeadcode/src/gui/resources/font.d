module gui.resources.font;

import graphics.font : GFont = Font;
import gui.locations;
import gui.resource;

import io.iomanager;

import util.jsonx;

import std.path;

import test;
mixin registerUnittests;

class Font : GFont, IResource!Font
{
	private static @property Font builtIn() { return null; } // hide

	public this()
	{

	}

	//private this(string path, size_t size)
	//{
	//    super(path, size);
	//}

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

		Handle handle() const pure nothrow @safe
		{
			return _handle;
		}

		void handle(Handle h)
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

private:
	Manager _manager;
	Handle _handle;
	string _name;
}


class FontManager : ResourceManager!Font
{
	private Handle builtinFontHandle;

	@property Font builtinFont()
	{
		return get(builtinFontHandle);
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
        import platform.config;
		builtinFontHandle = declare(builtinFontPath).handle;
	}

	Font create(string path, size_t size = 16)
	{
		auto f = declare();
		f.init(path, size);
		return f;
	}
}

class JsonFontSerializer : ResourceSerializer!Font
{
	override bool canRead() pure const nothrow { return true; }

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

	auto r = m.declare();
	AssertIs(m.get(r.handle), r, "Resource from declare same as resource gotten by handle from manager");
	//auto r2 = m.declare("font1");
	//AssertIs(r, r2, "Redeclaring with same name results in same resource");
	//auto r3 = m.declare("font1", new URI("resources/fonts/default.font"));
	//AssertIs(r, r3, "Redeclaring with same name and a uri results in same resource");
}
