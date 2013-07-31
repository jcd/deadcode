module gui.models;

import graphics._;
import gui.style; // : Style;
import gui.window;
import math._;
import std.range;
import std.container;
import styledtext;

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


float[] quadVertices(Rectf r)
{
	float[] verts = [ 
		r.x,  r.y,  0f,
		r.x,  r.y2, 0f,
		r.x2, r.y2, 0f, 
		r.x,  r.y,  0f,
		r.x2, r.y2, 0f,
		r.x2, r.y,  0f ];			
	return verts;	
}

float[] quadUVs(Rectf rect, Material mat, Window win)
{
	Vec2i winSize = win.size;
	float windowMaxU = winSize.x / mat.texture.width;
	float windowMaxV = winSize.y / mat.texture.height;
	float u = (0.5f * rect.w) * windowMaxU;
	float v = (0.5f * rect.h) * windowMaxV;
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

Model createWindowQuad(Rectf windowRect, Material mat)
{
	Rectf rect = Window.active.windowToWorld(windowRect);
	return createQuad(rect, mat);
}

Model createQuad(Rectf rect, Material mat)
{
	auto m = new Model;
	rect.pos = Vec2f(0,0);
	
	float[] vert = quadVertices(rect);
	float[] uv = quadUVs(rect, mat, Window.active);
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

