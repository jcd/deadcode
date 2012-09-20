module render;

import std.container;
import graphics;
import math;
import font;

alias BinaryHeap!(Token[], "a.begin > b.begin") Heap;

// Reuse of temporary float arrays during rendering.
private
{
	// Keep verts and uv arrays for reuse in order
	// to prevent allocating new arrays all the time
	float[] verts;
	float[] cols;
	float[] uvs;
}

// Token pointing into a text buffer to specify attributes of the token
// such as color etc.
struct Token
{
	uint begin;
	uint end;
	Vec3f color;
}

/** Render a text range as into a text model
 */
Vec2f setTextMesh(R)(Model textModel, R str, Heap toks, Font font, Mesh target, Rectf box, size_t charOfInterest, Vec2f charAtCoords, bool wrap = true)
{
	float sx = box.x;
	Vec2f pos = Vec2f(sx, box.y - Window.active.pixelHeightToWorld(font.fontLineSkip));
	
	// Estimate buffer sizes
	verts.length = str.length * 18; // 6 vertices
	cols.length = str.length * 18; // 6 vertices
	uvs.length = str.length * 12;   // 6 uvs

	size_t idx = 0;
	size_t handled = 0;
	bool skip = false;
	charOfInterest++;
	Vec2f poi = Vec2f(0,0);
	
	auto nextToken = Token.init;
	
	if (!toks.empty)
	{
		nextToken = toks.front;
		toks.removeFront();
	}

	foreach (ch; str)
	{			
		handled++;
		if (charOfInterest == handled && !skip)
			poi = pos;

		if (ch == '\n')
		{
			skip = false;
			pos.x = sx;
			pos.y -= Window.active.pixelHeightToWorld(font.fontLineSkip);
			continue;
		}
		
		if (ch == '\r' || skip)
			continue;
		
		if (ch == '\t')
		{
			pos.x += Window.active.pixelWidthToWorld(font.fontWidth * 0.5) * 4;
			continue;
		}
		
		if (ch == ' ')
		{
			pos.x += Window.active.pixelWidthToWorld(font.fontWidth * 0.5);
			continue;
		}

		if (pos.x >= box.x2)
		{
			if (wrap)
			{
				pos.x = sx;
				pos.y -= Window.active.pixelHeightToWorld(font.fontLineSkip);
			} 
			else
			{
				skip = true;
				continue;
			}
		}

		if (pos.y < box.y2)
		{
			skip = true; // signal that cursor might be out of visible area
			break; 
		}
					
		// Lookup glyph in font
		auto g = font.lookupGlyph(ch);
		auto offsetRect = Rectf(Window.active.pixelSizeToWorld(g.offsetRect.pos), 
								Window.active.pixelSizeToWorld(g.offsetRect.size));
		Rectf o = offsetRect + pos;
		//std.stdio.writeln(o);
		//o.size *= 1f;
		//o = Rectf(0,0,1,1);
		Rectf c = g.uvRect;
		//c = Rectf(Vec2f(c.pos.x, -c.pos.y), c.size);
		//c.pos *= 2.05f;
		//c.size *= 1.0f;
			
		size_t base = idx*18;
		
		// TODO: optimize using e.g slices
		verts[base..base+2] = o.pos.v[];
		//verts[base+0] = o.x;
		//verts[base+1] = o.y;
		verts[base+2] = 0f;
		
		verts[base+3] = o.x;
		verts[base+4] = o.y2;
		verts[base+5] = 0f;

		verts[base+6] = o.x2;
		verts[base+7] = o.y2;
		verts[base+8] = 0f;

		verts[base+9] = o.x;
		verts[base+10] = o.y;
		verts[base+11] = 0f;

		verts[base+12] = o.x2;
		verts[base+13] = o.y2;
		verts[base+14] = 0f;

		verts[base+15] = o.x2;
		verts[base+16] = o.y;
		verts[base+17] = 0f;

		uint h = handled - 1;
		if (nextToken.begin <= h && nextToken.end > h)
		{
			for (int i = 0; i < 6; i++)
			{
				cols[base+i*3] = nextToken.color.x;
				cols[base+i*3+1] = nextToken.color.y;
				cols[base+i*3+2] = nextToken.color.z;
			}
			if (nextToken.end - 1 == h && !toks.empty)
			{
				nextToken = toks.front;
				toks.removeFront();
			}
		}
		else
		{
			for (int i = 0; i < 6; i++)
			{
				cols[base+i*3] = 1.0f;
				cols[base+i*3+1] = 1.0f;
				cols[base+i*3+2] = 1.0f;
			}
		}
		
		base = idx*12;

		uvs[base+0] = c.x;
		uvs[base+1] = c.y;
		
		uvs[base+2] = c.x;
		uvs[base+3] = c.y2;

		uvs[base+4] = c.x2;
		uvs[base+5] = c.y2;

		uvs[base+6] = c.x;
		uvs[base+7] = c.y;

		uvs[base+8] = c.x2;
		uvs[base+9] = c.y2;

		uvs[base+10] = c.x2;
		uvs[base+11] = c.y;
		
//			pos.x += Window.active.pixelWidthToWorld(font.fontWidth);
		pos.x += Window.active.pixelWidthToWorld(g.advance);
		//pos += Vec2f(0.3f);
		idx++;
	}
	verts.length = idx * 18;
	uvs.length = idx * 12;
	textModel.mesh.buffers[0].setData(verts);
	textModel.mesh.buffers[1].setData(uvs);
	textModel.mesh.buffers[2].setData(cols);

	//std.stdio.writeln(uvs.length);
	//std.stdio.writeln(verts.length);
	
	// Special case when cursor poi is after the very last char in str 
	if (handled == str.length && charOfInterest == (handled+1) && !skip)
		poi = pos;
	
	return poi;
}
