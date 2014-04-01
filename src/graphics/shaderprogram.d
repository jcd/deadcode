module graphics.shaderprogram;

import derelict.opengl3.gl3;
import graphics.shader : Shader;
import math._ : Mat4f;
static import std.conv;
import std.exception : enforceEx, enforce;
import std.range : empty;
import std.stdio : writeln;
import std.string : toStringz;

class ShaderProgram
{
	private static ShaderProgram builtIn_;
	static @property ShaderProgram builtIn()
	{
		if (builtIn_ is null)
		{
			builtIn_ = create();
			builtIn_.attach(Shader.builtInVertexShader);
			builtIn_.attach(Shader.builtInFragmentShader);
			builtIn_.link();
			builtIn.setUniform("colMap", 0);
		}
		return builtIn_;
	}
	
	uint glProgramID = 0;
	Shader vertexShader;
	Shader fragmentShader;

	// if intoThis is null a new ShaderProgram is allocated
	static ShaderProgram create(const(char)[] vertexSource = null, const(char)[] fragmentSource = null, ShaderProgram intoThis = null)
	{
		// ShaderProgram pr = intoThis is null ? new ShaderProgram() : intoThis;
		scope ShaderProgram pr = new ShaderProgram();
		
		import std.conv;

 		// assert(pr.glProgramID == 0, "Shader program ID is null " ~ text(pr.glProgramID));

		pr.glProgramID = glCreateProgram(); 
		if(pr.glProgramID == 0)
		{ 
			writeln("Error: GL did not assign main shader program id"); 
			return null; 
		} 
		
		if (!vertexSource.empty)
		{
			pr.vertexShader = new Shader(vertexSource, Shader.Type.Vertex);
			pr.attach(pr.vertexShader);
		}
		
		if (!fragmentSource.empty)
		{
			pr.fragmentShader = new Shader(fragmentSource, Shader.Type.Fragment);
			pr.attach(pr.fragmentShader);
		}
	
		if (intoThis is null)
			intoThis = new ShaderProgram;
		else
			intoThis.deleteGLObjects();

		if (pr.fragmentShader !is null && pr.vertexShader !is null)
		{
			if (!pr.link())
			{
				pr.deleteGLObjects();
				return null;
			}
		}

		// Steal pr content and put into this
		intoThis.vertexShader = pr.vertexShader;
		intoThis.fragmentShader = pr.fragmentShader;
		intoThis.glProgramID = pr.glProgramID;

		return intoThis;
	}
	
	private void deleteGLObjects()
	{
		if (glProgramID != 0)
			glDeleteProgram(glProgramID);
		glProgramID = 0;

		if (vertexShader && vertexShader.glShaderID != 0)
		{
			glDeleteShader(vertexShader.glShaderID);
			vertexShader.glShaderID = 0;
		}
		if (fragmentShader && fragmentShader.glShaderID != 0)
		{
			glDeleteShader(fragmentShader.glShaderID);
			fragmentShader.glShaderID = 0;
		}
	}

	void attach(Shader shader)
	{
		assert(glProgramID > 0);
		assert(shader.glShaderID > 0);
		glAttachShader(glProgramID, shader.glShaderID); 
		enforce(glGetError() == GL_NO_ERROR, "Error setting shader source");
	}
	
	private bool link()
	{
		assert(glProgramID > 0);
		glLinkProgram(glProgramID); 
		int status, len;
		glGetProgramiv(glProgramID, GL_LINK_STATUS, &status); 
		
		if(status == GL_FALSE)
		{ 
			glGetShaderiv(glProgramID, GL_INFO_LOG_LENGTH, &len); 
			char[] error=new char[len]; 
			glGetProgramInfoLog(glProgramID, len, null, cast(char*)error); 
			//throw new Exception(error.idup);
			writeln(error); 
			return false; 
		}
		return true;
	} 
	
	private int getUniformLocation(const(char)[] name)
	{
		auto n = toStringz(name);
		int colLoc = glGetUniformLocation(glProgramID, n); 
		enforceEx!Exception(colLoc != -1, std.conv.text("Error: main shader did not assign id to uniform ", name , " prg ", glProgramID, " ERRNO ", glGetError())); 
		return colLoc;
	}
	
	void setUniform(const(char)[] name, int location)
	{ 
		glUseProgram(glProgramID);
		scope (exit) glUseProgram(0);
		glUniform1i(getUniformLocation(name), location); 
	}
	
	void setUniform(const(char)[] name, in Mat4f m)
	{ 
		glUseProgram(glProgramID);
		scope (exit) glUseProgram(0);
		glUniformMatrix4fv(getUniformLocation(name), 1, GL_TRUE, m.v.ptr); 
	} 
	
	void bind()
	{
		glUseProgram(glProgramID);
	}
}
