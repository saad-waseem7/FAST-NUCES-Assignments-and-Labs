#ifndef _TASKSYS_H
#define _TASKSYS_H

#include <thread>
#include <vector>
#include <mutex>
#include <condition_variable>
#include "itasksys.h"

using namespace std;

class TaskSystemSerial : public ITaskSystem
{
public:
    TaskSystemSerial(int num_threads);
    ~TaskSystemSerial();
    const char *name();
    void run(IRunnable *runnable, int num_total_tasks);
    TaskID runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                            const vector<TaskID> &deps);
    void sync();
};

class TaskSystemParallelSpawn : public ITaskSystem
{
public:
    TaskSystemParallelSpawn(int num_threads);
    ~TaskSystemParallelSpawn();
    const char *name();
    void run(IRunnable *runnable, int num_total_tasks);
    TaskID runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                            const vector<TaskID> &deps);
    void sync();

private:
    int nthreads;
    void spawnWorker(IRunnable* runnable, int num_total_tasks, int* counter, mutex* mtx);
};

class TaskSystemParallelThreadPoolSpinning : public ITaskSystem
{
public:
    TaskSystemParallelThreadPoolSpinning(int num_threads);
    ~TaskSystemParallelThreadPoolSpinning();
    const char *name();
    void run(IRunnable *runnable, int num_total_tasks);
    TaskID runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                            const vector<TaskID> &deps);
    void sync();

private:
    int nthreads;
    mutex mtx;
    vector<thread> Vworker;
    IRunnable *runn;
    int Tcounter;
    int Dcounter;
    int Ttask;
    int Dtask;
    bool dead;
    void spinWorker();
};

class TaskSystemParallelThreadPoolSleeping : public ITaskSystem
{
public:
    TaskSystemParallelThreadPoolSleeping(int num_threads);
    ~TaskSystemParallelThreadPoolSleeping();
    const char *name();
    void run(IRunnable *runnable, int num_total_tasks);
    TaskID runAsyncWithDeps(IRunnable *runnable, int num_total_tasks,
                            const vector<TaskID> &deps);
    void sync();

private:
    int nthreads;
    mutex mtx;
    vector<thread> Vworker;
    condition_variable cv_doing;
    condition_variable cv_fnsh;
    IRunnable *runn;
    int Tcounter;
    int Dcounter;
    int Dtask;
    int Ttask;
    bool dead;
    void sleepWorker();
};

#endif