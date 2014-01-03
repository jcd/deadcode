module gui.resources.material;

static import graphics.material;

import core.uri;

import gui.locations;
import gui.resource;
import gui.resources.shaderprogram;
import gui.resources.texture;

import io.iomanager;

import jsonx;

import std.file;

class Material : graphics.material.Material, IResource!Material
{
	private static @property Material builtIn() { return null; } // hide

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

		Material builtinMaterial()
		{
			return _manager.get("builtin");
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

class MaterialManager : ResourceManager!Material
{
	@property Material builtinMaterial()
	{
		return get("builtin");
	}

	static MaterialManager create(IOManager iom, ShaderProgramManager spm, TextureManager tm)
	{
		auto fm = new MaterialManager;
		auto fp = new MaterialSerializer(spm, tm);
		fm.ioManager = iom;
		fm.addSerializer(fp);

		fm.createBuiltinMaterial(spm, tm);

		return fm;
	}

	private void createBuiltinMaterial(ShaderProgramManager spm, TextureManager tm)
	{
		auto mat = declare("builtin");
		mat.shader = spm.builtinShaderProgram;
		mat.texture = tm.builtinTexture;
	}

	/** Overriden load that will ensure sub resources of the material (e.g. texture and shaders)
		are also loaded
	*/
	override bool load(ResourceState state)
	{
		super.load(state);

		gui.resources.Texture tex = cast(gui.resources.Texture) state.resource.texture;
		if (tex !is null)
			tex.load();

		gui.resources.ShaderProgram sp = cast(gui.resources.ShaderProgram) state.resource.shader;
		if (sp !is null)
			sp.load();

		return true;
	}
}

class MaterialSerializer : ResourceSerializer!Material
{
	this(ShaderProgramManager shaderProgramManager, TextureManager textureManager)
	{
		_shaderProgramManager = shaderProgramManager;
		_textureManager = textureManager;
	}	
	
	override bool canHandle(URI uri)
	{
		import std.path;
		return uri.extension == ".material";
	}
	
	override void deserialize(Material res, string str)
	{
		struct ShaderProgramSpec
		{
			string shaderProgram;
			string texture;
		}

		auto spec = jsonDecode!ShaderProgramSpec(str);
		auto spURI = new URI(spec.shaderProgram);
		auto texURI = new URI(spec.texture);
		auto baseURI = res.uri.dirName;
	
		if (!spURI.isAbsolute)
			spURI.makeAbsolute(baseURI);
		if (!texURI.isAbsolute)
			texURI.makeAbsolute(baseURI);

		res.shader = _shaderProgramManager.declare(null, spURI);
		res.texture = _textureManager.declare(null, texURI);

		res.manager.onResourceLoaded(res, this);
	}

	private ShaderProgramManager _shaderProgramManager;
	private TextureManager _textureManager;
}
