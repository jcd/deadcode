module dccore.signals;

/*
*/

// Special function for internal use only.
// Use of this is where the slot had better be a delegate
// to an object or an interface that is part of an object.
extern (C) Object _d_toObject(void* p);

// Used in place of Object.notifyRegister and Object.notifyUnRegister.
alias DisposeEvt = void delegate(Object);
extern (C) void  rt_attachDisposeEvent( Object obj, DisposeEvt evt );
extern (C) void  rt_detachDisposeEvent( Object obj, DisposeEvt evt );

/*

mixin template Signal(T...)
{
    private import std.signals;
    mixin std.signals.Signal!T _signal;
    // alias _signal this;

    private Object[] _roots;
    final void connectTo(slot_t slot)
    {
        import core.memory;
        class Dlg
        {
            void cb(T t)
            {
                slot(t);
            }
        }
        auto d = new Dlg();
        _roots ~= d;
        connect(&d.cb);
    }
}
*/


mixin template Signal(T1...)
{
    static import std.c.stdlib;
    static import core.exception;
    /***
     * A slot is implemented as a delegate.
     * The slot_t is the type of the delegate.
     * The delegate must be to an instance of a class or an interface
     * to a class instance.
     * Delegates to struct instances or nested functions must not be
     * used as slots.
     */
    alias slot_t = void delegate(T1);

    /***
     * Call each of the connected slots, passing the argument(s) i to them.
     */
    final void emit( T1 i )
    {
        foreach (slot; slots[0 .. slots_idx])
        {   if (slot)
                slot(i);
        }
    }

    /***
     * Add a slot to the list of slots to be called when emit() is called.
     */
    final void connect(slot_t slot)
    {
        /* Do this:
         *    slots ~= slot;
         * but use malloc() and friends instead
         */
        auto len = slots.length;
        if (slots_idx == len)
        {
            if (slots.length == 0)
            {
                len = 4;
                auto p = std.c.stdlib.calloc(slot_t.sizeof, len);
                if (!p)
                    core.exception.onOutOfMemoryError();
                slots = (cast(slot_t*)p)[0 .. len];
            }
            else
            {
                len = len * 2 + 4;
                auto p = std.c.stdlib.realloc(slots.ptr, slot_t.sizeof * len);
                if (!p)
                    core.exception.onOutOfMemoryError();
                slots = (cast(slot_t*)p)[0 .. len];
                slots[slots_idx + 1 .. $] = null;
            }
        }
        slots[slots_idx++] = slot;

     L1:
        Object o = _d_toObject(slot.ptr);
        rt_attachDisposeEvent(o, &unhook);
    }

    private Object[] _roots;
    final void connectTo(slot_t slot)
    {
        import core.memory;
        class Dlg
        {
            void cb(T1 t)
            {
                slot(t);
            }
        }
        auto d = new Dlg();
        _roots ~= d;
        connect(&d.cb);
    }

    /***
     * Remove a slot from the list of slots to be called when emit() is called.
     */
    final void disconnect(slot_t slot)
    {
        debug (signal) writefln("Signal.disconnect(slot)");
        for (size_t i = 0; i < slots_idx; )
        {
            if (slots[i] == slot)
            {   slots_idx--;
                slots[i] = slots[slots_idx];
                slots[slots_idx] = null;        // not strictly necessary

                Object o = _d_toObject(slot.ptr);
                rt_detachDisposeEvent(o, &unhook);
            }
            else
                i++;
        }
    }

    /* **
     * Special function called when o is destroyed.
     * It causes any slots dependent on o to be removed from the list
     * of slots to be called by emit().
     */
    final void unhook(Object o)
    {
        debug (signal) writefln("Signal.unhook(o = %s)", cast(void*)o);
        for (size_t i = 0; i < slots_idx; )
        {
            if (_d_toObject(slots[i].ptr) is o)
            {   slots_idx--;
                slots[i] = slots[slots_idx];
                slots[slots_idx] = null;        // not strictly necessary
            }
            else
                i++;
        }
    }

    /* **
     * There can be multiple destructors inserted by mixins.
     */
    ~this()
    {
        /* **
         * When this object is destroyed, need to let every slot
         * know that this object is destroyed so they are not left
         * with dangling references to it.
         */
        if (slots)
        {
            foreach (slot; slots[0 .. slots_idx])
            {
                if (slot)
                {   Object o = _d_toObject(slot.ptr);
                    rt_detachDisposeEvent(o, &unhook);
                }
            }
            std.c.stdlib.free(slots.ptr);
            slots = null;
        }
    }

  private:
    slot_t[] slots;             // the slots to call from emit()
    size_t slots_idx;           // used length of slots[]
}

