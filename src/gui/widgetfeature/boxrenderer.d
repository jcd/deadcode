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
		this.styleName = styleName;
		model = createQuad(Rectf(0,0,1,1));
	}
	
	override void draw(Widget widget)
	{
		Style style = widget.window.styleSet.getStyle(styleName);
		model.material = style.background;
		const Rectf r = Rectf(widget.rect);
		Rectf wrect = widget.window.windowToWorld(r);
		
		// Move model using translate to we do not have to update vertex position array
		auto transform = Mat4f.makeTranslate(Vec3f(wrect.x, wrect.y, 0));
		
		// All size changes need to adjust vertices and/or uvs.
		// Translation is done using transform so move rect to 0,0
		wrect.pos = Vec2f(0,0);
		float[] uv = quadUVForTextureMatchingRenderTargetPixels(wrect, model.material, widget.window.size);
		float[] vert = quadVertices(wrect);
		model.mesh.buffers[0].data = vert;
		model.mesh.buffers[1].data = uv;
		model.draw(widget.window.MVP * transform);
	}
}
