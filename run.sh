minikube delete --all
minikube start --memory=4096  # メモリのデフォルト値は2GBで気持ちやや少なめなので、4GBで起動
minikube addons enable metrics-server

minikube image build -t simple-app:1.0.0 app/v1/
minikube image build -t simple-app:1.0.1 app/v2/

# Istio
istioctl install --set profile=default --set components.egressGateways[0].name=istio-egressgateway --set components.egressGateways[0].enabled=true -y
kubectl label namespace default istio-injection=enabled
kubectl get namespace default --show-labels

# Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl create ns monitoring
helm upgrade -i prometheus prometheus-community/kube-prometheus-stack \
--namespace monitoring \
--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
--set fullnameOverride=prometheus
kubectl wait --for=condition=Ready pod --all --all-namespaces --timeout=-1s

# Pod Monitor
kubectl apply -f pod-monitor.yaml

## Flagger
helm repo add flagger https://flagger.app
helm repo update
kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml
helm upgrade -i flagger flagger/flagger \
  --namespace=istio-system \
  --set meshProvider=istio \
  --set metricsServer=http://prometheus-prometheus.monitoring.svc.cluster.local:9090
helm upgrade -i flagger-loadtester flagger/loadtester
kubectl apply -f metrics-template.yaml
kubectl wait --for=condition=Ready pod --all --all-namespaces --timeout=-1s

## デプロイ
kubectl apply -f simple-app.yaml
kubectl apply -f canary.yaml
kubectl wait --for=condition=Ready pod --all --all-namespaces --timeout=-1s

# デプロイ後のチェック
minikube service prometheus-prometheus -n monitoring --url &
minikube service simple-app --url &
kubectl get events --watch --field-selector involvedObject.kind=Canary

# カナリアリリース
kubectl set image deployment/simple-app simple-app=simple-app:1.0.1
