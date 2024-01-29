package main

import (
	"fmt"
	"math/rand"
)

func main() {
	// Num jars at time of mint
	// numJars := 3379
	
	// Use the checkpoint thresholds to generate randomness
	checkpoints := []int{1420, 3333}

	// Generate a random number using each checkpoint as a seed
	for i := 0; i < len(checkpoints); i++ {
		seed :=rand.New(rand.NewSource(int64(checkpoints[i])));
		fmt.Println(seed.Intn(checkpoints[i]+1))
	}
}