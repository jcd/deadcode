module gui.layout.gridlayout;

import gui.event;
import gui.widget;
import gui.layout;
import math;

import std.algorithm;
import std.math;

/** Layouting of child widgets
*
* When this feature is set on a widget all child widgets will
* be layed by this class.
*/
class GridLayout : ILayout
{
	float[] fixedRowSizes;    // if < 0 then row is not fixed
	float[] fixedColumnSizes; // if < 0 then column is not fixed

	int _count = 1;

	enum Direction
	{
		row,    // Row count is fixed by _count
		column  // Column count is fixed by _count
	}
	Direction _direction;

	@property Direction direction() const pure nothrow @safe
	{
		return _direction;
	}

	this(Direction dir, int count)
	{
		_direction = dir;
		_count = count;
	}

	override protected void layout(Widget widget, bool fit)
	{
		// Get sized ready for the children so that any layouter have them
		auto children = widget.children;
		RectfOffset padding = widget.style.padding;
		Rectf wrect = widget.rect;
		Rectf rect = Rectf(wrect.x + padding.left, wrect.y + padding.top,
						   wrect.w - padding.left - padding.right, wrect.h - padding.top - padding.bottom);

		auto rows = _direction == Direction.row ? _count : children.length / _count;
		auto cols = _direction == Direction.row ? children.length / _count : _count;

		if (rows > fixedRowSizes.length)
		{
			auto d = rows - fixedRowSizes.length;
			fixedRowSizes.length = rows;
			fixedRowSizes[fixedRowSizes.length - d..$] = -1f;
		}

		if (cols > fixedColumnSizes.length)
		{
			auto d = cols - fixedColumnSizes.length;
			fixedColumnSizes.length = cols;
			fixedColumnSizes[fixedColumnSizes.length - d..$] = -1f;
		}

		float[] colWidths;
		colWidths.length = cols;
		colWidths[] = 0f;
		float[] rowHeights;
		rowHeights.length = rows;
		rowHeights[] = 0f;

		foreach (i, w; children)
		{
			if (w.manualLayout)
				continue;
			auto column = i % cols;
			auto row = i / cols;

			rowHeights[row] = fixedRowSizes[row] < 0f ? max(rowHeights[row], w.h) : fixedRowSizes[row];
			colWidths[column] = fixedColumnSizes[column] < 0f ? max(colWidths[column], w.w) : fixedColumnSizes[column];
		}

		//float accumFixedWidth = reduce( (a,b) => b > 0 ? a+b : a )(0f, fixedColumnSizes);
		//float accumFixedHeight = reduce( (a,b) => b > 0 ? a+b : a )(0f, fixedRowSizes);
		//float accumFlexWidth = accumWidth - accumFixedWidth;
		//float accumFlexHeight = accumHeight - accumFixedHeight;
		float accumWidth = sum(colWidths);
		float accumHeight = sum(rowHeights);
		float fixedWidth = reduce!((acc,elm) => elm < 0 ? acc : acc + elm)(0f, fixedColumnSizes);
		float fixedHeight = reduce!((acc,elm) => elm < 0 ? acc : acc + elm)(0f, fixedRowSizes);

		//float widthLeft = rect.w - accumWidth;
		//float heightLeft = rect.h - accumHeight;

		// We scale only the flex part of the col/row in case the accumulated size it too large/small
		// TODO: handle when width/heightLeft is negatively larger that accumWidth/Height
		float accumFlexWidth  = accumWidth - fixedWidth;
        float accumFlexHeight = accumHeight - fixedHeight;
        float scaleFlexWidth  = accumFlexWidth.isNormal ? (rect.w - fixedWidth ) / accumFlexWidth : 0f;
		float scaleFlexHeight = accumFlexHeight.isNormal ? (rect.h - fixedHeight) / accumFlexHeight : 0f;

		foreach (i; 0..rows)
		{
			if (fixedRowSizes[i] < 0)
				rowHeights[i] = rowHeights[i] * scaleFlexHeight;
            import std.math;
            if (!isFinite(rowHeights[i]))
            {
                auto dd = rowHeights[i];
            }
		}

		foreach (i; 0..cols)
		{
			if (fixedColumnSizes[i] < 0)
				colWidths[i] = colWidths[i] * scaleFlexWidth;
		}


		// Scale the flex row and heights

		// TODO: support padding
		Vec2f offset = rect.pos;
		// float lastRowHeight = 0f;
		foreach (i, w; children)
		{
			if (w.manualLayout)
				continue;

			auto column = i % cols;
			auto row = i / cols;

			if (column == 0)
			{
				offset.x = rect.pos.x;
				offset.y = offset.y + (row == 0 ? 0f : rowHeights[row-1]);
			}

			w.pos = offset;
			w.w = colWidths[column];
			w.h = rowHeights[row];

			//// TODO: scale the flex cell according the max flex cell size
			//if (fixedRowSize >= 0)
			//    w.h = fixedRowSize;
			//else if (scaleFlexHeight != 1f)
			//    w.h = w.h * scaleFlexHeight;
			//
			//lastRowHeight = max(lastRowHeight, w.h);
			//
			//auto fixedColumnSize = fixedColumnSizes[column];
			//if (fixedColumnSize >= 0)
			//    w.w = fixedColumnSize;
			//else if (scaleFlexWidth != 1f)
			//    w.w = w.w * scaleFlexWidth;

			offset.x = offset.x + w.w;
		}

		//auto rowChildren = widget.children;;
		//while (!rowChildren.empty)
		//{
		//    foreach(i, w; rowChildren.take(cols))
		//    {
		//
		//    }
		//
		//    rowChildren.popFrontN(cols);
		//}
	}
}
