module gui.widgetfeature.ninegridrenderer;

import graphics.model;
import gui.models;
import gui.style;
import gui.widget;
import gui.widgetfeature._;
import math._;


/** A 9 grid model for rendering boxes with expandables borders

	-----------------
	|  |         |  |
	-----------------
	|  |         |  |
	|  | content |  |
	|  |         |  |
	-----------------
	|  |         |  |
	-----------------

	The four corners of the widget are draw with fixed size images.
	The four sides are draw with images that can expand horizontally/vertically depending on axis of the side
	The center is either tiling or streching depending of style setting.

	All these settings are stored in the style.
*/
class NineGridRenderer : WidgetFeature 
{
	string styleName;
	BoxModel model;
	private RectfOffset _spriteBorder;
	private Rectf _spriteRect;

	@property void color(Color col) 
	{
		model.color = col;
	}
	
	this(string styleName = DefaultStyleName)
	{
		this.styleName = styleName;
		// model = new BoxModel(Sprite(0,0,160,160), RectfOffset(6,6,6,6));
		//model = createQuad(Rectf(0,0,1,1));
	}
/*
	Model createQuad(Rectf worldRect, Material mat = null)
	{
		auto m = new Model;
	//	float[] vert = quadVertices(worldRect);
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
*/
	override void draw(Widget widget)
	{
		Style style = widget.style; 
		auto mat = style.background;
		if (mat is null || mat.texture is null) 
			return;

		Mat4f transform;
		widget.getStyledScreenToWorldTransform(transform);
		
		RectfOffset spriteBorder = style.backgroundSpriteBorder;
		Rectf spriteRect = style.backgroundSprite;
		//
		//if (widget.id == 8)
		//    std.stdio.writeln("w8 dpos ", widget.rect.h);

		if (model is null)
		{
			model = new BoxModel(widget.id, Sprite(spriteRect),  spriteBorder);
			_spriteBorder = spriteBorder;
			_spriteRect = spriteRect;
		} 
		else if (_spriteRect != spriteRect || _spriteBorder != spriteBorder)
		{
		    model.borders = spriteBorder;
			model.setupDefaultNinePatch(Sprite(spriteRect));
			_spriteBorder = spriteBorder;
			_spriteRect = spriteRect;
		}

//		auto wr = widget.rectStyled.size;
		auto wr = widget.rect.size;
		model.rect =  Rectf(0, 0, wr);
		model.material = mat;
		color = style.backgroundColor;
		
		model.draw(widget.window.MVP * transform);
		
		//Style style = widget.window.styleddSet.getStyle(styleName);
		//model.material = style.background;
		//const Rectf r = Rectf(widget.rect);
		//Rectf wrect = widget.window.windowToWorld(r);
		//
		//// Move model using translate to we do not have to update vertex position array
		//auto transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0));
		//
		//// All size changes need to adjust vertices and/or uvs.
		//// Translation is done using transform so move rect to 0,0
		//wrect.pos = Vec2f(0,0);
		//float[] uv = quadUVForTextureMatchingRenderTargetPixels(wrect, model.material.texture, widget.window.size);
		//float[] vert = quadVertices(wrect);
		//model.mesh.buffers[0].data = vert;
		//model.mesh.buffers[1].data = uv;
		//model.draw(widget.window.MVP * transform);
	}
}
