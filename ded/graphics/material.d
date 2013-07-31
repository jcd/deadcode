module graphics.material;

import derelict.opengl3.gl3; 
import graphics.shaderprogram;
import graphics.texture;

final class Material
{
	private static Material builtIn_;
	
	static @property Material builtIn()
	{
		if (builtIn_ is null)
		{
			builtIn_ = new Material();
			builtIn_.shader = ShaderProgram.builtIn;
			builtIn_.texture = Texture.builtIn;
		}
		return builtIn_;
	}
	
	ShaderProgram shader;
	Texture texture;
	
	static Material create(const(char)[] imagePath)
	{
		Texture tex = Texture.create(imagePath);
		
		Material mat = new Material();
		mat.texture = tex;
		mat.shader = ShaderProgram.builtIn;
		return mat;
	}
	
	void bind()
	{
		shader.bind();
		texture.bind(0);
	}
	
	void unbind()
	{
		glBindTexture(GL_TEXTURE_2D, 0); 
	}
}
