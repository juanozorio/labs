#!/usr/bin/env bash
set -euo pipefail

echo "=============================="
echo " Kubernetes Cluster System Info"
echo "=============================="
echo

############################################
# Kubernetes core
############################################

echo ">>> Kubernetes"
kubectl version
echo

echo ">>> Contexto atual"
kubectl config current-context
echo

echo ">>> Nodes (kubelet versions)"
kubectl get nodes -o wide
echo

############################################
# ingress-nginx
############################################

echo ">>> ingress-nginx"

if kubectl get ns ingress-nginx >/dev/null 2>&1; then
  VERSION=$(kubectl get deploy ingress-nginx-controller \
    -n ingress-nginx \
    -o jsonpath='{.metadata.labels.app\.kubernetes\.io/version}' 2>/dev/null || true)

  IMAGE=$(kubectl get deploy ingress-nginx-controller \
    -n ingress-nginx \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)

  echo "Namespace : ingress-nginx"
  echo "Version   : ${VERSION:-unknown}"
  echo "Image     : $IMAGE"
else
  echo "ingress-nginx não instalado"
fi
echo

############################################
# cert-manager
############################################

echo ">>> cert-manager"

if kubectl get ns cert-manager >/dev/null 2>&1; then
  VERSION=$(kubectl get deploy cert-manager \
    -n cert-manager \
    -o jsonpath='{.metadata.labels.app\.kubernetes\.io/version}' 2>/dev/null || true)

  IMAGE=$(kubectl get deploy cert-manager \
    -n cert-manager \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)

  echo "Namespace : cert-manager"
  echo "Version   : ${VERSION:-unknown}"
  echo "Image     : $IMAGE"
else
  echo "cert-manager não instalado"
fi
echo

############################################
# kube-prometheus / Prometheus Operator
############################################

echo ">>> kube-prometheus / Prometheus Operator"

if kubectl get ns monitoring >/dev/null 2>&1; then
  OP_IMAGE=$(kubectl get deploy prometheus-operator \
    -n monitoring \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)

  PROM_IMAGE=$(kubectl get prometheus \
    -n monitoring \
    -o jsonpath='{.items[0].spec.image}' 2>/dev/null || true)

  ALERT_IMAGE=$(kubectl get alertmanager \
    -n monitoring \
    -o jsonpath='{.items[0].spec.image}' 2>/dev/null || true)

  echo "Namespace            : monitoring"
  echo "Prometheus Operator  : $OP_IMAGE"
  echo "Prometheus           : ${PROM_IMAGE:-default image}"
  echo "Alertmanager         : ${ALERT_IMAGE:-default image}"
else
  echo "kube-prometheus não instalado"
fi
echo

############################################
# CRDs (versão indireta)
############################################

echo ">>> CRDs instalados (principais)"
kubectl get crd | grep -E 'cert-manager|monitoring.coreos.com' || true
echo

echo "=============================="
echo " System info coletado com sucesso"
echo "=============================="
