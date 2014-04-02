module gui.widgetfeature.boxrenderer;

import graphics.model;
import gui.models;
import gui.style;
import gui.widget;
import gui.widgetfeature._;
import math._;

class BoxRenderer : WidgetFeature 
{
	string styleName;
	Model model;
		
	this(string styleName = DefaultStyleName)
	{
		//model = new BoxModel(Sprite(0,0,256,256), RectfOffset(1,1,1,1));
		//model.color = Vec3f(0.25, 0.25, 0.25);

		this.styleName = styleName;
		model = createQuad(Rectf(0,0,1,1));
	}
	
	override void draw(Widget widget)
	{
		Style style = widget.style;
		if (style is null)
			return;
		model.material = style.background;
		//Rectf r2 = widget.rect;
		//r.y = (-r.y) - r.h;
		
	//	Rectf r = Rectf(0,24,1000,1000);
		//model.rect = r2;

	//	Mat4f transform;
	//	widget.getScreenToWorldTransform(transform);
	//	model.draw(widget.window.MVP * transform);
		
	


		const Rectf r = Rectf(widget.rect);
		Rectf wrect = widget.window.windowToWorld(r);
		
		// Move model using translate to we do not have to update vertex position array
		auto transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0));
		// model.draw(widget.window.MVP * transform);

		// All size changes need to adjust vertices and/or uvs.
		// Translation is done using transform so move rect to 0,0
		wrect.pos = Vec2f(0,0);
		// float[] uv = quadUVForTextureMatchingRenderTargetPixels(wrect, , );
		auto tex = model.material.texture;
		float[] uv = quadUVForTextureMatchingRenderTargetPixels(wrect, widget.window.size / Vec2f(tex.width, tex.height));
		float[] vert = quadVertices(wrect);
		model.mesh.buffers[0].data = vert;
		model.mesh.buffers[1].data = uv;
		model.draw(widget.window.MVP * transform);
	}
}
