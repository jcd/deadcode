module graphics.model;

import derelict.opengl3.gl3; 
import graphics.mesh : Mesh;
import graphics.material : Material;
import math._ : Mat4f;
import std.range : front;

final class Model(SubModelKey = int)
{
	final static class SubModel
	{
		Mesh mesh;
		Material material;
		bool blend;
		
		@property valid() const
		{
			return material.texture !is null;
		}
		void draw(Mat4f transform)
		{
			//material.shader.setUniform("colMap", 0);
			
			if (blend)
			{
				glEnable (GL_BLEND);
				//glDisable(GL_DEPTH_TEST);
				glDepthMask(GL_FALSE);
				glBlendFunc (GL_ONE, GL_ONE);
			}
			else
			{
				glDepthMask(GL_TRUE);
				glDisable (GL_BLEND);
				//glEnable(GL_DEPTH_TEST);
			}

			import gui.window : Window;
			material.shader.setUniform("MVP", Window.active.MVP * transform);
			material.bind();
			mesh.bind();
			//		material.shader.setUniform("MVP", Window.active.MVP * transform);
			mesh.draw();
			material.unbind();
			glBindVertexArray(0);
			glUseProgram(0);
		}
	}
	
	SubModel subModels[SubModelKey];
	
	SubModel addSubModel(SubModelKey key)
	{
		auto sm = new SubModel();
		subModels[key] = sm;
		return sm;
	}
	
	// Mesh of the first SubModel 
	@property 
	{
		Mesh mesh()
		{
			return subModels.values().front.mesh; 
		}
		
		void mesh(Mesh m)
		{
			subModels[subModels.keys().front].mesh = m;
		}
		
		Material material()
		{
			return subModels.values().front.material; 
		}
		
		void material(Material m)
		{
			subModels[subModels.keys().front].material = m;
		}
		
		@property valid() const
		{
			return subModels.values().front.valid;
		}
	}
	
	void draw(Mat4f transform)
	{
		foreach (m; subModels)
		{
			m.draw(transform);
		}
	}
}
