package cos418_hw1_1

import (
	"bufio"
	"io"
	"os"
	"strconv"
)

func sumWorker(nums chan int, out chan int) {
	local := 0
	for n := range nums {
		local += n
	}
	out <- local
}

func sum(num int, fileName string) int {
	file, err := os.Open(fileName)
	checkError(err)
	defer file.Close()

	values, err := readInts(file)
	checkError(err)

	jobs := make(chan int)
	results := make(chan int, num)

	for i := 0; i < num; i++ {
		go sumWorker(jobs, results)
	} // start workers
	for _, v := range values {
		jobs <- v
	} // send jobs
	close(jobs)

	total := 0
	for i := 0; i < num; i++ {
		total += <-results
	}

	return total
}

// Read a list of integers separated by whitespace from `r`.
// Return the integers successfully read with no error, or
// an empty slice of integers and the error that occurred.
func readInts(r io.Reader) ([]int, error) {
	scanner := bufio.NewScanner(r)
	scanner.Split(bufio.ScanWords)
	var elems []int
	for scanner.Scan() {
		val, err := strconv.Atoi(scanner.Text())
		if err != nil {
			return elems, err
		}
		elems = append(elems, val)
	}
	return elems, nil
}
