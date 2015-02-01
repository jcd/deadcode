module graphics.buffer;

import derelict.opengl3.gl3;
import std.range : empty;

final class Buffer
{
	uint glBufferID = 0;
	float[] data;
	size_t uploadedSize;
	bool clear;

	static Buffer create(float[] indata = null)
	{
		Buffer b = new Buffer();
		b.clear = false;
		glGenBuffers(1, &(b.glBufferID));
		if (!indata.empty)
			b.data = indata;
		return b;
	}

	void upload()
	{
		glBindBuffer(GL_ARRAY_BUFFER, glBufferID);
		// Copy the data to gl buffer. Static draw: modify once, use many
		if (clear && data.empty)
		{
			glBufferData(GL_ARRAY_BUFFER, 0, null, GL_STATIC_DRAW);
			uploadedSize = 0;
		}
		else
		{
			glBufferData(GL_ARRAY_BUFFER, data.length * GL_FLOAT.sizeof, data.ptr, GL_STATIC_DRAW);
			uploadedSize = data.length;
		}
		clear = false;
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		//std.stdio.writeln("uploading ", data);
	}

	//
	void clearLocal()
	{
		//data = null;
        data.length = 0;
		assumeSafeAppend(data);
	}
}

