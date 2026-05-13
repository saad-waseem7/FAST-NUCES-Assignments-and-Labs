package mapreduce

import (
	"encoding/json"
	"hash/fnv"
	"io/ioutil"
	"os"
)

// doMap does the job of a map worker: it reads one of the input files
// (inFile), calls the user-defined map function (mapF) for that file's
// contents, and partitions the output into nReduce intermediate files.
func doMap(
	jobName string, // the name of the MapReduce job
	mapTaskNumber int, // which map task this is
	inFile string,
	nReduce int, // the number of reduce task that will be run ("R" in the paper)
	mapF func(file string, contents string) []KeyValue,
) {
	// Read the input file
	contents, err := ioutil.ReadFile(inFile)
	checkError(err)

	// Call mapF to get key/value pairs
	kva := mapF(inFile, string(contents))

	// Create intermediate files for each reduce task
	encoders := make([]*json.Encoder, nReduce)
	files := make([]*os.File, nReduce)
	for i := 0; i < nReduce; i++ {
		fileName := reduceName(jobName, mapTaskNumber, i)
		file, err := os.Create(fileName)
		checkError(err)
		files[i] = file
		encoders[i] = json.NewEncoder(file)
	}

	// Partition key/value pairs into appropriate intermediate files
	for _, kv := range kva {
		reduceTask := ihash(kv.Key) % uint32(nReduce)
		err := encoders[reduceTask].Encode(&kv)
		checkError(err)
	}

	// Close all files
	for i := 0; i < nReduce; i++ {
		files[i].Close()
	}
}

func ihash(s string) uint32 {
	h := fnv.New32a()
	h.Write([]byte(s))
	return h.Sum32()
}
