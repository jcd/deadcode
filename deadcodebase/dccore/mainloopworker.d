module dccore.mainloopworker;

import util.queue;

interface IWorker
{
    void work();
}

abstract class MainLoopWorker : IWorker
{
    private void delegate(IWorker) _wakeMainLoop;
    protected void wakeMainLoop() { _wakeMainLoop(this); }

    @property
    {
        void wakeUpMainLoopDelegate(void delegate(IWorker) wakeMainLoop) { _wakeMainLoop = wakeMainLoop; }
        void delegate(IWorker) wakeUpMainLoopDelegate() { return _wakeMainLoop; }
    }
}

/** Queue for submitting items from a thread to be handled by a function run in main loop thread

This class holds a queue with items which any thread can push to. When items are pushed the
main loop is waked up and provede with the instance of the QueuedWorker. How the main loop will handle
QueuedWorker and how the main loop is waked up is customizable. Whenever the main loop is ready it should
then call the work() method of the QueuedWorker in order for queued items to be handled. The handler is
provided in the constructor.
*/
class QueuedWorker(T) : MainLoopWorker
{
private:
    shared GrowableCircularQueue!(shared T) _queue;
    void delegate(T) _workDlg;
    //    mixin Signal!(IWorker) onWorkQueued; /// emitted from any thread

public:

    this(void delegate(T) dlg, void delegate(IWorker) wakeMainLoopDlg = null)
    {
        wakeUpMainLoopDelegate = wakeMainLoopDlg;
        _queue = new shared typeof(_queue);
        _workDlg = dlg;
    }

    // Called by any thread
    void pushWork(ref T item)
    {
        T tmp = item;
        item = null;
        _queue.push(cast(shared T)tmp);
        wakeMainLoop();
    }

    // Should be called in thread doing the actual work (e.g. main thread)
    void work()
    {
        while (!_queue.empty)
        {
            auto item = cast(T)_queue.pop();
            _workDlg(item);
        }
    }
}
