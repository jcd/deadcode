module graphics.shaderprogram;

import derelict.opengl3.gl3;
import graphics.shader : Shader;
import math._ : Mat4f;
import std.conv : text;
import std.exception : enforceEx;
import std.range : empty;
import std.stdio : writeln;
import std.string : toStringz;

final class ShaderProgram
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
	
	static ShaderProgram create(const(char)[] vertexSource = null, const(char)[] fragmentSource = null)
	{
		ShaderProgram pr = new ShaderProgram();
		uint p = glCreateProgram(); 
		if(p == 0){ 
			writeln("Error: GL did not assign main shader program id"); 
			return pr; 
		} 
		
		pr.glProgramID = p;
		
		if (!vertexSource.empty)
		{
			pr.attach(new Shader(vertexSource, Shader.Type.Vertex));
		}
		
		if (!fragmentSource.empty)
		{
			pr.attach(new Shader(fragmentSource, Shader.Type.Fragment));
		}
		
		return pr;
	}
	
	void attach(Shader shader)
	{
		assert(glProgramID > 0);
		assert(shader.glShaderID > 0);
		glAttachShader(glProgramID, shader.glShaderID); 
	}
	
	bool link()
	{
		assert(glProgramID > 0);
		glLinkProgram(glProgramID); 
		int status, len;
		glGetShaderiv(glProgramID, GL_LINK_STATUS, &status); 
		
		if(status == GL_FALSE)
		{ 
			glGetShaderiv(glProgramID, GL_INFO_LOG_LENGTH, &len); 
			char[] error=new char[len]; 
			glGetShaderInfoLog(glProgramID, len, null, cast(char*)error); 
			writeln(error); 
			return false; 
		}
		return true;
	} 
	
	private int getUniformLocation(const(char)[] name)
	{
		auto n = toStringz(name);
		int colLoc = glGetUniformLocation(glProgramID, n); 
		enforceEx!Exception(colLoc != -1, text("Error: main shader did not assign id to uniform ", name , " prg ", glProgramID)); 
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
