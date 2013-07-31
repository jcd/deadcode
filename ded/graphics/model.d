module graphics.model;

import derelict.opengl3.gl3; 
import graphics.mesh : Mesh;
import graphics.material : Material;
import math._ : Mat4f;
import std.range : front, empty;

final class SubModel
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
		
		material.shader.setUniform("MVP", transform);
		material.bind();
		mesh.bind();
		mesh.draw();
		material.unbind();
		glBindVertexArray(0);
		glUseProgram(0);
	}
}

final class Model
{
	SubModel[] subModels;
	
	SubModel createSubModel()
	{
		auto sm = new SubModel();
		subModels ~= sm;
		return sm;
	}

	void ensureSubModelExists()
	{
		if (subModels.empty)
			createSubModel();
	}

	// Mesh of the first SubModel 
	@property 
	{
		Mesh mesh()
		{
			ensureSubModelExists();
			return subModels.front.mesh; 
		}
		
		void mesh(Mesh m)
		{
			ensureSubModelExists();
			subModels.front.mesh = m;
		}
		
		Material material()
		{
			ensureSubModelExists();
			return subModels.front.material; 
		}
		
		void material(Material m)
		{
			ensureSubModelExists();
			subModels.front.material = m;
		}
		
		@property valid() const
		{
			return !subModels.empty && subModels.front.valid;
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
