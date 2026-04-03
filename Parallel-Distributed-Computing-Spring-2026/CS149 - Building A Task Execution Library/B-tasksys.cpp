#include "tasksys.h"

IRunnable::~IRunnable() {}

ITaskSystem::ITaskSystem(int num_threads) {}
ITaskSystem::~ITaskSystem() {}

/*
 * ================================================================
 * Serial task system implementation
 * ================================================================
 */

const char *TaskSystemSerial::name() { return "Serial"; }

TaskSystemSerial::TaskSystemSerial(int num_threads) : ITaskSystem(num_threads) {}

TaskSystemSerial::~TaskSystemSerial() {}

void TaskSystemSerial::run(IRunnable *runnable, int num_total_tasks)
{
    for (int i = 0; i < num_total_tasks; i++) { runnable->runTask(i, num_total_tasks); }
}

TaskID TaskSystemSerial::runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                                          const vector<TaskID> &deps)
{
    for (int i = 0; i < num_total_tasks; i++) { runnable->runTask(i, num_total_tasks); }
    return 0;
}

void TaskSystemSerial::sync() { return; }

/*
 * ================================================================
 * Parallel Task System Implementation
 * ================================================================
 */

const char *TaskSystemParallelSpawn::name() { return "Parallel + Always Spawn"; }

TaskSystemParallelSpawn::TaskSystemParallelSpawn(int num_threads) : ITaskSystem(num_threads)
{
    // NOTE: CS149 students are not expected to implement TaskSystemParallelSpawn in Part B.
}

TaskSystemParallelSpawn::~TaskSystemParallelSpawn() {}

void TaskSystemParallelSpawn::run(IRunnable *runnable, int num_total_tasks)
{
    // NOTE: CS149 students are not expected to implement TaskSystemParallelSpawn in Part B.
    for (int i = 0; i < num_total_tasks; i++) { runnable->runTask(i, num_total_tasks); }
}

TaskID TaskSystemParallelSpawn::runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                                                 const vector<TaskID> &deps)
{
    // NOTE: CS149 students are not expected to implement TaskSystemParallelSpawn in Part B.
    for (int i = 0; i < num_total_tasks; i++) { runnable->runTask(i, num_total_tasks); }
    return 0;
}

void TaskSystemParallelSpawn::sync()
{
    // NOTE: CS149 students are not expected to implement TaskSystemParallelSpawn in Part B.
    return;
}

/*
 * ================================================================
 * Parallel Thread Pool Spinning Task System Implementation
 * ================================================================
 */

const char *TaskSystemParallelThreadPoolSpinning::name() { return "Parallel + Thread Pool + Spin"; }

TaskSystemParallelThreadPoolSpinning::TaskSystemParallelThreadPoolSpinning(int num_threads) : ITaskSystem(num_threads)
{
    // NOTE: CS149 students are not expected to implement TaskSystemParallelThreadPoolSpinning in Part B.
}

TaskSystemParallelThreadPoolSpinning::~TaskSystemParallelThreadPoolSpinning() {}

void TaskSystemParallelThreadPoolSpinning::run(IRunnable *runnable, int num_total_tasks)
{
    // NOTE: CS149 students are not expected to implement TaskSystemParallelThreadPoolSpinning in Part B.
    for (int i = 0; i < num_total_tasks; i++) { runnable->runTask(i, num_total_tasks); }
}

TaskID TaskSystemParallelThreadPoolSpinning::runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                                                              const vector<TaskID> &deps)
{
    // NOTE: CS149 students are not expected to implement TaskSystemParallelThreadPoolSpinning in Part B.
    for (int i = 0; i < num_total_tasks; i++) { runnable->runTask(i, num_total_tasks); }
    return 0;
}

void TaskSystemParallelThreadPoolSpinning::sync()
{
    // NOTE: CS149 students are not expected to implement TaskSystemParallelThreadPoolSpinning in Part B.
    return;
}

/*
 * ================================================================
 * Parallel Thread Pool Sleeping Task System Implementation
 * ================================================================
 */

const char *TaskSystemParallelThreadPoolSleeping::name() { return "Parallel + Thread Pool + Sleep"; }

TaskSystemParallelThreadPoolSleeping::TaskSystemParallelThreadPoolSleeping(int num_threads) : ITaskSystem(num_threads)
{
    //
    // TODO: CS149 student implementations may decide to perform setup
    // operations (such as thread pool construction) here.
    // Implementations are free to add new class member variables
    // (requiring changes to tasksys.h).
    //

    nthreads = num_threads;
    Poff = false;
    active = 0;
    RGgroup.reserve(1000); // safer

    for (int i = 0; i < nthreads; i++) {
        workers.push_back(thread(&TaskSystemParallelThreadPoolSleeping::worker, this));
    }
}

