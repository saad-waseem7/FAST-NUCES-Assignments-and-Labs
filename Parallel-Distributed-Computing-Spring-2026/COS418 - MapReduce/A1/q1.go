// q1.go
package cos418_hw1_1

import (
	"bufio"
	"container/heap"
	"fmt"
	"os"
	"sort"
	"strings"
)

type minHeap []WordCount

func (h minHeap) Len() int            { return len(h) }
func (h minHeap) Swap(i, j int)       { h[i], h[j] = h[j], h[i] }
func (h *minHeap) Push(x interface{}) { *h = append(*h, x.(WordCount)) }

func (h minHeap) Less(i, j int) bool {
	if h[i].Count == h[j].Count {
		return h[i].Word > h[j].Word
	}
	return h[i].Count < h[j].Count
}

func (h *minHeap) Pop() interface{} {
	temp := *h
	n := len(temp)
	item := temp[n-1]
	*h = temp[:n-1]
	return item
}

func cleanLine(line string) []string {
	var words []string
	var b strings.Builder
	for _, r := range strings.ToLower(line) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		} else if r == '\'' {
			continue
		} else {
			if b.Len() > 0 {
				words = append(words, b.String())
				b.Reset()
			}
		}
	}

	if b.Len() > 0 {
		words = append(words, b.String())
	}
	return words
}

func topWords(path string, numWords int, charThreshold int) []WordCount {
	file, err := os.Open(path)
	checkError(err)
	defer file.Close()

	reader := bufio.NewReader(file)
	freq := make(map[string]int)

	for {
		line, err := reader.ReadString('\n')
		if len(line) > 0 {
			for _, w := range cleanLine(line) {
				if len(w) >= charThreshold {
					freq[w]++
				}
			}
		}
		if err != nil {
			break
		}
	}

	h := &minHeap{}
	heap.Init(h)

	for word, count := range freq {
		if h.Len() < numWords {
			heap.Push(h, WordCount{Word: word, Count: count})
		} else if count > (*h)[0].Count || (count == (*h)[0].Count && word < (*h)[0].Word) {
			heap.Pop(h)
			heap.Push(h, WordCount{Word: word, Count: count})
		}
	}

	res := make([]WordCount, h.Len())
	for i := len(res) - 1; i >= 0; i-- {
		res[i] = heap.Pop(h).(WordCount)
	}

	sortWordCounts(res)
	return res
}

// A struct that represents how many times a word is observed in a document
type WordCount struct {
	Word  string
	Count int
}

func (wc WordCount) String() string { return fmt.Sprintf("%v: %v", wc.Word, wc.Count) }

func sortWordCounts(wordCounts []WordCount) { // Unchanged from q1.go
	sort.Slice(wordCounts, func(i, j int) bool {
		wc1 := wordCounts[i]
		wc2 := wordCounts[j]
		if wc1.Count == wc2.Count {
			return wc1.Word < wc2.Word
		}
		return wc1.Count > wc2.Count
	})
}
