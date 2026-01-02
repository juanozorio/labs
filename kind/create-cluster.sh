#!/usr/bin/env bash

set -e

CLUSTER_NAME="giropops-senhas"
KIND_CONFIG_FILE="kind-config.yaml"

echo "🔧 Criando config do kind com 2 workers..."

cat <<EOF > ${KIND_CONFIG_FILE}
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF

echo "🚀 Criando cluster kind..."
kind create cluster --name ${CLUSTER_NAME} --config ${KIND_CONFIG_FILE}

echo "📦 Instalando Ingress NGINX..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "⏳ Aguardando Ingress NGINX ficar pronto..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "🔐 Instalando cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

echo "⏳ Aguardando cert-manager ficar pronto..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=180s

echo "🔑 Criando Issuer selfsigned (bootstrap da CA)..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned
  namespace: cert-manager
spec:
  selfSigned: {}
EOF

echo "🏗️ Criando CA local..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: local-ca
  namespace: cert-manager
spec:
  isCA: true
  commonName: local-ca
  secretName: local-ca-secret
  issuerRef:
    name: selfsigned
    kind: Issuer
EOF

echo "⏳ Aguardando certificado CA ser criado..."
kubectl wait --namespace cert-manager \
  --for=condition=Ready \
  certificate/local-ca \
  --timeout=60s || echo "⚠️ Certificado pode ainda estar sendo processado..."

echo "🌍 Criando ClusterIssuer local-ca..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: local-ca
spec:
  ca:
    secretName: local-ca-secret
    # O secret está no namespace cert-manager, mas o ClusterIssuer pode acessá-lo
    # quando o certificado for criado no mesmo namespace do secret ou quando
    # o secret for copiado para o namespace do certificado
EOF

echo "📊 Instalando kube-prometheus (monitoring stack)..."

if [ -d "kube-prometheus" ]; then
  rm -rf kube-prometheus
fi

git clone https://github.com/prometheus-operator/kube-prometheus.git

cd kube-prometheus

echo "➡️ Criando CRDs e namespace..."
kubectl apply --server-side -f manifests/setup

echo "⏳ Aguardando CRDs do Prometheus..."
kubectl wait \
  --for=condition=Established \
  --all CustomResourceDefinition \
  --timeout=180s

echo "➡️ Aplicando manifests do kube-prometheus..."
kubectl apply -f manifests/

cd ..
echo "✅ kube-prometheus instalado!"

echo "📄 Exportando certificado da CA local para arquivo local-ca.crt..."
kubectl -n cert-manager get secret local-ca-secret -o jsonpath='{.data.ca\.crt}' | base64 -d > local-ca.crt

echo "📁 Instalando certificado da CA local no sistema host..."
sudo cp local-ca.crt /usr/local/share/ca-certificates/local-ca.crt

echo "🔄 Atualizando certificados do sistema..."
sudo update-ca-certificates

echo "✅ Certificado da CA local instalado no sistema host!"
ls /etc/ssl/certs | grep local-ca

if [ -d "$HOME/.pki/nssdb" ]; then
  echo "📁 Instalando certificado da CA local no Google Chrome..."
  certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "local-ca" -i local-ca.crt
  echo "✅ Certificado da CA local instalado no Google Chrome!"
fi

rm -rf local-ca.crt

echo ""
echo "🎯 Cluster pronto com:"
echo "- kind (1 control-plane + 2 workers)"
echo "- ingress-nginx"
echo "- cert-manager + CA local"
echo "- kube-prometheus"
echo ""
echo "👉 Acessos úteis:"
echo "- Grafana: kubectl -n monitoring port-forward svc/grafana 3000:3000"
echo "- Prometheus: kubectl -n monitoring port-forward svc/prometheus-k8s 9090:9090"
echo "- Alertmanager: kubectl -n monitoring port-forward svc/alertmanager-main 9093:9093"
echo ""
echo "🔐 Login Grafana padrão:"
echo "user: admin"
echo "senha: admin"
