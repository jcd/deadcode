module graphics.rendertarget;

import math._;

// TODO: make a window render target and an renderbuffer render target
//
class RenderTarget
{
	alias void delegate() OnRender;
	protected
	{
		OnRender _onRender;
	}

	@property 
	{
		void onRender(OnRender callback)
		{
			_onRender = callback;
		}
		abstract Mat4f MVP() const;
		abstract Vec2i size() const;
		abstract void size(Vec2f s);
		abstract void size(Vec2i s);
		abstract Vec2f position() const;
		abstract void position(Vec2f pos);
	}

	this()
	{
		// Constructor code
	}

	abstract void render(bool _swapBuffers = true);
	abstract void swapBuffers();
	abstract Rectf windowToWorld(Rectf r);
	abstract Vec2f pixelSizeToWorld(Vec2f pixels);
	abstract Vec2f worldSizeToPixel(Vec2f worldUnits);
	abstract float pixelWidthToWorld(float x);
	abstract float pixelHeightToWorld(float y);
	abstract Vec2f worldToPixelPos(Vec2f src);

}
