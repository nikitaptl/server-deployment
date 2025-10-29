#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="muffin"
NAMESPACE="muffin"
HOSTNAME="muffin.local"
INGRESS_MANIFEST_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml"
TLS_CERT="muffin.local.pem"
TLS_KEY="muffin.local-key.pem"

log() { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m⚠ %s\033[0m\n" "$*"; }
die() { printf "\n\033[1;31m✖ %s\033[0m\n" "$*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

ensure_hosts() {
  if ! grep -qE "(^|\\s)${HOSTNAME}(\\s|$)" /etc/hosts; then
    log "Add ${HOSTNAME} to /etc/hosts"
    echo "127.0.0.1 ${HOSTNAME}" | sudo tee -a /etc/hosts >/dev/null
  fi
}

ensure_mkcert_and_certs() {
  have mkcert || die "mkcert not found. Install: brew install mkcert nss"
  log "mkcert -install (idempotent)"
  mkcert -install
  if [[ ! -f "${TLS_CERT}" || ! -f "${TLS_KEY}" ]]; then
    log "Generate leaf cert for ${HOSTNAME}"
    mkcert "${HOSTNAME}"
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$(mkcert -CAROOT)/rootCA.pem" || true
    sudo bash -lc 'cat "$(mkcert -CAROOT)/rootCA.pem" >> /etc/ssl/cert.pem' || true
    sudo killall -9 trustd || true
  fi
}

recreate_kind() {
  log "Recreate kind cluster ${CLUSTER_NAME}"
  if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    kind delete cluster --name "${CLUSTER_NAME}"
  fi
  kind create cluster --name "${CLUSTER_NAME}" --config kind-cluster.yaml
}

install_ingress_nginx() {
  log "Install ingress-nginx (kind manifest)"
  kubectl apply -f "${INGRESS_MANIFEST_URL}"
  log "Wait for deploy/ingress-nginx-controller Available"
  kubectl -n ingress-nginx wait deploy/ingress-nginx-controller \
    --for=condition=Available --timeout=180s
}

apply_workloads() {
  log "Apply app manifests"
  kubectl apply -f k8s/namespace.yaml
  kubectl apply -n "${NAMESPACE}" -f k8s/configmap.yaml
  kubectl apply -n "${NAMESPACE}" -f k8s/secret.yaml
  kubectl apply -n "${NAMESPACE}" -f k8s/postgres.yaml
  kubectl apply -n "${NAMESPACE}" -f k8s/deployment.yaml
  kubectl apply -n "${NAMESPACE}" -f k8s/service.yaml
}

ensure_tls_secret_before_ingress() {
  log "Create/Update TLS secret (before Ingress)"
  kubectl -n "${NAMESPACE}" create secret tls muffin-tls \
    --cert="${TLS_CERT}" --key="${TLS_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

apply_ingress_with_fallback() {
  local patched=0
  log "Apply Ingress (try strict)"
  set +e
  kubectl -n "${NAMESPACE}" apply -f k8s/ingress-tls.yaml
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    warn "Ingress apply failed (likely validating webhook not ready). Temporarily set failurePolicy=Ignore"
    kubectl patch validatingwebhookconfiguration ingress-nginx-admission \
      --type='json' \
      -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]' || true
    patched=1
    kubectl -n "${NAMESPACE}" apply -f k8s/ingress-tls.yaml
  fi
  if [[ $patched -eq 1 ]]; then
    log "Restore failurePolicy=Fail"
    kubectl patch validatingwebhookconfiguration ingress-nginx-admission \
      --type='json' \
      -p='[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Fail"}]' || true
  fi
}

wait_and_check() {
  log "Wait for pods Ready (namespace ${NAMESPACE})"
  kubectl -n "${NAMESPACE}" wait --for=condition=Ready pods --all --timeout=300s || true

  log "Summary:"
  kubectl -n "${NAMESPACE}" get pods -o wide || true
  kubectl -n "${NAMESPACE}" get svc,ingress -o wide || true

  log "OpenSSL cert info:"
  openssl s_client -connect "${HOSTNAME}:443" -servername "${HOSTNAME}" </dev/null 2>/dev/null \
    | openssl x509 -noout -issuer -subject -dates || true

  log "curl HTTPS check:"
  curl -vk "https://${HOSTNAME}/" >/dev/null || true

  log "Done. Open https://${HOSTNAME}"
}

main() {
  ensure_hosts
  ensure_mkcert_and_certs
  recreate_kind
  install_ingress_nginx
  apply_workloads
  ensure_tls_secret_before_ingress
  apply_ingress_with_fallback
  wait_and_check
}

main "$@"
