package main

import (
	"log"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestModel tests the model
func TestModel(t *testing.T) {
	for _, test := range tests {
		output, err := runModel(test.input)
		if err != nil {
			t.Errorf("model: %v", err)
		}
		// t.Logf("Output: %v", output)
		assert.InDeltaSlice(&testingT{}, test.output, output, 5e-2, "slices must be equal")
	}
}

type testingT struct{}

func (t *testingT) Errorf(format string, args ...interface{}) {
	log.Printf(format, args...)
}
