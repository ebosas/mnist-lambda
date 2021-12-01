package main

import (
	"encoding/json"
	"fmt"
	"math"

	"github.com/owulveryck/onnx-go"
	"github.com/owulveryck/onnx-go/backend/x/gorgonnx"
	"gorgonia.org/tensor"
)

// runModel runs the ONNX model with the image pixel data, produces
// a len 10 slice of recognized digit likelyhoods
func runModel(inputJson string) ([]float64, error) {
	// Set up model
	backend := gorgonnx.NewGraph()
	m := onnx.NewModel(backend)
	err := m.UnmarshalBinary(modelOnnx)
	if err != nil {
		return []float64{}, fmt.Errorf("unmarshal model: %v", err)
	}
	// Unmarshal input
	var input []float32
	err = json.Unmarshal([]byte(inputJson), &input)
	if err != nil {
		return []float64{}, fmt.Errorf("unmarshal input: %v", err)
	}
	// Set input
	inputTd := tensor.New(tensor.WithShape(1, 1, 28, 28), tensor.WithBacking(input))
	inputT, err := tensor.Div(inputTd, float32(255))
	if err != nil {
		return []float64{}, fmt.Errorf("div 255: %v", err)
	}
	m.SetInput(0, inputT)
	// Run model
	err = backend.Run()
	if err != nil {
		return []float64{}, fmt.Errorf("run: %v", err)
	}
	// Output
	computedOutputT, err := m.GetOutputTensors()
	if err != nil {
		return []float64{}, fmt.Errorf("get output: %v", err)
	}
	computedOutput := computedOutputT[0].Data().([]float32)
	output := softmax(computedOutput)
	return output, nil
}

// softmax
func softmax(a []float32) []float64 {
	var sum float64
	output := make([]float64, len(a))
	for i := 0; i < len(a); i++ {
		output[i] = math.Exp(float64(a[i]))
		sum += output[i]
	}
	for i := 0; i < len(output); i++ {
		output[i] = output[i] / sum
	}
	return output
}
