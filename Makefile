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
