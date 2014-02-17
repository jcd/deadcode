module gui.models;

import graphics.buffer;
import graphics.material;
import graphics.model;
import graphics.rendertarget;
import graphics.texture;
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

void appendQuadVertices(Rectf worldRect, ref float[] verts)
{
	verts ~= [ 
		worldRect.x,  worldRect.y,  0f,
		worldRect.x,  worldRect.y2, 0f,
		worldRect.x2, worldRect.y2, 0f, 
		worldRect.x,  worldRect.y,  0f,
		worldRect.x2, worldRect.y2, 0f,
		worldRect.x2, worldRect.y,  0f ];			
}

float[] quadUVForTextureMatchingRenderTargetPixels(Rectf worldRect, Texture tex, Vec2f renderTargetPixelSize)
{
	return quadUVForTextureMatchingRenderTargetPixels(worldRect, renderTargetPixelSize / Vec2f(tex.width, tex.height));
}

float[] quadUVForTextureMatchingRenderTargetPixels(Rectf worldRect, Vec2f winTexRatio)
{
//	float windowMaxU = renderTargetPixelSize.x / tex.width;
//	float windowMaxV = renderTargetPixelSize.y / tex.height;

//	float u = (0.5f * worldRect.w) * windowMaxU;
//	float v = (0.5f * worldRect.h) * windowMaxV;

//	float u = (0.5f * worldRect.w) * winTexRatio.x;
//	float v = (0.5f * worldRect.h) * winTexRatio.y;

	Vec2f uv = (worldRect.size * 0.5) * winTexRatio;

	float[] c = [
		0f, 1f,
		0f, uv.y + 1f,
		uv.x,  uv.y + 1f,
		0f, 1f,
		uv.x,  uv.y + 1f,
		uv.x,  1f];
	
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
		0f, 0f,
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

void updateQuads(Model m, Rectf[] worldRects)
{
	float[] uv = [
		0f, 1f,
		0f, 1f,
		1f,  1f,
		0f, 1f,
		1f,  1f,
		1f,  0f];

	float[] verts;
	float[] uvs;

	foreach (r; worldRects)
	{
		appendQuadVertices(r, verts);
		uvs ~= uv;
	}

	//float[] uv = quadUVForTextureRenderTargetPixels(worldRect, mat, Window.active.size);
	float[] cols = new float[verts.length];
	std.algorithm.fill(cols, 1.0f);
	m.mesh.buffers[0].data = verts;
	m.mesh.buffers[1].data = uvs;
	m.mesh.buffers[2].data = cols;
}

Model createEmptyModel(Material mat = null)
{
	auto m = new Model;

	Buffer vertexBuf = Buffer.create();
	Buffer colorBuf = Buffer.create();
	Buffer vertCols = Buffer.create();

	Mesh mesh = Mesh.create();
	mesh.setBuffer(vertexBuf, 3, 0);	
	mesh.setBuffer(colorBuf, 2, 1);	
	mesh.setBuffer(vertCols, 3, 2);	

	m.mesh = mesh;
	m.material = mat;

	return m;
}

string dirtyProp(string type, string name, string dirtyField = "_dirty")
{
	return  "private " ~ type ~ " _" ~ name ~ ";" ~
		    type ~ " " ~ name ~ "() { return _" ~ name ~ "; }" ~
	//		"void " ~ name ~ "(" ~ type ~ " v) { " ~ dirtyField ~ " = v != _" ~ name ~ "; _" ~ name ~ " = v; }";
	"void " ~ name ~ "(" ~ type ~ " v) { " ~ dirtyField ~ " = true; _" ~ name ~ " = v; }";
}

enum ImageFill
{
	none,        // Image is rendered as is
	uniform,     // Image is scaled uniformly until it fills on one axis. Aspect ratio is kept.
	uniformFill, // Image is scaled uniformly until it fills the entire area, clipping if necessary. Aspect ratio is kept.
	fill,        // Image is scaled to fill. Aspect ratio is not kept.
	tile         // Image is tiled to fill. Aspect ration is kept.
}


struct Sprite
{
	Rectf rect; // Location on texture in pixels

	this(float x, float y, float w, float h)
	{
		rect = Rectf(x,y,w,h);
	}
}

/**
	
*/
class BoxModel
{
	@property 
	{
		mixin(dirtyProp("Rectf", "rect", "_dirtyRect"));  // window size rect
		mixin(dirtyProp("RectfOffset", "borders", "_dirtyBorders"));  // window size borders
		mixin(dirtyProp("ImageFill[4]", "borderFills", "_dirtyBorders")); // top, left, bottom, right
		mixin(dirtyProp("ImageFill", "centerFill", "_dirtyBorders"));
		mixin(dirtyProp("Sprite", "topLeft", "_dirtyBorders"));
		mixin(dirtyProp("Sprite", "top", "_dirtyBorders"));
		mixin(dirtyProp("Sprite", "topRight", "_dirtyBorders"));
		mixin(dirtyProp("Sprite", "left", "_dirtyBorders"));
		mixin(dirtyProp("Sprite", "center", "_dirtyBorders")); // Only this is used if RectfOffset is zero
		mixin(dirtyProp("Sprite", "right", "_dirtyBorders"));
		mixin(dirtyProp("Sprite", "bottomLeft", "_dirtyBorders"));
		mixin(dirtyProp("Sprite", "bottom", "_dirtyBorders"));
		mixin(dirtyProp("Sprite", "bottomRight", "_dirtyBorders"));

		Material material()
		{
			return _model.material;
		}
		void material(Material m)
		{
			_model.material = m;
		}

	}

	Vec3f color;

	private 
	{		
		Model _model;
		bool _dirtyRect;
		bool _dirtyBorders;
	}

	this(Sprite center, Material mat = null)
	{	
		this.center = center;
		_init(mat);
	}

	this(Sprite nineSprite, RectfOffset borders, Material mat = null)
	{	
		// Split up sprite into nine sub sprites based on the borders
		_borders = borders;

		setupDefaultNinePatch(nineSprite);
		_init(mat);
	}

	void setupDefaultNinePatch(Sprite nineSprite)
	{
		float x = nineSprite.rect.x;
		float y = nineSprite.rect.y;
		float x2 = nineSprite.rect.x2;
		float y2 = nineSprite.rect.y2;
		float w = nineSprite.rect.w;
		float h = nineSprite.rect.h;
		float bleft = _borders.left;
		float bright = _borders.right;
		float btop = _borders.top;
		float bbottom = _borders.bottom;

		_topLeft = Sprite(x, y, bleft, btop);
		_top = Sprite(x + bleft, y, w - bleft - bright, btop);
		_topRight = Sprite(x2 - bright, y, bright, btop);
		_right = Sprite(x2 - bright, y + btop, bright, h - btop - bbottom);
		_bottomRight = Sprite(x2 - bright, y2 - bbottom, bright, bbottom);
		_bottom = Sprite(x + bleft, y2 - bbottom, w - bleft - bright, bbottom);
		_bottomLeft = Sprite(x, y2 - bbottom, bleft, bbottom);
		_left = Sprite(x, y + btop, bleft, h - btop - bbottom);
		_center = Sprite(x + bleft, y + btop, w - bleft - bright, h - btop - bbottom);
		_dirtyBorders = true;
	}

	private void _init(Material mat)
	{
		color = Vec3f(1,1,1);
		_dirtyRect = true;
		
		_borderFills[0] = ImageFill.fill;
		_borderFills[1] = ImageFill.fill;
		_borderFills[2] = ImageFill.fill;
		_borderFills[3] = ImageFill.fill;
		_centerFill = ImageFill.fill;

		_model = new Model;
		Buffer vertexBuf = Buffer.create();
		Buffer colorBuf = Buffer.create();
		Buffer vertCols = Buffer.create();

		Mesh mesh = Mesh.create();
		mesh.setBuffer(vertexBuf, 3, 0);	
		mesh.setBuffer(colorBuf, 2, 1);	
		mesh.setBuffer(vertCols, 3, 2);	

		_model.mesh = mesh;
		_model.material = mat;
		_model.subModel.blend = true;
		_model.subModel.blendMode = 1;
	}

	private void update(RenderTarget renderTarget)
	{
		float[] verts;
		float[] uvs;

		// If border size or fill behaviour has changed then always recalculate uvs.
		// TODO: take into consideration that a resize of window will scale the rect but should recalc the
		// uvs. Just a performance optimization.
		bool recalcUVs = _dirtyBorders || (_dirtyRect && _centerFill != ImageFill.fill);
		
		Rectf worldRect = _rect; //  renderTarget.windowToWorld(_rect);
		
		// Swap coords from win to world x,y dir
		worldRect.y = -(worldRect.y + worldRect.h); // world is negative downwards, win is positive

		void fillUVs(Sprite s)
		{
			Rectf r = material.texture.pixelRectToUVRect(s.rect);
			
			uvs ~= [r.x, r.y2, r.x, r.y, r.x2, r.y,
					r.x, r.y2, r.x2, r.y, r.x2, r.y2];
			//uvs ~= [r.x, r.y, r.x, r.y2, r.x2, r.y2,
			// r.x, r.y, r.x2, r.y2, r.x2, r.y];
			//uvs ~= [
			//    0f, 0f,
			//    0f, 1f,
			//    1f,  1f,
			//    0f, 0f,
			//    1f,  1f,
			//    1f,  0f];
		}

		//void tileUVs(Sprite s)
		//{
		//    auto tex = material.texture;
		//    uvs ~= quadUVForTextureMatchingRenderTargetPixels(wrect, renderTarget.size / Vec2f(tex.width, tex.height));
		//    
		//}

		if (_borders.empty)
		{
			// No borders. A single quad will do
			appendQuadVertices(worldRect, verts);
			if (recalcUVs)
			{
				if (_centerFill == ImageFill.fill)
					fillUVs(center);
				else
				{
					auto tex = material.texture;
					uvs ~= quadUVForTextureMatchingRenderTargetPixels(worldRect, renderTarget.size / Vec2f(tex.width, tex.height));
				}
			}
		}
		else
		{
			float left = _borders.left;
			float right = _borders.right;
			float top = _borders.top;
			float bottom = _borders.bottom;

			//float left = renderTarget.pixelWidthToWorld(_borders.left);
			//float right = renderTarget.pixelWidthToWorld(_borders.right);
			//float top = renderTarget.pixelHeightToWorld(_borders.top);
			//float bottom = renderTarget.pixelHeightToWorld(_borders.bottom);

			Rectf r = Rectf(worldRect.x, worldRect.y2 - top, left, top);

			appendQuadVertices(r, verts); // top left

			appendQuadVertices(Rectf(worldRect.x + left, worldRect.y2 - top, 
			                         worldRect.w - right - left, top), verts); // top

			r.x = worldRect.x2 - right;
			appendQuadVertices(r, verts); // top right

			appendQuadVertices(Rectf(worldRect.x2 - right, worldRect.y + bottom, 
			                         right, worldRect.h - top - bottom), verts); // right

			r.y = worldRect.y;
			appendQuadVertices(r, verts); // bottom right
			
			appendQuadVertices(Rectf(worldRect.x + left, worldRect.y, 
									 worldRect.w - right - left, bottom), verts); // bottom

			r.x = worldRect.x;
			appendQuadVertices(r, verts); // bottom left

			appendQuadVertices(Rectf(worldRect.x, worldRect.y + bottom, 
									 left, worldRect.h - top - bottom), verts); // left

			appendQuadVertices(Rectf(worldRect.x + left, worldRect.y + bottom, 
									 worldRect.w - left - right, worldRect.h - top - bottom), verts); // center

			if (recalcUVs)
			{
				// TODO support tiling
				fillUVs(_topLeft);
				fillUVs(_top);
				fillUVs(_topRight);
				fillUVs(_right);
				fillUVs(_bottomRight);
				fillUVs(_bottom);
				fillUVs(_bottomLeft);
				fillUVs(_left);
				fillUVs(_center);
			}

		}
		
		_model.mesh.buffers[0].data = verts;

		//float[] uv = quadUVForTextureRenderTargetPixels(worldRect, mat, Window.active.size);
		float[] cols = new float[verts.length];
		foreach (i; 0..verts.length/3)
		{
			cols[i*3] = color.x;
			cols[i*3+1] = color.y;
			cols[i*3+2] = color.z;
		}

		// std.algorithm.fill(cols, 1.0f);
		_model.mesh.buffers[1].data = uvs;
		_model.mesh.buffers[2].data = cols;
		// _lastPixelWorldSize = pixelWorldSize;
		_dirtyBorders = false;
		_dirtyRect = false;
	}

	void draw(Mat4f transform)
	{	
		// Vec2f pixelWorldSize = Window.active.renderTarget.pixelSizeToWorld(Vec2f(1,1))

		if (_dirtyRect || _dirtyBorders) // || pixelWorldSize != _lastPixelWorldSize)
			update(Window.active.renderTarget);
		
		assert(_model.material !is null);
	
		_model.draw(transform);
	}

}
