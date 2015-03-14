/** Animation system

	The animation system is based in the concept of timeline where you can add clips
    to be applied on objects. Additionally events can be fired at certains point during
    an animation.

	The animation system uses compile time reflection to be able to build 
    clips at runtime for a given type. A clip can then be applied to an object of 
    that type using the timeline.

	---
    import animation;
    
    class Foo 
    {
	    this(float a, float b) 
        {
	        bar = a;
            muh = b;    
        }
        float bar;
        float muh;
    }
    auto foo = new Foo(0);
    
    // Animate foo.bar from 0 to 42 in 2 seconds.
    auto tl = new Timeline;
    tl.animate!"bar"(foo, 42, 2);
	---

	---    
    // Animate entire foo state using a clip
    // ie. animate bar from 0 to 100 and muh from 9 to 2 
    // starting from 0th second ending at 10th second.
	auto tmp1 = new Foo(0, 9);
	auto tmp2 = new Foo(100, 2);
	
    auto clip = new Clip;
    clip.createCurves(0, tmp1, 10, tmp2);
    
    // Run the clip on the foo object
    tl.animate(foo, clip);
    ---
*/
module animation;

public import animation.interpolate;
public import animation.timeline;
