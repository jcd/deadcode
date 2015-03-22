module gui.resources.shaderprogram;

static import graphics.shaderprogram;
import gui.locations;
import gui.resource;

import io.iomanager;

import util.jsonx;

import std.file;

class ShaderProgram : graphics.shaderprogram.ShaderProgram, IResource!ShaderProgram
{
	private static @property ShaderProgram builtIn() { return null; } // hide

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

	Manager _manager;
	Handle _handle;
	string _name;
}

class ShaderProgramManager : ResourceManager!ShaderProgram
{
	private Handle builtinShaderProgramHandle;

	@property ShaderProgram builtinShaderProgram()
	{
		return get(builtinShaderProgramHandle);
	}

	static ShaderProgramManager create(IOManager ioManager)
	{
		auto fm = new ShaderProgramManager;
		auto fp = new ShaderProgramSerializer;
		fm.ioManager = ioManager;
		fm.addSerializer(fp);

		fm.createBuiltinShaderProgram();

		return fm;
	}

	static class BuiltinLoader : Loader
	{
		bool load(ShaderProgram p, URI uri)
		{
			import graphics.shader;
			ShaderProgram.create(Shader.builtInVertexShaderSource, Shader.builtInFragmentShaderSource, p);
			// p.link();
			p.setUniform("colMap", 0);
			p.manager.onResourceLoaded(p, null);
			return true;
		}

		bool save(ShaderProgram p, URI uri)
		{
			throw new Exception("Cannot save shader programs");
		}
	}

	private void createBuiltinShaderProgram()
	{
		auto res = declare(new URI("builtin:default"), new BuiltinLoader);
		builtinShaderProgramHandle = res.handle;
	}
}

class ShaderProgramSerializer : ResourceSerializer!ShaderProgram
{
	override bool canRead() pure const nothrow { return true; }

	override bool canHandle(URI uri)
	{
		import std.path;
		return uri.extension == ".shaderprogram";
	}

	override void deserialize(ShaderProgram res, string str)
	{
		struct ShaderProgramSpec
		{
			string fragmentShader;
			string vertexShader;
		}
		import std.string;
		string[dchar] transTable;
		transTable['\n'] = "\\n";
		transTable['\t'] = "\\t";
		transTable['\r'] = "\\r";
		auto trStr = translate(str, transTable);
		auto spec = jsonDecode!ShaderProgramSpec(str);

		// TODO: Make explicit attach and link here!
		if (ShaderProgram.create(spec.vertexShader, spec.fragmentShader, res) !is null)
		{
			// Only signal resource loaded on success
			res.manager.onResourceLoaded(res, this);
		}
	}
}

