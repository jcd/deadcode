module gui.resources.texture;

static import graphics.texture;
import gui.locations;
import gui.resource;

import io.iomanager;

import std.file;

class Texture : graphics.material.Texture, IResource!Texture
{
	private static @property Texture builtIn() { return null; } // hide

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
		_manager.load(_handle);
	}

	void unload()
	{
		_manager.unload(_handle);
	}


	Manager _manager;
	Handle _handle;
	string _name;
}

class TextureManager : ResourceManager!Texture
{
	@property Texture builtinTexture()
	{
		return get("builtin");
	}

	static TextureManager create(IOManager ioManager)
	{
		auto fm = new TextureManager;
		auto fp = new TextureSerializer;
		fm.ioManager = ioManager;
		fm.addSerializer(fp);
		fm.createBuiltinTexture();
		return fm;
	}
	
	static class BuiltinLoader : Loader
	{
		bool load(Texture t, URI uri)
		{
			import graphics.color;
			graphics.texture.Texture.create(8, 8, Color.magenta, t);
			return true;
		}
	}

	void createBuiltinTexture()
	{
		declare("builtin",  new URI("builtin:default"), new BuiltinLoader);
	}

}

class TextureSerializer : ResourceSerializer!Texture
{
	override bool canHandle(URI uri)
	{
		import std.path;
		import std.algorithm;
		return [ ".png" ].countUntil(uri.extension) >= 0;
	}
	
	override void deserialize(Texture res, IO io)
	{
		// TODO: Make use of the IO instead of using sdl builtin loader
		Texture.create(res.uri.toString(), res);
		res.manager.onResourceLoaded(res, this);
	}
}
