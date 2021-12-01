package main

import (
	"context"
	"net/http"
	"testing"

	"github.com/aws/aws-lambda-go/events"
)

// TestLambda tests the lambda function
func TestLambda(t *testing.T) {
	for _, test := range tests {
		req := events.APIGatewayProxyRequest{
			Body: test.input,
		}
		res, err := handleRequest(context.Background(), req)
		if err != nil {
			t.Errorf("bad response: %v", err)
		}
		// t.Logf("Response: %v", res)
		if res.StatusCode != http.StatusOK {
			t.Errorf("response %d, want %d", res.StatusCode, http.StatusOK)
		}
	}
}

// TestRespMessage tests response message
func TestRespMessage(t *testing.T) {
	var tests = []struct {
		input []float64
		want  string
	}{
		{[]float64{0, 1, 0, 0, 0, 0, 0, 0, 0, 0}, "You drew 1, I'm 100% sure."},
		{[]float64{0, 0, 0, 0, 0, 0, 0, 0, 1, 0}, "You drew 8, I'm 100% sure."},
		{[]float64{0, 0.8, 0, 0, 0.2, 0, 0, 0, 0, 0}, "You drew 1, I'm 80% sure."},
		{[]float64{0, 0.7, 0, 0, 0.3, 0, 0, 0, 0, 0}, "Looks like 1, but could be 4."},
		{[]float64{0, 0.4, 0, 0, 0.45, 0, 0, 0.15, 0, 0}, "Looks like 4, but could be 1."},
	}
	for _, test := range tests {
		if got := respMessage(test.input); got != test.want {
			t.Errorf("respMessage(%v) = %q, want %q", test.input, got, test.want)
		}
	}
}
