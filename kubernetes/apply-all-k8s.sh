#!/bin/bash
set -e

NAMESPACE="sock-shop"

echo "Applying Kubernetes manifests..."

echo "1) Namespace"
kubectl apply -f namespace.yaml

echo "2) Configs"
kubectl apply -f configs/ || true

echo "3) Secrets"
kubectl apply -f secrets/ || true

echo "4) RBAC"
kubectl apply -f rbac/ || true

echo "5) Storage"
kubectl apply -f storage/ || true

echo "6) Services"
kubectl apply -f services/ || true

echo "7) Deployments"
kubectl apply -f deployments/ || true

echo "8) DaemonSets"
kubectl apply -f daemonset/ || true

echo "9) HPA"
kubectl apply -f hpa/ || true

echo "10) NetworkPolicies"
kubectl apply -f networkpolicy/ || true

echo "11) Ingress"
kubectl apply -f ingress/ || true

echo "12) Monitoring"
kubectl apply -f monitoring/ || true

echo "Done applying manifests."

echo "Checking resources..."
kubectl get all -n $NAMESPACE
kubectl get ingress -n $NAMESPACE || true
kubectl get hpa -n $NAMESPACE || true
kubectl get networkpolicy -n $NAMESPACE || true
