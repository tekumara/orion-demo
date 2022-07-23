export KUBECONFIG=$(HOME)/.k3d/kubeconfig-orion.yaml

## create cluster and install minio and prefect
kubes: cluster kubes-minio kubes-prefect

## create k3s cluster
cluster:
# enable ephmeral containers for profiling
	k3d cluster create orion --registry-create orion-registry:0.0.0.0:5550 \
		-p 4200:80@loadbalancer -p 9000:9000@loadbalancer -p 9001:9001@loadbalancer \
		--k3s-arg '--kube-apiserver-arg=feature-gates=EphemeralContainers=true@server:*' \
  		--k3s-arg '--kube-scheduler-arg=feature-gates=EphemeralContainers=true@server:*' \
  		--k3s-arg '--kubelet-arg=feature-gates=EphemeralContainers=true@agent:*' \
		--wait
	@echo "Probing until traefik CRDs are created (~60 secs)..." && export KUBECONFIG=$$(k3d kubeconfig write orion) && \
		while : ; do kubectl get crd ingressroutes.traefik.containo.us > /dev/null && break; sleep 10; done
	@echo -e "\nTo use your cluster set:\n"
	@echo "export KUBECONFIG=$$(k3d kubeconfig write orion)"

## install minio
kubes-minio:
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm upgrade --install minio bitnami/minio --set auth.rootUser=minioadmin --set auth.rootPassword=minioadmin
	kubectl apply -f infra/lb-minio.yaml

## install prefect api and agent into kubes cluster
kubes-prefect: export PREFECT_API_URL=http://localhost:4200/api

kubes-prefect: $(venv)
	$(venv)/bin/prefect kubernetes manifest orion | kubectl apply -f - --wait=true
	kubectl apply -f infra/ingress-orion.yaml --wait=true
	kubectl wait pod --for=condition=ready --timeout=120s -lapp=orion
	@echo "Probing for the prefect API to be available (~20 secs)..." && \
		while : ; do curl -fsS $$PREFECT_API_URL/admin/version && break; sleep 1; done && echo
	$(venv)/bin/prefect work-queue create kubernetes

## run parameterised flow
param-flow: $(venv)
	$(venv)/bin/python -m flows.param_flow

## run dask flow
dask-flow: $(venv)
	$(venv)/bin/python -m flows.dask_flow

## run dask-kubernetes flow
dask-kubes-flow: $(venv)
	$(venv)/bin/python -m flows.dask_kubes_flow

## run ray flow
ray-flow: $(venv)
	$(venv)/bin/python -m flows.ray_flow

## run sub flow
sub-flow: $(venv)
	$(venv)/bin/python -m flows.sub_flow

## deploy basic_flow to kubernetes
kubes-deploy: export PREFECT_API_URL=http://localhost:4200/api
kubes-deploy: $(venv)
	docker-compose build app && docker-compose push app
# use minio as the s3 remote file system
	set -e && . config/fsspec-env.sh && $(venv)/bin/prefect deployment create flows/kubes_deployments.py
	$(venv)/bin/prefect deployment ls
	for deployment in increment/orion-packager increment/orion-packager-import increment/file-packager greetings/orion-packager; do $(venv)/bin/prefect deployment run $$deployment; done
	$(venv)/bin/prefect flow-run ls
	@echo Visit http://localhost:4200

## start prefect ui
ui: $(venv)
	PATH="$(venv)/bin:$$PATH" prefect orion start

## show kube logs
kube-logs:
	kubectl logs -lapp=orion --all-containers -f

## create kubernetes work queue
kube-work-queue: export PREFECT_API_URL=http://localhost:4200/api
kube-work-queue: $(venv)
	$(venv)/bin/prefect work-queue create kubernetes

## show flow run logs
run-logs:
	curl -H "Content-Type: application/json" -X POST --data '{"logs":{"flow_run_id":{"any_":["$(id)"]},"level":{"ge_":0}},"sort":"TIMESTAMP_ASC"}' -s "http://localhost:4200/api/logs/filter" | jq '.[].message | fromjson'

## access orion.db in kubes
kubes-db:
	kubectl exec -i -t svc/orion -c=api -- /bin/bash -c 'hash sqlite3 || (apt-get update && apt-get install sqlite3) && sqlite3 ~/.prefect/orion.db'

## upgrade to latest vesion of orion
upgrade: $(venv)
	latest=$$($(venv)/bin/pip index versions prefect --pre | grep 'LATEST' | sed -E 's/[[:space:]]+LATEST:[[:space:]]+([^[:space:]]+).*/\1/') && \
		rg -l -g '!orion*.yaml' 2.0b11 | xargs sed -i '' "s/2.0b11/$$latest/g"

include *.mk
