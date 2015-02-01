module graphics.model;

import derelict.opengl3.gl3;
import graphics.mesh : Mesh;
import graphics.material : Mat = Material;
import math : Mat4f;
import std.range : front, empty;

final class SubModel
{
	Mesh mesh;
	Mat material;
	bool blend;
	int blendMode = 0;

	@property valid() const
	{
		return material.hasTexture;
	}

	void draw(Mat4f transform)
	{
		//material.shader.setUniform("colMap", 0);

		if (blend)
		{
			glEnable (GL_BLEND);
			//glDisable(GL_DEPTH_TEST);
			glDepthMask(GL_FALSE);
			if (blendMode == 0)
				glBlendFunc (GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
			else
				glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
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
		sm.blend = true;
		sm.blendMode = 1;
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

		Mat material()
		{
			ensureSubModelExists();
			return subModels.front.material;
		}

		void material(Mat m)
		{
			ensureSubModelExists();
			subModels.front.material = m;
		}

		SubModel subModel()
		{
			return subModels.front;
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
