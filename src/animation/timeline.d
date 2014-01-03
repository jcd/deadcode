module animation.timeline;

import animation.animator;
import animation.interpolate;
import animation.mutator;

import core.time;

import std.container;
import std.traits;

class Timeline
{
private:

	class _Anim
	{
		this(float dur, float _start)
		{
			duration = dur;
			start = _start;
		}

		abstract void update(float offset);
		abstract bool onDone(); // return true if animation should be removed when done

		float duration;
		float start;
		_Anim next;
	}

	class _AnimatorAnim : _Anim
	{
		this (Animator a, float d, float s) 
		{
			super(d, s);
			animator = a;
		}

		final override void update(float offset)
		{
			animator.update(offset);
		}

		final override bool onDone()
		{
			return removeWhenDone;
		}

		Animator animator;
		bool removeWhenDone;
	}

	class _EventAnim : _Anim
	{
		this(float triggerTime, EventCallback cb, int _data = 0)
		{
			const float verySmallDuration = 0.00000001;
			super(verySmallDuration, triggerTime);
			callback = cb;
			data = _data;
		}

		final override void update(float offset)
		{
		}
		
		final override bool onDone()
		{
			callback(data);
			return true;
		}

		int data;
		EventCallback callback;
	}

	_Anim _schedule; 
	_Anim _head;

public:
	InterpolateTimer timer;

	alias void delegate(int data) EventCallback;

	this()
	{
		this(dur!"weeks"(56));
	}

	this(Duration duration)
	{
		timer = new InterpolateTimer(duration);
	}

	@property bool hasPendingAnimation()
	{
		return _head !is null;
	}
	/*
	Animator animate(ref float target, float endValue, float duration, float start = float.max)
	{
		auto a = new InterpolateAnimator!float(&target, new CubicInterpolator(target, endValue));
		insert(a, duration, start);
		return a;
	}

*/

	Animator animate(string propertyPath, PropertyOwner, AnimType)(PropertyOwner owner, AnimType endValue, float duration, float start = float.max)
	{
		auto m = mutator!propertyPath(owner);
		auto a = new InterpolateAnimator!(typeof(m))(m, new CubicInterpolator(m.value, endValue));
		insert(a, duration, start);
		return a;
	}

	void event(float afterDuration, EventCallback callback, int data = 0)
	{
		auto newAnim = new _EventAnim(timer.now + afterDuration, callback, data);
		insert(newAnim, true);
	}

	private void insert(Animator anim, float duration, float start = float.max)
	{
		auto newAnim = new _AnimatorAnim(anim, duration, start == float.max ? timer.now : start);
		newAnim.removeWhenDone = true;
		insert(newAnim, newAnim.removeWhenDone);
	}

	private void insert(_Anim newAnim, bool removeWhenDone)
	{
		_Anim prev = null;
		_Anim cur = _schedule;
		while (true)
		{
			if (cur is null || cur.start > newAnim.start)
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
				if ( !removeWhenDone || isActiveDuration )
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
		_Anim prev = null;
		while (cur !is null && cur.start <= n)
		{
			float offset = (n - cur.start) / cur.duration;
			//std.stdio.writeln("animating ", n, " ", cur.start, " ", offset);
			cur.update(offset > 1f ? 1f : offset);

			if (offset >= 1f && cur.onDone())
			{
				// remove cur from list
				if (prev is null)
				{
					_head = cur.next;
				}
				else
				{
					prev.next = cur.next;
				}
			}
			else
			{
				prev = cur;
			}
			cur = cur.next;
		}
	}
}
