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
    // You do not need to implement this method.
    return 0;
}

void TaskSystemSerial::sync()
{
    // You do not need to implement this method.
    return;
}

/*
 * ================================================================
 * Parallel Task System Implementation
 * ================================================================
 */

const char *TaskSystemParallelSpawn::name() { return "Parallel + Always Spawn"; }

TaskSystemParallelSpawn::TaskSystemParallelSpawn(int num_threads)
    : ITaskSystem(num_threads), nthreads(num_threads)
{
    //
    // TODO: CS149 student implementations may decide to perform setup
    // operations (such as thread pool construction) here.
    // Implementations are free to add new class member variables
    // (requiring changes to tasksys.h).
    //
    
}

TaskSystemParallelSpawn::~TaskSystemParallelSpawn() {}

void TaskSystemParallelSpawn::spawnWorker(IRunnable* runnable, int num_total_tasks, int* counter, mutex* mtx)
{
    while (true) {
        int Tid; // Task ID
        mtx->lock();
        if (*counter < num_total_tasks) {
            Tid = (*counter)++;
            mtx->unlock();
        }
        else {
            mtx->unlock();
            break;
        }
        // mtx->unlock();
        runnable->runTask(Tid, num_total_tasks);
    }
}

void TaskSystemParallelSpawn::run(IRunnable *runnable, int num_total_tasks)
{
    //
    // TODO: CS149 students will modify the implementation of this
    // method in Part A.  The implementation provided below runs all
    // tasks sequentially on the calling thread.
    //

    int Ntask = 0;   // Shared counter
    mutex Tmutex;    // Counter protector
    vector<thread> workers;
    for (int t = 0; t < nthreads; t++) {
        workers.emplace_back(&TaskSystemParallelSpawn::spawnWorker, this, runnable, num_total_tasks, &Ntask, &Tmutex);
    }

    int cnt = (int)workers.size();
    int i = 0;
    while (i < cnt) {
        workers[i].join();
        i++;
    }
}

TaskID TaskSystemParallelSpawn::runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                                                 const vector<TaskID> &deps)
{
    // You do not need to implement this method.
    return 0;
}

void TaskSystemParallelSpawn::sync()
{
    // You do not need to implement this method.
    return;
}

/*
 * ================================================================
 * Parallel Thread Pool Spinning Task System Implementation
 * ================================================================
 */

const char *TaskSystemParallelThreadPoolSpinning::name() { return "Parallel + Thread Pool + Spin"; }

TaskSystemParallelThreadPoolSpinning::TaskSystemParallelThreadPoolSpinning(int num_threads)
    : ITaskSystem(num_threads), nthreads(num_threads),
      runn(nullptr), Tcounter(0),
      Dcounter(0), Ttask(0), dead(false)
{
    //
    // TODO: CS149 student implementations may decide to perform setup
    // operations (such as thread pool construction) here.
    // Implementations are free to add new class member variables
    // (requiring changes to tasksys.h).
    //
    for (int i = 0; i < nthreads; i++) {
        Vworker.emplace_back(&TaskSystemParallelThreadPoolSpinning::spinWorker, this);  
    }
}

TaskSystemParallelThreadPoolSpinning::~TaskSystemParallelThreadPoolSpinning()
{
    mtx.lock();
    dead = true;
    mtx.unlock();
    int k = (int)Vworker.size();
    while(k > 0) {
        Vworker[k - 1].join();
        k--;
    }
}

void TaskSystemParallelThreadPoolSpinning::spinWorker()
{
    int Tid; // Task ID
    while (!dead) {
        Tid = -1;
        mtx.lock();
        if (Tcounter < Ttask) { Tid = Tcounter++; }
        mtx.unlock();

        if (Tid == -1) { continue; }
        runn->runTask(Tid, Ttask);
        mtx.lock();
        Dtask++;
        mtx.unlock();
    }
}

void TaskSystemParallelThreadPoolSpinning::run(IRunnable *runnable, int num_total_tasks)
{
    //
    // TODO: CS149 students will modify the implementation of this
    // method in Part A.  The implementation provided below runs all
    // tasks sequentially on the calling thread.
    //
    mtx.lock();
    runn = runnable;
    Tcounter = 0;
    Dtask = 0;
    Ttask = num_total_tasks;
    mtx.unlock();

    while (true) {
        mtx.lock();
        if (Dtask >= Ttask) {
            mtx.unlock();
            break;
        }
        mtx.unlock();
    }
}

TaskID TaskSystemParallelThreadPoolSpinning::runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                                                              const vector<TaskID> &deps)
{
    // You do not need to implement this method.
    return 0;
}

void TaskSystemParallelThreadPoolSpinning::sync()
{
    // You do not need to implement this method.
    return;
}

/*
 * ================================================================
 * Parallel Thread Pool Sleeping Task System Implementation
 * ================================================================
 */

const char *TaskSystemParallelThreadPoolSleeping::name() { return "Parallel + Thread Pool + Sleep"; }

TaskSystemParallelThreadPoolSleeping::TaskSystemParallelThreadPoolSleeping(int num_threads)
    : ITaskSystem(num_threads), nthreads(num_threads),
      runn(nullptr), Tcounter(0), Dcounter(0),
      Dtask(0), Ttask(0), dead(false)
{
    //
    // TODO: CS149 student implementations may decide to perform setup
    // operations (such as thread pool construction) here.
    // Implementations are free to add new class member variables
    // (requiring changes to tasksys.h).
    //
    // Inside the Constructor

    for (int i = 0; i < nthreads; i++) {
        Vworker.emplace_back(&TaskSystemParallelThreadPoolSleeping::sleepWorker, this);
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
    dead = true;
    mtx.unlock();
    cv_doing.notify_all();
    int k = (int)Vworker.size();

    while(k > 0) {
        Vworker[k - 1].join();
        k--;
    }
}

void TaskSystemParallelThreadPoolSleeping::sleepWorker()
{
    int Tid;
    while (!dead) {
        Tid = -1;
        unique_lock<mutex> lock(mtx);
        while (true) {
            if (dead) { break; }
            if (Tcounter < Ttask) { break; }
            cv_doing.wait(lock);
        }

        if (dead) { break; }
        Tid = Tcounter++;
        lock.unlock();
        runn->runTask(Tid, Ttask);
        mtx.lock();
        Dtask++;

        if (Dtask == Ttask) { cv_fnsh.notify_one(); }
        mtx.unlock();
    }
}

void TaskSystemParallelThreadPoolSleeping::run(IRunnable *runnable, int num_total_tasks)
{
    //
    // TODO: CS149 students will modify the implementation of this
    // method in Parts A and B.  The implementation provided below runs all
    // tasks sequentially on the calling thread.
    //

    mtx.lock();
    runn = runnable;
    Tcounter = 0;
    Dtask = 0;
    Ttask = num_total_tasks;
    mtx.unlock();

    cv_doing.notify_all();
    unique_lock<mutex> lock(mtx);
    while (Dtask < Ttask) { cv_fnsh.wait(lock); }
}

TaskID TaskSystemParallelThreadPoolSleeping::runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                                                              const vector<TaskID> &deps)
{
    //
    // TODO: CS149 students will implement this method in Part B.
    //
    return 0;
}

void TaskSystemParallelThreadPoolSleeping::sync()
{
    //
    // TODO: CS149 students will modify the implementation of this method in Part B.
    //
    return;
}