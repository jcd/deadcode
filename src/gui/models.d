module gui.models;

import graphics.buffer;
import graphics.material;
import graphics.model;
//import gui.style; // : Style;
import gui.window;
import math._;
import std.range;
import std.container;

Model createTriangle()
{
	float[] v = [   -0.75f, -0.75f, 0.0f, 
                  0.75f, 0.75f, 0.0f, 
                  -0.75f, 0.75f, 0.0f]; 
	float[] c = [   0.0f, 0.0f, 
                  1.0f, 1.0f, 
                  0.0f, 1.0f]; 
	float[] cols = new float[v.length];
	std.algorithm.fill(cols, 1.0f);
	
	Buffer vertexBuf = Buffer.create(v);
	Buffer colorBuf = Buffer.create(c);
	Buffer vertCols = Buffer.create(cols);	
	
	Mesh mesh = Mesh.create();
	mesh.setBuffer(vertexBuf, 3, 0);
	mesh.setBuffer(colorBuf, 2, 1);
	mesh.setBuffer(colorBuf, 3, 2);
 
	auto m = new Model();
	m.mesh = mesh;
	m.material = Material.builtIn;
	
	return m;
}


float[] quadVertices(Rectf worldRect)
{
	float[] verts = [ 
		worldRect.x,  worldRect.y,  0f,
		worldRect.x,  worldRect.y2, 0f,
		worldRect.x2, worldRect.y2, 0f, 
		worldRect.x,  worldRect.y,  0f,
		worldRect.x2, worldRect.y2, 0f,
		worldRect.x2, worldRect.y,  0f ];			
	return verts;	
}

float[] quadUVForTextureMatchingRenderTargetPixels(Rectf worldRect, Material mat, Vec2f renderTargetPixelSize)
{
	float windowMaxU = renderTargetPixelSize.x / mat.texture.width;
	float windowMaxV = renderTargetPixelSize.y / mat.texture.height;
	float u = (0.5f * worldRect.w) * windowMaxU;
	float v = (0.5f * worldRect.h) * windowMaxV;
	float[] c = [
		0f, 1f,
		0f, v + 1f,
		u,  v + 1f,
		0f, 1f,
		u,  v + 1f,
		u,  1f];
	/*float[] c = [
		0f, v,
		0f, 0f,
		u, 0f,
		0f, v,
		u, 0f,
		u, v ];*/
	return c;
}

/*
Model createRdenderTargetQuad(Rectf pixelRect, Material mat, RenderWindow win)
{
	Rectf rect = win.windowToWorld(pixelRect);
	return createQuad(rect, mat);
}
*/

Model createQuad(Rectf worldRect, Material mat = null)
{
	auto m = new Model;
	float[] vert = quadVertices(worldRect);
	float[] uv = [
		0f, 1f,
		0f, 1f,
		1f,  1f,
		0f, 1f,
		1f,  1f,
		1f,  0f];
	//float[] uv = quadUVForTextureRenderTargetPixels(worldRect, mat, Window.active.size);
	float[] cols = new float[vert.length];
	std.algorithm.fill(cols, 1.0f);
	Buffer vertexBuf = Buffer.create(vert);
	Buffer colorBuf = Buffer.create(uv);
	Buffer vertCols = Buffer.create(cols);
	
	Mesh mesh = Mesh.create();
	mesh.setBuffer(vertexBuf, 3, 0);	
	mesh.setBuffer(colorBuf, 2, 1);	
	mesh.setBuffer(vertCols, 3, 2);	

	m.mesh = mesh;
	m.material = mat;
	
	return m;
}

