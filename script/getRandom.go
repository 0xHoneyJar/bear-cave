package main

import (
	"fmt"
	"math/rand"
)

func main() {
	// Num jars at time of mint
	// numJars := 3379
	
	// Use the checkpoint thresholds to generate randomness
	checkpoints := []int{
		3500,
        3664,
        3828,
        3992,
        4156,
        4320,
        4484,
        4648,
        4812,
        4976,
        5140,
        5304,
        5468,
        5632,
        5898,
	}

	// Generate a random number using each checkpoint as a seed
	for i := 0; i < 18; i++ {
		seedValue := 0
		if (i >= len(checkpoints)) {
			seedValue = checkpoints[len(checkpoints)-1] -i
		} else {
			seedValue = checkpoints[i]
		}

		seed :=rand.New(rand.NewSource(int64(seedValue)));
		randomNumber := seed.Intn(seedValue-3500+1) + 3500
		// fmt.Println(randomNumber)
		fmt.Printf("%d,", randomNumber)
	}

}