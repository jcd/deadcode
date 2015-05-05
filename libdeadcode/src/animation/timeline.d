module animation.timeline;

import animation.animator;
import animation.clip;
import animation.interpolate;
import animation.mutator;

import core.time;

import std.container;
import std.traits;

class Timeline
{
public:
	class Runner
	{
		protected this(float dur, float _start) nothrow @safe
		{
			stopped = false;
			duration = dur;
			start = _start;
		}

		protected abstract void update(float offset);
		protected abstract bool onDone(); // return true if animation should be removed when done

		void abort() nothrow
		{
			stopped = true;
		}

		@property float timeLeft() const
		{
			if (stopped)
				return 0;

			auto n = timer.now;

			float diff = n - start;
			if (diff <= 0)
				return duration;
			float left = duration - diff;
			if (left <= 0)
				return 0;
			return left;
		}

		// Animation animation;
		bool stopped;
		float duration;
		float start;
		string name; // optional name
		protected Runner next;
	}

private:

	class AnimatorRunner : Runner
	{
		protected this (Animator a, float d, float s) nothrow @safe
		{
			super(d, s);
			animator = a;
		}

		protected final override void update(float offset)
		{
			animator.update(offset);
		}

		protected final override bool onDone()
		{
			return removeWhenDone;
		}

		Animator animator;
		bool removeWhenDone;
	}

	class EventRunner : Runner
	{
		protected this(float triggerTime, EventCallback cb, int _data = 0) nothrow @safe
		{
			const float verySmallDuration = 0.00000001;
			super(verySmallDuration, triggerTime);
			callback = cb;
			data = _data;
		}

		protected final override void update(float offset)
		{
		}

		protected final override bool onDone()
		{
			callback(data);
			return true;
		}

		int data;
		EventCallback callback;
	}

	Runner _schedule;
	Runner _head;

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

	Runner getRunner(string name)
	{
		Runner cur = _head;
		while (cur !is null)
		{
			if (cur.name == name)
				return cur;
			cur = cur.next;
		}
		return null;
	}

	@property bool hasPendingAnimation()
	{
		return _head !is null;
	}
	/*
	Animator animate(ref float target, float endValue, float duration, float start = float.max)
	{
		auto a = new InterpolateAnimator!float(&target, new CubicCurve(target, endValue));
		insert(a, duration, start);
		return a;
	}

*/

	Runner animate(string propertyPath, alias CurveType = CubicCurve, PropertyOwner, AnimType)(PropertyOwner owner, AnimType endValue, float duration, float start = float.max)
	{
		// auto m = mutator!propertyPath(owner);
		start = start == float.max ? timer.now : start;
		auto a = new AnimatedObject!PropertyOwner(owner);
		auto clip = a.createClip();
		clip.createCurve!(propertyPath, CurveType)(0, mixin("owner." ~ propertyPath), duration, endValue);

		//auto a = new InterpolateAnimator!(typeof(m), typeof(m).FieldType)
		//                                 (m, new CubicCurve(start, m.value, start+duration, endValue));

		return insert(a, duration, start);
	}

	Runner animate(Target)(Target target, Clip!Target clip, float start = float.max)
	{
		// auto m = mutator!propertyPath(owner);
		start = start == float.max ? timer.now : start;
		auto a = new AnimatedObject!Target(target);
		a.clip = clip;

		//auto a = new InterpolateAnimator!(typeof(m), typeof(m).FieldType)
		//                                 (m, new CubicCurve(start, m.value, start+duration, endValue));

		return insert(a, clip.duration, start);
	}

	Runner event(float afterDuration, EventCallback callback, int data = 0) nothrow
	{
		auto newAnim = new EventRunner(timer.now + afterDuration, callback, data);
		insert(newAnim, true);
		return newAnim;
	}

	Runner animate(Target)(double timeStep, Target target, float duration = float.max, float start = float.max) nothrow
	{
		// auto m = mutator!propertyPath(owner);
		start = start == float.max ? timer.now : start;
		auto a = new DiscreteAnimator!Target(target, timeStep);

		return insert(a, duration, start);
	}

	Runner insert(Animator anim, float duration, float start) nothrow
	{
		auto newAnim = new AnimatorRunner(anim, duration, start);
		newAnim.removeWhenDone = true;
		insert(newAnim, newAnim.removeWhenDone);
		return newAnim;
	}

	private void insert(Runner newAnim, bool removeWhenDone) nothrow
	{
		Runner prev = null;
		Runner cur = _schedule;
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

	/** Remove animation by handle
	*/
	/*
	void remove(Handle h)
	{

	}
*/
	void start()
	{
		timer.reset();
		_head = _schedule;
	}

	void update()
	{
		auto n = timer.now;
		Runner cur = _head;
		Runner prev = null;
		while (cur !is null && cur.start <= n)
		{
			//float offset = (n - cur.start) / cur.duration;
			//std.stdio.writeln("animating ", n, " ", cur.start, " ", offset);
			// cur.update(offset > 1f ? 1f : offset);
			if (!cur.stopped)
				cur.update(n - cur.start);

			if (cur.stopped)
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
			else if (n >= (cur.start + cur.duration) && cur.onDone())
			{
				cur.stopped = true;

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
