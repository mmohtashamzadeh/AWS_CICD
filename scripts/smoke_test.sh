#!/usr/bin/env bash
set -euo pipefail

KCFG="${WORKSPACE:-.}/.kube/config"
export KUBECONFIG="$KCFG"

echo "[*] Namespaces:"
kubectl get ns

echo "[*] App pods:"
kubectl -n app get pods -o wide

echo "[*] Service:"
kubectl -n app get svc web-svc -o wide

LB=$(kubectl -n app get svc web-svc -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -z "${LB}" ]; then
  echo "LoadBalancer hostname not ready yet."
  exit 1
fi

echo "[*] curl http://${LB}"
curl -sSf "http://${LB}" | head -n 5
echo "[OK]"

