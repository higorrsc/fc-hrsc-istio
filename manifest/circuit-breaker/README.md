# Istio Circuit Breaker Demonstration

This project demonstrates Istio's circuit breaker capabilities using a simple Go service deployed on Kubernetes. The goal is to show how Istio's **Outlier Detection** can automatically detect and eject failing service instances from the load-balancing pool, improving the overall resilience of a microservices architecture.

## Project Overview

The setup consists of the following components:

1. **`ServiceX` (Go Application)**: A simple HTTP server that can simulate two states:
    * **Healthy**: Responds immediately with `HTTP 200 OK`.
    * **Faulty**: Introduces a random delay (0-4 seconds) and responds with `HTTP 504 Gateway Timeout`. This behavior is triggered by the `error=yes` environment variable.

2. **`Dockerfile`**: A multi-stage Dockerfile to build a minimal, production-ready container image for the `ServiceX` application.

3. **Kubernetes Manifests (`deployment.yaml`)**:
    * **`servicex` Deployment**: Runs healthy instances of `ServiceX` (pods labeled `version: "200"`).
    * **`servicex-error` Deployment**: Runs faulty instances of `ServiceX` (pods labeled `version: "504"`).
    * **`servicex-service` Service**: A `ClusterIP` service that groups all pods from both deployments under a single DNS name (`servicex-service`).

4. **Istio Manifest (`circuit-breaker.yaml`)**:
    * **`DestinationRule`**: Configures Istio's outlier detection (circuit breaker) for the `servicex-service`. It tells Istio to eject any pod that returns 10 consecutive gateway errors.

## How It Works

When traffic is sent to `servicex-service`, Istio load-balances requests across all available pods (both healthy and faulty). The faulty pods will start returning `504 Gateway Timeout` errors.

The `DestinationRule`'s `outlierDetection` policy monitors this behavior. After a pod returns 10 consecutive gateway errors, Istio considers it an "outlier" and temporarily ejects it from the service mesh's load-balancing pool for 30 seconds. During this time, no new traffic will be sent to the ejected pod, allowing it to potentially recover and preventing it from affecting users.

## Prerequisites

* A Kubernetes cluster (e.g., k3d, minikube).
* Istio installed on your cluster.
* Docker installed to build and push the container image.
* `kubectl` configured to interact with your cluster.

## Setup and Deployment

### 1. Build and Push the Docker Image

First, build the `ServiceX` application and push its image to a container registry (e.g., Docker Hub).

```sh
# Navigate to the service directory
cd manifest/circuit-breaker/servicex/

# Build and push the image (replace 'your-dockerhub-username' with your own)
export DOCKER_USER=higorrsc
export IMAGE_NAME=fc-hrsc-istio-servicex
docker build -t $DOCKER_USER/$IMAGE_NAME .
docker push $DOCKER_USER/$IMAGE_NAME
```

> **Note**: The provided `deployment.yaml` uses the image `higorrsc/fc-hrsc-istio-servicex`. If you use a different name, be sure to update the YAML file.

### 2. Deploy the Application and Service

Apply the Kubernetes manifests to create the deployments and the service.

```sh
# Navigate to the k3d manifest directory
cd manifest/circuit-breaker/k3d/

# Apply the deployments and service
kubectl apply -f deployment.yaml
```

Verify that the pods are running. You should see pods from both deployments.

```sh
kubectl get pods -l app=servicex
# NAME                              READY   STATUS    RESTARTS   AGE
# servicex-78c6675d4c-abcde         1/1     Running   0          1m
# servicex-error-667958c87f-fghij   1/1     Running   0          1m
```

### 3. Apply the Istio Circuit Breaker Rule

Apply the `DestinationRule` to enable outlier detection.

```sh
kubectl apply -f circuit-breaker.yaml
```

## Testing the Circuit Breaker

To see the circuit breaker in action, you need to generate traffic to the service. The easiest way is to run a client pod inside the cluster and use a loop.

1. **Deploy a client pod (e.g., `sleep`)**:

    ```sh
    kubectl run sleep --image=curlimages/curl -it --rm -- /bin/sh
    ```

2. **Generate Traffic**:
    Inside the `sleep` pod's shell, run a loop to continuously send requests to `servicex-service`.

    ```sh
    # Inside the sleep pod
    while true; do curl -s -o /dev/null -w "%{http_code}\n" http://servicex-service; sleep 0.1; done
    ```

    You will see a mix of `200` and `504` responses.

3. **Observe Outlier Detection**:
    In another terminal, check the Istio proxy stats for one of the client pods to see the ejections.

    ```sh
    # Find your sleep pod name
    kubectl get pods

    # Check the upstream cluster stats
    istioctl proxy-config cluster <sleep-pod-name> -o json | grep "outlier.ejections"
    ```

    Initially, the ejection count will be zero. After a short while, as the faulty pod consistently returns `504` errors, you will see the `outlier.ejections.total` count increase. This confirms that Istio's circuit breaker has tripped and ejected the unhealthy instance.
