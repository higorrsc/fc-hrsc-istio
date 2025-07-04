cluster:
	k3d cluster create -p "8000:30000@loadbalancer" --agents 2
context:
	kubectl config use-context k3d-k3s-default
istio-default-profile:
	istioctl install -y
istio-injection:
	kubectl label namespace default istio-injection=enabled
istio-addons:
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/grafana.yaml
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/loki.yaml
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml
istio-fortio:
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/httpbin/sample-client/fortio-deploy.yaml
istio-fortio-env-var:
	export FORTIO_POD="$(kubectl get pods -l app=fortio -o 'jsonpath={.items[0].metadata.name}')"
istio-fortio-load-test:
	kubectl exec "$(FORTIO_POD)" -c fortio -- fortio load -c 2 -qps 0 -t 200s -loglevel Warning http://nginx-service:8000
nginx-loadbalancer:
	while true; do curl http://localhost:8000; echo; sleep 0.5; done;
