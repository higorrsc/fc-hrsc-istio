package main

import (
	"math/rand/v2"
	"net/http"
	"os"
	"time"
)

// main starts the HTTP server and handles incoming requests.
func main() {
	http.HandleFunc("/", Run)
	http.ListenAndServe(":8000", nil)
}

// Run handles HTTP requests. It simulates an error scenario based on an environment variable.
func Run(w http.ResponseWriter, r *http.Request) {
	if os.Getenv("error") == "yes" {
		time.Sleep(time.Second * time.Duration(rand.IntN(5)))
		w.WriteHeader(http.StatusGatewayTimeout)
		return
	}
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}
