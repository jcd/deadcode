module graphics.shader;

import derelict.opengl3.gl3;
import std.stdio : writeln;
import std.string : toStringz;
import std.exception;

final class Shader 
{
version (none) // Windows
{
	enum builtInVertexShaderSource = " 
   	#version 330 
   	layout(location = 0) in vec3 pos; 
   	layout(location = 1) in vec2 texCoords; 
   	layout(location = 2) in vec3 col; 

   	out vec2 coords; 
	out vec3 cols;
	uniform mat4 MVP;
	
   	void main(void) 
   	{ 

       gl_Position = MVP * vec4(pos, 1.0); 
 //      gl_Position = vec4(pos, 1.0); 
      coords = texCoords.st; 
	  cols = col;
   	} 
   	"; 
	
	enum builtInFragmentShaderSource = " 
   	#version 330 
	
   	uniform sampler2D colMap; 
	
	in vec2 coords; 
	in vec3 cols; 
	out vec3 color;

   	void main(void) 
   	{ 
      vec3 coltmp = texture(colMap, coords.st).xyz; 

//      color = vec3(coords.yyx + coltmp); 
      color = vec3(coltmp) * cols; 
      // color = vec3(1.0, 0.0,0.0);
	} 
   	"; 
}
version (all) // linux
{
	enum builtInVertexShaderSource = " 
   	#version 120
    attribute vec3 pos; 
   	attribute vec2 texCoords;
   	//layout(location = 2) in vec3 col; 

   	//out vec2 coords; 
	//out vec3 cols;
	uniform mat4 MVP;
	
   	void main(void) 
   	{ 

       gl_Position = MVP * vec4(pos,1.0);
       gl_TexCoord[0] = vec4(texCoords,texCoords);
       gl_FrontColor = gl_Color;
 //      gl_Position = vec4(pos, 1.0); 
       //gl_FragCoord = texCoords.st; 
	 // gl_FragColor = col;
   	} 
   	"; 
	
	enum builtInFragmentShaderSource = " 
   	#version 120
	
   	uniform sampler2D colMap; 
	
	//in vec2 coords; 
	//in vec3 cols; 
	//out vec3 color;

   	void main(void) 
   	{ 
      //vec3 coltmp = texture2D(colMap, gl_FragCoord.st).xyz; 
gl_FragColor = texture2D(colMap, gl_TexCoord[0].st);
//      color = vec3(coords.yyx + coltmp); 
      //gl_FragColor = vec4(coltmp, 1.0); // * cols; 
      // color = vec3(1.0, 0.0,0.0);
	} 
   	"; 
}
	
	private static Shader builtInVertexShader_;
	private static Shader builtInFragmentShader_;
	
	static @property Shader builtInVertexShader()
	{
		if (builtInVertexShader_ is null)
			builtInVertexShader_ = new Shader(builtInVertexShaderSource, Shader.Type.Vertex);
		return builtInVertexShader_;
	}
	
	static @property Shader builtInFragmentShader()
	{
		if (builtInFragmentShader_ is null)
			builtInFragmentShader_ = new Shader(builtInFragmentShaderSource, Shader.Type.Fragment);
		return builtInFragmentShader_;
	}
	
	enum Type
	{
		Vertex,
		Fragment
	}
	
	package uint glShaderID = 0;
	
	this(const(char)[] source, Shader.Type type)
	{
		compileString(source, type);
	}
	
	bool compileString(const(char)[] source, Shader.Type type)
	{
		int shaderType = 0;
		final switch (type)
		{
			case Type.Vertex:
				shaderType = GL_VERTEX_SHADER;
				break;
			case Type.Fragment:
				shaderType = GL_FRAGMENT_SHADER;
				break;
		}
		int fshad = glCreateShader(shaderType); 
		const char * fptr = toStringz(source); 
		
		enforce(fshad != 0, "Couldn't create shader for : " ~ source);
		
		glShaderSource(fshad, 1, &fptr, null);
		int err = glGetError();
		import std.conv;
		enforce(err == GL_NO_ERROR, "Error setting shader source :" ~ err.to!string ~ " " ~ fshad.to!string ~ " " ~ source);

		glCompileShader(fshad);
		
		int status;
		glGetShaderiv(fshad, GL_COMPILE_STATUS, &status); 
		
		if(status == GL_FALSE)
		{ 
			int len;
			glGetShaderiv(fshad, GL_INFO_LOG_LENGTH, &len); 
			char[] error=new char[len]; 
			glGetShaderInfoLog(fshad, len, null, cast(char*)error); 
			
			throw new Exception(error.idup);
			// writeln(error); 
			//return false; 
		}
		glShaderID = fshad;
		return true; 
	}
}
/*
const string fshader2 = "
   #version 330 

in vec2 coords; 
out vec3 color;
		 
void main(void){
    color = vec3(1.0 * coords.x, 0 , 0);
}
				";
*/
