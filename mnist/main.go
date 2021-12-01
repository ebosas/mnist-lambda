package main

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"math"
	"net/http"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

// body is used to marshal the api response body.
type body struct {
	Message string `json:"message"`
}

//go:embed model.onnx
var modelOnnx []byte

// badReq is a short form bad request
var badReq = events.APIGatewayProxyResponse{
	StatusCode: http.StatusBadRequest,
}

// handleRequest is our lambda
func handleRequest(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// reqJson, _ := json.Marshal(req)
	// log.Printf("Request: %s", reqJson)
	if req.Body == "" {
		return badReq, fmt.Errorf("empty body")
	}
	output, err := runModel(req.Body)
	if err != nil {
		return badReq, fmt.Errorf("model: %v", err)
	}
	msg := respMessage(output)
	body, err := json.Marshal(body{Message: msg})
	if err != nil {
		return badReq, fmt.Errorf("marshal: %v", err)
	}
	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(body),
	}, nil
}

// respMessage generates the API response message
func respMessage(output []float64) string {
	i, o := maxItem(output)
	if o > 0.75 {
		return fmt.Sprintf("You drew %d, I'm %d%% sure.", i, int(math.Round(o*100)))
	}
	i2, _ := maxItem(append(append(output[:i], 0), output[i+1:]...))
	return fmt.Sprintf("Looks like %d, but could be %d.", i, i2)
}

// maxItem gets the largest number & index in a slice
func maxItem(numbers []float64) (int, float64) {
	var max struct {
		i int
		n float64
	}
	for i, n := range numbers {
		if i == 0 || n > max.n {
			max.i, max.n = i, n
		}
	}
	return max.i, max.n
}

func main() {
	lambda.Start(handleRequest)
}
