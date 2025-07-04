cluster:
	k3d cluster create -p "8000:30000@loadbalancer" --agents 2
context:
	kubectl config use-context k3d-k3s-default
istio-default-profile:
	istioctl install -y
