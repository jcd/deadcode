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
    float cellHorizontalSpacing = 0f;
    float cellVerticalSpacing = 0f;

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


		auto rows = _direction == Direction.row ? _count : cast(int)(ceil(float(children.length) / float(_count)));
		auto cols = _direction == Direction.row ? cast(int)(ceil(float(children.length) / float(_count))) : _count;

        auto hSpace = max(0, cols - 2);
        auto vSpace = max(0, rows - 2);
        auto hSpacing = hSpace * cellHorizontalSpacing;
        auto vSpacing = vSpace * cellVerticalSpacing;

        rect.w -= hSpacing;
        rect.h -= vSpacing;

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

		struct MinMaxPreferred
        {
            float min;
            float max;
            float preferred;
        }

        MinMaxPreferred[] colWidths;
		colWidths.length = cols;
		colWidths[] = MinMaxPreferred(-float.infinity, float.infinity, 0f);
		MinMaxPreferred[] rowHeights;
		rowHeights.length = rows;
		rowHeights[] = MinMaxPreferred(-float.infinity, float.infinity, 0f);

		foreach (i, w; children)
		{
			if (w.manualLayout)
				continue;
			auto column = i % cols;
			auto row = i / cols;

            float fixedRowSize = fixedRowSizes[row];
            const bool hasFixedRowSize = fixedRowSize >= 0f;
            if (hasFixedRowSize)
            {
                MinMaxPreferred* r = &(rowHeights[row]);
                r.min = float.nan; // signal fixed height
                r.preferred = fixedRowSize;
            }
            else
            {
                MinMaxPreferred* r = &(rowHeights[row]);
                if (w.minHeight > r.min)
                    r.min = w.minHeight;
                if (w.maxHeight < r.max)
                    r.max = w.maxHeight;
                r.preferred = min(max(r.preferred, w.h, r.min), r.max);
            }

            float fixedColumnSize = fixedColumnSizes[column];
            const bool hasFixedColumnSize = fixedColumnSize >= 0f;
            if (hasFixedColumnSize)
            {
                MinMaxPreferred* r = &(colWidths[column]);
                r.min = float.nan; // signal fixed width
                r.preferred = fixedColumnSize;
            }
            else
            {
                MinMaxPreferred* r = &(colWidths[column]);
                if (w.minWidth > r.min)
                    r.min = w.minWidth;
                if (w.maxWidth < r.max)
                    r.max = w.maxWidth;
                r.preferred = min(max(r.preferred, w.w, r.min), r.max);
            }
		}

        MinMaxPreferred flexWidth = MinMaxPreferred(0f, 0f, 0f);
        float fixedWidth = 0f;
        foreach (row, ref r; colWidths)
        {
            float fixedColumnSize = fixedColumnSizes[row];
            const bool hasFixedColumnSize = fixedColumnSize >= 0f;
            if (hasFixedColumnSize)
            {
                fixedWidth += fixedColumnSize;
            }
            else
            {
                flexWidth.min += r.preferred - r.min;
                flexWidth.max +=  r.max - r.preferred;
                flexWidth.preferred += r.preferred;
            }
        }
        float deltaToPreferredWidth = rect.w - fixedWidth - flexWidth.preferred;

        MinMaxPreferred flexHeight = MinMaxPreferred(0f, 0f, 0f);
        float fixedHeight = 0f;
        foreach (col, ref r; rowHeights)
        {
            float fixedRowSize = fixedRowSizes[col];
            const bool hasFixedRowSize = fixedRowSize >= 0f;
            if (hasFixedRowSize)
            {
                fixedHeight += fixedRowSize;
            }
            else
            {
                flexHeight.min += r.preferred - r.min;
                flexHeight.max +=  r.max - r.preferred;
                flexHeight.preferred += r.preferred;
            }
        }
        float deltaToPreferredHeight = rect.h - fixedHeight - flexHeight.preferred;

        //float scaleWidthFactor = 1f;
        //if (deltaToPreferredWidth < 0f)
        //{
        //    // Need to scale down
        //    if (-deltaToPreferredWidth > flexWidth.min)
        //    {
        //        // Delta is larger that how much we can flex down and we are going to break a constraint here!
        //
        //    }
        //    scaleWidthFactor = (deltaToPreferredWidth + flexWidth.preferred) / flexWidth.preferred;
        //}
        //else if (deltaToPreferredWidth > 0f)
        //{
        //    if (deltaToPreferredWidth > flexWidth.max)
        //    {
        //        // Delta is larger that how much we can flex up and we are going to break a constraint here!
        //    }
        //    scaleWidthFactor = (deltaToPreferredWidth + flexWidth.preferred) / flexWidth.preferred;
        //}


        //
        ////float accumFixedWidth = reduce( (a,b) => b > 0 ? a+b : a )(0f, fixedColumnSizes);
        ////float accumFixedHeight = reduce( (a,b) => b > 0 ? a+b : a )(0f, fixedRowSizes);
        ////float accumFlexWidth = accumWidth - accumFixedWidth;
        ////float accumFlexHeight = accumHeight - accumFixedHeight;
        //float accumWidth = sum(colWidths);
        //float accumHeight = sum(rowHeights);
        //
        //float fixedWidth = reduce!((acc,elm) => elm < 0 ? acc : acc + elm)(0f, fixedColumnSizes);
        //float fixedHeight = reduce!((acc,elm) => elm < 0 ? acc : acc + elm)(0f, fixedRowSizes);
        //
        ////float widthLeft = rect.w - accumWidth;
        ////float heightLeft = rect.h - accumHeight;
        //
        //// We scale only the flex part of the col/row in case the accumulated size it too large/small
        //// TODO: handle when width/heightLeft is negatively larger that accumWidth/Height
        //float accumFlexWidth  = accumWidth - fixedWidth;
        //float accumFlexHeight = accumHeight - fixedHeight;
        //float scaleFlexWidth  = accumFlexWidth.isNormal ? (rect.w - fixedWidth ) / accumFlexWidth : 0f;
        //float scaleFlexHeight = accumFlexHeight.isNormal ? (rect.h - fixedHeight) / accumFlexHeight : 0f;

        //foreach (i; 0..rows)
        //{
        //    if (fixedRowSizes[i] < 0)
        //        rowHeights[i] = rowHeights[i].preferred * scaleHeightFactor;
        //    else
        //        rowHeights[i] = fixedRowSizes[i];
        //
        //}

        float lastDeltaToPreferredWidth = 0;
        bool changed = true;
        while (!approxEqual(deltaToPreferredWidth, lastDeltaToPreferredWidth, 1e-2, 0.1) && !approxEqual(deltaToPreferredWidth, 0f, 1e-2, 0.1) && changed)
        {
            lastDeltaToPreferredWidth = deltaToPreferredWidth;
            changed = false;
            float scaleWidthFactor = (deltaToPreferredWidth + flexWidth.preferred) / flexWidth.preferred;
		    foreach (i; 0..cols)
		    {
			    MinMaxPreferred* c = &(colWidths[i]);
                const isFixedWidthColumn = fixedColumnSizes[i] >= 0;
                if (isFixedWidthColumn)
                {
                    c.preferred = fixedColumnSizes[i];
                }
                else if (!c.min.isNaN())
                {
                    float newWidth = c.preferred * scaleWidthFactor;
                    float deltaWidth = newWidth - c.preferred;

                    if (!scaleWidthFactor.isFinite)
                    {
                        // flexHeight.preferred was 0f. Just split deltaHeights evenly among the rows;
                        newWidth = deltaToPreferredWidth / cols;
                        deltaWidth = newWidth;
                        c.min = float.nan; // signal stop of calc for this column
                    }

                    if (newWidth > c.max)
                    {
                        newWidth = c.max;
                        deltaWidth = newWidth - c.preferred;
                        c.min = float.nan; // signal stop of calc for this column
                    }
                    else if (newWidth < c.min)
                    {
                        newWidth = c.min;
                        deltaWidth = newWidth - c.preferred;
                        c.min = float.nan; // signal stop of calc for this column
                    }

                    flexWidth.preferred += deltaWidth;
                    c.preferred = newWidth;
                    deltaToPreferredWidth -= deltaWidth;
                    changed = true;
                }
		    }
        }


        float lastDeltaToPreferredHeight = 0;
        changed = true;
        while (!approxEqual(deltaToPreferredHeight, lastDeltaToPreferredHeight, 1e-2, 0.1) && !approxEqual(deltaToPreferredHeight, 0f, 1e-2, 0.1) && changed)
        {
            lastDeltaToPreferredHeight = deltaToPreferredHeight;
            changed = false;
            float scaleHeightFactor = (deltaToPreferredHeight + flexHeight.preferred) / flexHeight.preferred;
		    foreach (i; 0..rows)
		    {
			    MinMaxPreferred* c = &(rowHeights[i]);
                const isFixedHeightRow= fixedRowSizes[i] >= 0;
                if (isFixedHeightRow)
                {
                    c.preferred = fixedRowSizes[i];
                }
                else if (!c.min.isNaN())
                {
                    float newHeight = c.preferred * scaleHeightFactor;
                    float deltaHeight = newHeight - c.preferred;

                    if (!scaleHeightFactor.isFinite)
                    {
                        // flexHeight.preferred was 0f. Just split deltaHeights evenly among the rows;
                        newHeight = deltaToPreferredHeight / rows;
                        deltaHeight = newHeight;
                        c.min = float.nan; // signal stop of calc for this row
                    }

                    if (newHeight > c.max)
                    {
                        newHeight = c.max;
                        deltaHeight = newHeight - c.preferred;
                        c.min = float.nan; // signal stop of calc for this row
                    }
                    else if (newHeight < c.min)
                    {
                        newHeight = c.min;
                        deltaHeight = newHeight - c.preferred;
                        c.min = float.nan; // signal stop of calc for this row
                    }

                    flexHeight.preferred += deltaHeight;
                    c.preferred = newHeight;
                    deltaToPreferredHeight -= deltaHeight;
                    changed = true;
                }
		    }
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
				offset.y = offset.y + (row == 0 ? 0f : rowHeights[row-1].preferred + cellVerticalSpacing);
			}

			w.pos = offset;
			w.w = colWidths[column].preferred;
			w.h = rowHeights[row].preferred;

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

			offset.x = offset.x + w.w + cellHorizontalSpacing;
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
