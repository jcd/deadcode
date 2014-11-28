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

		override graphics.shaderprogram.ShaderProgram shader()
		{
			ShaderProgram p = cast(ShaderProgram) _shader;
			if (_shader !is null)
				p.ensureLoaded();
			return _shader;
		}
		
		override void shader(graphics.shaderprogram.ShaderProgram s)
		{
			_shader = s;
		}

		override graphics.texture.Texture texture()
		{
			Texture t = cast(Texture) _texture;
			if (t !is null)
				t.ensureLoaded();
			return _texture;
		}
		

		override void texture( graphics.texture.Texture t)
		{
			_texture = t;
		}
	}
	
	Manager _manager;
	Handle _handle;
	string _name;
}

class MaterialManager : ResourceManager!Material
{
	private Handle builtinMaterialHandle;

	@property Material builtinMaterial()
	{
		return get(builtinMaterialHandle);
	}

	ShaderProgramManager shaderProgramManager;
	TextureManager textureManager;

	static MaterialManager create(IOManager iom, ShaderProgramManager spm, TextureManager tm)
	{
		auto fm = new MaterialManager;
		fm.shaderProgramManager = spm;
		fm.textureManager = tm;
		auto fp = new MaterialSerializer(spm, tm);
		fm.ioManager = iom;
		fm.addSerializer(fp);

		fm.createBuiltinMaterial(spm, tm);

		return fm;
	}

	private void createBuiltinMaterial(ShaderProgramManager spm, TextureManager tm)
	{
		auto mat = declare(new URI("builtin:default"));
		mat.shader = spm.builtinShaderProgram;
		mat.texture = tm.builtinTexture;
		builtinMaterialHandle = mat.handle;
	}

	/** Overriden load that will ensure sub resources of the material (e.g. texture and shaders)
		are also loaded
	override bool load(ResourceState state)
	{
		super.load(state);

		//// TODO: Remove since tex and shader are lazy loaded as well
		//gui.resources.Texture tex = cast(gui.resources.Texture) state.resource.texture;
		//if (tex !is null)
		//    tex.ensureLoaded();
		//
		//gui.resources.ShaderProgram sp = cast(gui.resources.ShaderProgram) state.resource.shader;
		//if (sp !is null)
		//    sp.ensureLoaded();
		//
		return true;
	}
	*/
}

class MaterialSerializer : ResourceSerializer!Material
{
	this(ShaderProgramManager shaderProgramManager, TextureManager textureManager)
	{
		_shaderProgramManager = shaderProgramManager;
		_textureManager = textureManager;
	}	
	
	override bool canRead() pure const nothrow { return true; }

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

		res.shader = _shaderProgramManager.declare(spURI);
		res.texture = _textureManager.declare(texURI);

		res.manager.onResourceLoaded(res, this);
	}

	private ShaderProgramManager _shaderProgramManager;
	private TextureManager _textureManager;
}
