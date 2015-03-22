module graphics.rendertarget;

import math;

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
		abstract uint id();
		abstract Mat4f MVP() const;
		abstract Vec2i size() const;
		abstract void size(Vec2f s);
		abstract void size(Vec2i s);
		abstract Vec2f position() const;
		abstract void position(Vec2f pos);
	}

    
	abstract void render(bool _swapBuffers = true);
	abstract void swapBuffers();

    /** Convert a size in pixels to a size in world coordinate at z = 0
     */
    Vec2f pixelSizeToWorld(Vec2f pixels)
    {
        Vec2i s = size;
        pixels.x /= s.x * 0.5f;
        pixels.y /= s.y * 0.5f;
        return pixels;
    }

    /** Convert a size in pixels to a size in world coordinate at z = 0
     */
    Vec2f worldSizeToPixel(Vec2f worldUnits)
    {
        Vec2i s = size;
        worldUnits *= 0.5f;
        return Vec2f(s.x * worldUnits.x, s.y * -worldUnits.y);
    }

    /// ditto
    float pixelWidthToWorld(float x)
    {
        x /= size.x * 0.5f;
        return x;
    }

    /// ditto
    float pixelHeightToWorld(float y)
    {
        y /= size.y * 0.5f;
        return y;
    }

    /** Window pixel coordinate to world coordinate at z = 0
     */
    Vec2f windowToWorld(float x, float y)
    {
        // world goes from (-1,-1) to (1,1)
        Vec2i s = size;
        return Vec2f(2f * x / s.x - 1f, -2f * y / s.y + 1f);
    }

    /// ditto
    Vec2f windowToWorld(Vec2f src)
    {
        return windowToWorld(src.x, src.y);
    }

    /** Window pixel coordinate to world coordinate at z = 0
     */
    Rectf windowToWorld(float x1, float y1, float x2, float y2)
    {
        // world goes from (-1,-1) to (1,1)
        Vec2f pTopLeft = windowToWorld(x1, y1);
        Vec2f pLowRight = windowToWorld(x2, y2);
        auto r = Rectf(pTopLeft.x, pTopLeft.y, 0, 0);
        r.x2 = pLowRight.x;
        r.y2 = pLowRight.y;
        return r;
    }

    Rectf windowToWorld(Rectf r)
    {
        return windowToWorld(r.x, r.y, r.x2, r.y2);
    }

    /** World coordinate (ignoring z) to window pixel coordinate
     */
    Vec2f worldToPixelPos(Vec2f src)
    {
        // world goes from (-1,-1) to (1,1)
        Vec2i s = size;
        return Vec2f(( 0.5f * src.x + 0.5f) * s.x, ( 0.5f * -src.y + 0.5f) * s.y);
    }

    Rectf worldToWindow(Rectf r)
    {
        Vec2f winPos = worldToPixelPos(r.pos);
        Vec2f winSize = worldSizeToPixel(r.size);
        return Rectf(winPos, winSize);
    }
}


class NullRenderTarget : RenderTarget
{

    static uint _nextID = 1;
    private
    {
        uint _id;
        string _name;
        Vec2i _size;
        Vec2f _pos;
        Mat4f _MVP;
    }
        @property
            {
                override uint id() { return _id; }
                override Mat4f MVP() const { return _MVP; }
                override Vec2i size() const { return _size; }
                override void size(Vec2i s) { _size = s; }
                override void size(Vec2f s) {
                    _size = Vec2i(cast(int)s.x, cast(int)s.y);
                }
                override Vec2f position() const { return _pos; }
                override void position(Vec2f pos) { _pos = pos; }
            }

        this(const(char)[] name, Vec2i sz)
            {
                this(name, sz.x, sz.y);
            }

        this(const(char)[] name, int width, int height)
            {
                _name = name.idup;
                _id = _nextID++;
                _size.x = width;
                _size.y = height;
                _pos = Vec2f(0,0);

                Mat4f proj = Mat4f.orthographic(-1,1,-1,1,1,100);
                Mat4f view = Mat4f.makeTranslate(Vec3f(0.0,0.0,10.0f));
                _MVP = proj * view;
            }

        override void render(bool _swapBuffers = true)
        {
            if (_onRender !is null)
                _onRender();
        }
        override void swapBuffers() {}
}
