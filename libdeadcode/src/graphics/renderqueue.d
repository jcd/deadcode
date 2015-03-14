module graphics.renderqueue;

import graphics.camera;
import graphics.model;
import graphics.rendertarget;
import math;

class renderqueue
{
	private Model[] queue;

	void add(Model m)
	{
		// TODO: use appender... or not now that assumeSafeAppend is used.
		queue ~= m;
	}

	private void sort()
	{
		// Front to back sort
		// First render all opaque models with depth buffer write enabled
		// Then render all transparent objects with depth buffer write disabled

	}

	void render(Camera cam, RenderTarget target)
	{
		Mat4f transform;
		sort();
		foreach (m; queue)
		{
			m.draw(transform);
		}
	}

	void clear()
	{
		queue.length = 0;
	    assumeSafeAppend(queue);
    }
}
