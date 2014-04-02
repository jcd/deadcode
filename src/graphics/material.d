module graphics.material;

import derelict.opengl3.gl3; 
import graphics.shaderprogram;
import graphics.texture;

class Material 
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
	
	protected ShaderProgram _shader;
	protected Texture _texture;

	@property ShaderProgram shader()
	{
		return _shader;
	}

	@property void shader(ShaderProgram s)
	{
		_shader = s;
	}

	@property Texture texture()
	{
		return _texture;
	}

	@property void texture(Texture t)
	{
		_texture = t;
	}
	
	@property bool hasTexture() const
	{
		return _texture !is null;
	}

	@property bool hasShader() const
	{
		return _shader !is null;
	}

	static Material create(const(char)[] imagePath)
	{
		Texture tex = Texture.create(imagePath);
		
		Material mat = new Material();
		mat._texture = tex;
		mat._shader = ShaderProgram.builtIn;
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
