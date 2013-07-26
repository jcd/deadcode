module graphics.mesh;

import derelict.opengl3.gl3; 
import graphics.buffer : Buffer;
import std.range : empty;

final class Mesh
{
	uint glVertexArrayID = 0;
	Buffer[] buffers;
	
	static Mesh create()
	{
		Mesh m = new Mesh();
		glGenVertexArrays(1, &(m.glVertexArrayID)); 
		assert(m.glVertexArrayID > 0); 
		return m;
	}
	
	void setBuffer(Buffer buf, int size, int location)
	{
		glBindVertexArray(glVertexArrayID); 
		glBindBuffer(GL_ARRAY_BUFFER, buf.glBufferID); 
		glEnableVertexAttribArray(location); 
		glVertexAttribPointer(location, size, GL_FLOAT, GL_FALSE, 0, null);          
		glBindBuffer(GL_ARRAY_BUFFER, 0); 
		glBindVertexArray(0);  	
		if (buffers.length < (location+1))
			buffers.length = location + 1;
		buffers[location] = buf;
	} 
	
	void bind()
	{
		glBindVertexArray(glVertexArrayID);
	}
	
	void clear()
	{
		foreach (buffer; buffers)
		{
			buffer.clear = true;
		}
	}
	
	void draw()
	{
		// upload dirty buffers to gpu
		foreach (buffer; buffers)
		{
			if (!buffer.data.empty || buffer.clear)
				buffer.upload();
			buffer.clearLocal();
		}
		
		// do the drawing dance
		if (buffers[0].uploadedSize != 0)
		{
			glDrawArrays(GL_TRIANGLES, 0, buffers[0].uploadedSize / 3); 
		}
	}
}