# Adiciona .PHONY para todos os alvos que não geram arquivos com o mesmo nome.
# Isso evita conflitos e melhora a performance.
.PHONY: all setup-cluster setup-istio istio-addons istio-fortio istio-fortio-load-test teardown help

# O alvo 'help' será executado se você rodar 'make' sem argumentos.
DEFAULT_GOAL := help

# --- Configuração do Cluster e Istio ---

# Cria um alvo "guarda-chuva" para configurar tudo com um só comando: make all
all: setup-cluster setup-istio istio-fortio

# Configura o cluster k3d
setup-cluster:
	@# Verifica se uma linha COMEÇA com 'k3s-default'
	@if ! k3d cluster list | grep -q '^k3s-default'; then \
		echo "--- 📦 Cluster 'k3s-default' não encontrado. Criando... ---"; \
		k3d cluster create -p "8000:30000@loadbalancer" --agents 2; \
	else \
		echo "--- ✅ Cluster 'k3s-default' já existe. Pulando criação. ---"; \
	fi
	@echo "--- 🎯 Usando o contexto do k3d... ---"
	@kubectl config use-context k3d-k3s-default

# Instala o Istio e seus componentes. Depende do cluster estar no ar.
setup-istio: setup-cluster
	@# Verifica se o deployment 'istiod' já existe no namespace 'istio-system'
	@if ! kubectl get deployment istiod -n istio-system >/dev/null 2>&1; then \
		echo "--- ⛵ Istio não encontrado. Instalando... ---"; \
		istioctl install -y; \
	else \
		echo "--- ✅ Istio já está instalado. Pulando instalação. ---"; \
	fi
	@echo "--- 💉 Habilitando injeção automática no namespace default... ---"
	@kubectl label namespace default istio-injection=enabled --overwrite=true

# Instala os addons do Istio. Use '&& \' para parar se um comando falhar.
istio-addons: setup-istio
	@echo "--- 📊 Instalando addons do Istio (Grafana, Jaeger, Kiali, etc.)... ---"
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/grafana.yaml && \
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/jaeger.yaml && \
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/kiali.yaml && \
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/prometheus.yaml && \
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/addons/loki.yaml

# --- Aplicações de Teste ---

# Implanta o cliente de teste Fortio. Depende da configuração do Istio.
istio-fortio: setup-istio
	@echo "--- 🚀 Implantando aplicação Fortio... ---"
	kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/httpbin/sample-client/fortio-deploy.yaml

# Executa o teste de carga com o Fortio.
# Depende do Fortio estar implantado.
istio-fortio-load-test: istio-fortio
	@echo "--- ⚡ Iniciando teste de carga com Fortio... ---"
	# Busca o nome do pod AQUI, no momento da execução, garantindo que ele exista.
	# Usamos uma variável de shell ($$POD_NAME) em vez de uma variável do make.
	# O '$$' é para escapar o '$' e passá-lo para o shell.
	@POD_NAME=$$(kubectl get pods -l app=fortio -o 'jsonpath={.items[0].metadata.name}'); \
	echo "Executando teste no pod: $$POD_NAME"; \
	kubectl exec "$$POD_NAME" -c fortio -- fortio load -c 2 -qps 0 -t 200s -loglevel Warning http://nginx-service:8000

# Este alvo é um loop infinito para gerar carga manualmente.
# É bom avisar o usuário que ele precisa ser interrompido com Ctrl+C.
nginx-loadbalancer:
	@echo "--- 🔄 Gerando carga contínua para http://localhost:8000 (Pressione Ctrl+C para parar) ---"
	@while true; do curl http://localhost:8000; echo; sleep 0.5; done;

# --- Limpeza ---

# Destrói os recursos criados.
teardown:
	@echo "--- 💣 Destruindo cluster k3d... ---"
	k3d cluster delete

# --- Ajuda ---

help:
	@echo "Uso: make [alvo]"
	@echo ""
	@echo "Alvos disponíveis:"
	@echo "  all                  Cria o cluster e instala o Istio e o Fortio."
	@echo "  setup-cluster        Cria o cluster k3d e configura o contexto."
	@echo "  setup-istio          Instala o Istio e habilita a injeção."
	@echo "  istio-addons         Instala os addons do Istio (Grafana, Prometheus, etc.)."
	@echo "  istio-fortio         Implanta a aplicação cliente Fortio."
	@echo "  istio-fortio-load-test Executa um teste de carga usando o Fortio."
	@echo "  nginx-loadbalancer   Inicia um loop infinito para gerar tráfego."
	@echo "  teardown             Remove o cluster k3d."
	@echo "  help                 Mostra esta mensagem de ajuda."
