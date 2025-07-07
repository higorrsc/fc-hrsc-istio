# Istio Manifests

This directory contains all the Kubernetes and Istio manifests required to run the demonstrations outlined in the root [README.md](../README.md).

## Contents

1. **`circuit-breaker/`**: Contains all resources for the Circuit Breaker (Outlier Detection) demo.
2. **`consistent-hash.yaml`**: Defines an Istio `VirtualService` and `DestinationRule` to demonstrate consistent hash-based load balancing.
3. **`fault-injection.yaml`**: Defines an Istio `VirtualService` to demonstrate how to inject HTTP faults (aborts) into service traffic.

---

## 1. Circuit Breaker

This demonstration shows how Istio's outlier detection can automatically eject failing service instances from the load-balancing pool.

* **Directory**: `circuit-breaker/`
* **Application Source**: `circuit-breaker/servicex/`
* **Manifests**: `circuit-breaker/k3d/`

### Key Files

* `deployment.yaml`: Deploys two versions of the `servicex` application: one healthy (`version: "200"`) and one faulty (`version: "504"`). It also creates a `Service` to group them.
* `circuit-breaker.yaml`: Applies an Istio `DestinationRule` to the `servicex-service` to enable outlier detection. It ejects any pod that returns 10 consecutive `5xx` errors.

### How to Run

1. First, build and push the `servicex` Docker image.

    ```sh
    cd circuit-breaker/servicex/
    docker build -t <your-registry>/servicex:latest .
    docker push <your-registry>/servicex:latest
    # Remember to update the image name in circuit-breaker/k3d/deployment.yaml
    ```

2. Apply the manifests.

    ```sh
    kubectl apply -f circuit-breaker/k3d/deployment.yaml
    kubectl apply -f circuit-breaker/k3d/circuit-breaker.yaml
    ```

---

## 2. Consistent Hash Load Balancing

This demonstration shows how to route requests from a specific user to the same backend pod, which is useful for improving cache hit rates.

* **File**: `consistent-hash.yaml`

### Key Resources

* `VirtualService (nginx-vs)`: Performs a standard route to the `nginx-service`.
* `DestinationRule (nginx-dr)`: Configures the `trafficPolicy` for the `nginx-service`. It sets the load balancer to `consistentHash` and uses the `x-user` HTTP header as the hash key.

### How to Run

1. Deploy a backend service (e.g., NGINX).

    ```sh
    kubectl create deployment nginx --image=nginx --replicas=3
    kubectl expose deployment nginx --name=nginx-service --port=80
    ```

2. Apply the manifest.

    ```sh
    kubectl apply -f consistent-hash.yaml
    ```

---

## 3. Fault Injection

This demonstration shows how to test application resilience by having Istio inject errors into traffic without changing any application code.

* **File**: `fault-injection.yaml`

### Key Resources

* `VirtualService (nginx-vs)`: Intercepts traffic to `nginx-service` and applies a `fault` rule. This rule is configured to abort 100% of requests with an `HTTP 504 Gateway Timeout` error.

### How to Run

1. Deploy a backend service if you haven't already.

    ```sh
    kubectl create deployment nginx --image=nginx
    kubectl expose deployment nginx --name=nginx-service --port=80
    ```

2. Apply the manifest.

    ```sh
    kubectl apply -f fault-injection.yaml
    ```

3. To stop injecting faults, simply delete the `VirtualService`.

    ```sh
    kubectl delete -f fault-injection.yaml
    ```
