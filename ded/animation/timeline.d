module animation.timeline;

import animation.animator;
import animation.interpolate;

import core.time;

import std.container;

class Timeline
{
private:
	class _Anim
	{
		this (AnimatorBase a, float d, float s) 
		{
			animator = a;
			duration = d;
			start = s;
		}
		AnimatorBase animator;
		float duration;
		float start;
		bool removeWhenDone;
		_Anim next;
	}

	_Anim _schedule; 
	_Anim _head;
public:
	InterpolateTimer timer;

	this()
	{
		this(dur!"weeks"(56));
	}

	this(Duration duration)
	{
		timer = new InterpolateTimer(duration);
	}

	AnimatorBase animate(ref float target, float endValue, float duration, float start = float.max)
	{
		auto a = new Animator!float(&target, new CubicInterpolator(target, endValue));
		insert(a, duration, start);
		return a;
	}

	private void insert(AnimatorBase anim, float duration, float start = float.max)
	{
		_Anim prev = null;
		_Anim cur = _schedule;
		_Anim newAnim = new _Anim(anim, duration, start == float.max ? timer.now : start);
		newAnim.removeWhenDone = true;
		while (true)
		{
			if (cur is null || cur.start > start)
			{
				if (prev is null)
				{
					// first element
					_schedule = newAnim;
				}
				else
				{
					prev.next = newAnim;
				}
				newAnim.next = cur;

				auto nowTime = timer.now;
				bool isActiveDuration = (newAnim.start + newAnim.duration) > nowTime;
				if ( !newAnim.removeWhenDone || isActiveDuration )
				{
					if (_head is null || newAnim.start < _head.start)
						_head = newAnim;
				}
				return;
			}
			prev = cur;
			cur = cur.next;
		}
	}

	void start()
	{
		timer.reset();
		_head = _schedule;
	}

	void update()
	{
		auto n = timer.now;
		_Anim cur = _head;
		while (cur !is null && cur.start <= n)
		{
			float offset = (n - cur.start) / cur.duration;
			//std.stdio.writeln("animating ", n, " ", cur.start, " ", offset);
			if (offset >= 1f)
			{
				if (cur.removeWhenDone && cur == _head)
				{
					_head = cur.next;
				}
			}

			cur.animator.update(offset > 1f ? 1f : offset);
			cur = cur.next;
		}
	}
}
