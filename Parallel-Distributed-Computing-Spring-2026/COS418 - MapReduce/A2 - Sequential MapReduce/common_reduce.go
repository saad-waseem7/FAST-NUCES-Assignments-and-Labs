package mapreduce

import (
	"encoding/json"
	"os"
	"sort"
)

// doReduce does the job of a reduce worker: it reads the intermediate
// key/value pairs (produced by the map phase) for this task, sorts the
// intermediate key/value pairs by key, calls the user-defined reduce function
// (reduceF) for each key, and writes the output to disk.
func doReduce(
	jobName string, // the name of the whole MapReduce job
	reduceTaskNumber int, // which reduce task this is
	nMap int, // the number of map tasks that were run ("M" in the paper)
	reduceF func(key string, values []string) string,
) {
	// Read all intermediate files for this reduce task
	intermediate := make(map[string][]string)
	for m := 0; m < nMap; m++ {
		fileName := reduceName(jobName, m, reduceTaskNumber)
		file, err := os.Open(fileName)
		checkError(err)
		
		dec := json.NewDecoder(file)
		for {
			var kv KeyValue
			err := dec.Decode(&kv)
			if err != nil {
				break
			}
			intermediate[kv.Key] = append(intermediate[kv.Key], kv.Value)
		}
		file.Close()
	}

	// Sort keys
	var keys []string
	for k := range intermediate {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	// Create output file
	fileName := mergeName(jobName, reduceTaskNumber)
	file, err := os.Create(fileName)
	checkError(err)
	enc := json.NewEncoder(file)

	// Call reduceF for each key and write output
	for _, k := range keys {
		output := reduceF(k, intermediate[k])
		enc.Encode(KeyValue{k, output})
	}

	file.Close()
}
