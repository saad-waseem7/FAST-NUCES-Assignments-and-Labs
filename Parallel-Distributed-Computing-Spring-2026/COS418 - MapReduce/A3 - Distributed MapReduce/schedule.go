package mapreduce

import "sync"

// schedule starts and waits for all tasks in the given phase (Map or Reduce).
func (mr *Master) schedule(phase jobPhase) {
	var ntasks int
	var nios int // number of inputs (for reduce) or outputs (for map)
	switch phase {
	case mapPhase:
		ntasks = len(mr.files)
		nios = mr.nReduce
	case reducePhase:
		ntasks = mr.nReduce
		nios = len(mr.files)
	}

	debug("Schedule: %v %v tasks (%d I/Os)\n", ntasks, phase, nios)

	// All ntasks tasks have to be scheduled on workers, and only once all of
	// them have been completed successfully should the function return.

	var wg sync.WaitGroup
	wg.Add(ntasks)

	for task := 0; task < ntasks; task++ {
		go func(task int) {
			defer wg.Done()
			args := DoTaskArgs{
				JobName:       mr.jobName,
				File:          "",
				Phase:         phase,
				TaskNumber:    task,
				NumOtherPhase: nios,
			}
			if phase == mapPhase {
				args.File = mr.files[task]
			}
			for {
				worker := <-mr.registerChannel
				ok := call(worker, "Worker.DoTask", &args, new(struct{}))
				if ok {
					// Put worker back for reuse
					go func() { mr.registerChannel <- worker }()
					break
				}
				// If failed, try another worker (loop)
			}
		}(task)
	}

	wg.Wait()

	debug("Schedule: %v phase done\n", phase)
}
