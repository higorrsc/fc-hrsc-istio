# Istio Features Demonstration

This repository contains a collection of hands-on examples to showcase key features of the Istio service mesh. Each demonstration is self-contained within the `manifest` directory and is designed to illustrate a specific capability using simple, reproducible steps.

## Demonstrations Overview

The following Istio features are demonstrated:

1. **Circuit Breaker (Outlier Detection)**: Automatically detect and eject failing service instances from the load-balancing pool to improve application resilience.
2. **Consistent Hash Load Balancing**: Route requests with specific characteristics (like a user ID) to the same backend pod, improving cache efficiency.
3. **Fault Injection**: Deliberately inject errors (aborts or delays) to test the resilience of the system without modifying application code.

## Prerequisites

Before you begin, ensure you have the following tools installed and configured:

* A running Kubernetes cluster (e.g., k3d, minikube).
* Istio installed on your cluster.
* `kubectl` configured to interact with your cluster.
* Docker (required for the Circuit Breaker demo).

---

## 1. Circuit Breaker (Outlier Detection)

This demo shows how Istio's outlier detection can act as a circuit breaker, protecting your system from cascading failures caused by unhealthy service instances.

* **Concept**: A `DestinationRule` is configured to monitor a service. When a pod returns too many consecutive errors, Istio ejects it from the load-balancing pool for a configured period.
* **Location**: `manifest/circuit-breaker/`

### Quickstart

1. **Build and Push the Docker Image**:

    ```sh
    cd manifest/circuit-breaker/servicex/
    docker build -t <your-registry>/servicex:latest .
    docker push <your-registry>/servicex:latest
    # Remember to update the image name in deployment.yaml
    ```

2. **Deploy and Test**:

    ```sh
    cd manifest/circuit-breaker/k3d/
    kubectl apply -f deployment.yaml
    kubectl apply -f circuit-breaker.yaml
    
    # Run a client and generate traffic to see the circuit breaker in action
    kubectl run sleep --image=curlimages/curl -it --rm -- /bin/sh
    # Inside the sleep pod:
    while true; do curl -s -o /dev/null -w "%{http_code}\n" http://servicex-service; sleep 0.1; done
    ```

## 2. Consistent Hash Load Balancing

This demo shows how to configure Istio to send requests from the same "user" to the same backend pod, which is useful for services that rely on in-memory caching.

* **Concept**: A `DestinationRule` with a `consistentHash` policy inspects a specified HTTP header (`x-user`) and uses its value to consistently route requests to a specific pod.
* **Location**: `manifest/consistent-hash.yaml`

### Quickstart

1. **Deploy a Backend Service**:

    ```sh
    kubectl create deployment nginx --image=nginx --replicas=3
    kubectl expose deployment nginx --name=nginx-service --port=80
    ```

2. **Apply the Rule and Test**:

    ```sh
    kubectl apply -f manifest/consistent-hash.yaml

    # Run a client pod
    kubectl run sleep --image=curlimages/curl -it --rm -- /bin/sh
    # Inside the sleep pod, verify that requests with the same header go to the same pod IP
    curl -s -H "x-user: higor" http://nginx-service/ | grep "Server address"
    curl -s -H "x-user: higor" http://nginx-service/ | grep "Server address"
    ```

## 3. Fault Injection

This demo shows how to use Istio to test an application's resilience by injecting faults (like HTTP errors) without changing any application code.

* **Concept**: A `VirtualService` intercepts traffic and applies a `fault` rule to abort a percentage of requests with a specific HTTP error code.
* **Location**: `manifest/fault-injection.yaml`

### Quickstart

1. **Deploy a Backend Service**:

    ```sh
    # If not already running from the previous demo
    kubectl create deployment nginx --image=nginx
    kubectl expose deployment nginx --name=nginx-service --port=80
    ```

2. **Apply the Rule and Test**:

    ```sh
    kubectl apply -f manifest/fault-injection.yaml

    # Run a client pod
    kubectl run sleep --image=curlimages/curl -it --rm -- /bin/sh
    # Inside the sleep pod, observe the injected error
    curl -v http://nginx-service
    # The response will be a 504 Gateway Timeout, injected by Istio.
    ```

## Cleanup

To remove a specific demo's resources, navigate to its directory and use `kubectl delete -f <filename.yaml>`.