// push all tasks of group Gid into the work queue
void TaskSystemParallelThreadPoolSleeping::dispatch(int Gid)
{
    if (RGgroup[Gid].pushed == true) { return; } // already dispatched earlier
    RGgroup[Gid].pushed = true;

    int total = RGgroup[Gid].Ttask;
    int i = 0;
    while(i < total) {
        Work w;
        w.Gid = Gid;
        w.Tidx = i;
        RDqueue.push(w);
        i++;
    }

    worker_cv.notify_all();
}

void TaskSystemParallelThreadPoolSleeping::worker()
{
    while (true) {
        unique_lock<mutex> lock(mtx);
        while (RDqueue.empty() && !Poff) { worker_cv.wait(lock); }
        if (Poff && RDqueue.empty()) { return; }

        Work w = RDqueue.front();
        RDqueue.pop();

        int k = (int)RGgroup.size();
        if (w.Gid < 0 || w.Gid >= k) { continue; }

        // copy everything needed BEFORE releasing lock
        IRunnable* r = RGgroup[w.Gid].runn;
        int total = RGgroup[w.Gid].Ttask;
        int tidx = w.Tidx;
        int gid = w.Gid;
        lock.unlock();

        r->runTask(tidx, total);

        lock.lock();
        // check bounds again after re-locking
        if (gid >= (int)RGgroup.size()) { continue; }

        RGgroup[gid].Dtask++;

        if (RGgroup[gid].Dtask == RGgroup[gid].Ttask) {
            active--;
            int i = 0;
            while (i < (int)RGgroup.size()) {
                if (!RGgroup[i].pushed) {
                    for (int j = 0; j < (int)RGgroup[i].deps.size(); j++) {
                        if (RGgroup[i].deps[j] == gid) {
                            RGgroup[i].wait_left--;
                            break;
                        }
                    }
                    if (RGgroup[i].wait_left == 0) { dispatch(i); }
                }
                i++;
            }
            if (active == 0) { sync_cv.notify_all(); }
        }
    }
}

TaskSystemParallelThreadPoolSleeping::~TaskSystemParallelThreadPoolSleeping()
{
    //
    // TODO: CS149 student implementations may decide to perform cleanup
    // operations (such as thread pool shutdown construction) here.
    // Implementations are free to add new class member variables
    // (requiring changes to tasksys.h).
    //
    mtx.lock();
    Poff = true;
    mtx.unlock();

    worker_cv.notify_all();
    int cnt = (int)workers.size();
    while(cnt > 0) {
        workers[cnt - 1].join();
        cnt--;
    }
}

void TaskSystemParallelThreadPoolSleeping::run(IRunnable *runnable, int num_total_tasks)
{

    //
    // TODO: CS149 students will modify the implementation of this
    // method in Parts A and B.  The implementation provided below runs all
    // tasks sequentially on the calling thread.
    //
    runAsyncWithDeps(runnable, num_total_tasks, vector<TaskID>());
    sync();
}

TaskID TaskSystemParallelThreadPoolSleeping::runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                                                              const vector<TaskID> &deps)
{

    //
    // TODO: CS149 students will implement this method in Part B.
    //
    unique_lock<mutex> lock(mtx);

    Group g;
    g.runn = runnable;
    g.Ttask = num_total_tasks;
    g.Dtask = 0;
    g.pushed = false;
    g.wait_left = 0;
    g.deps = deps;

    int cnt = 0;
    
    for (int i = 0; i < (int)deps.size(); i++) {
        int d = deps[i];
        if (d < 0 || d >= (int)RGgroup.size()) continue;
        if (!(RGgroup[d].Dtask == RGgroup[d].Ttask)) { cnt++; }
    }
    g.wait_left = cnt;

    int Gid = (int)RGgroup.size();
    int id = Gid;

    RGgroup.push_back(g);
    active++;

    if (g.wait_left == 0) { dispatch(Gid); }
    return id;
}

void TaskSystemParallelThreadPoolSleeping::sync()
{

    //
    // TODO: CS149 students will modify the implementation of this method in Part B.
    //
    unique_lock<mutex> lock(mtx);
    while (active > 0) { sync_cv.wait(lock); }
    RGgroup.clear();
}