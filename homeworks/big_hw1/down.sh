#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="muffin"
NAMESPACE="muffin"
HOSTNAME="muffin.local"
TLS_CERT="muffin.local.pem"
TLS_KEY="muffin.local-key.pem"

log()  { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m⚠ %s\033[0m\n" "$*"; }
die()  { printf "\n\033[1;31m✖ %s\033[0m\n" "$*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

delete_namespace() {
  if kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
    log "Delete namespace ${NAMESPACE} and its resources"
    kubectl delete ns "${NAMESPACE}" --grace-period=0 --force || true
  fi
}

delete_ingress_nginx() {
  if kubectl get ns ingress-nginx >/dev/null 2>&1; then
    log "Delete ingress-nginx"
    kubectl delete ns ingress-nginx --grace-period=0 --force || true
  fi
}

delete_kind_cluster() {
  if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    log "Delete kind cluster ${CLUSTER_NAME}"
    kind delete cluster --name "${CLUSTER_NAME}" || true
  else
    warn "No kind cluster named ${CLUSTER_NAME}"
  fi
}

cleanup_hosts() {
  log "Remove ${HOSTNAME} from /etc/hosts if present"
  sudo sed -i.bak "/${HOSTNAME}/d" /etc/hosts || true
}

cleanup_certs() {
  if [[ -f "${TLS_CERT}" || -f "${TLS_KEY}" ]]; then
    read -p "Remove local TLS files ${TLS_CERT}/${TLS_KEY}? [y/N]: " ans
    if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
      rm -f "${TLS_CERT}" "${TLS_KEY}"
      log "Local certs removed"
    else
      warn "Keep local certs"
    fi
  fi
}

cleanup_mkcert_trust() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    read -p "Remove mkcert rootCA from System keychain? [y/N]: " ans
    if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
      log "Removing mkcert rootCA from System keychain"
      sudo security delete-certificate -c "mkcert development CA" /Library/Keychains/System.keychain || true
    fi
  fi
}

main() {
  log "=== Muffin down sequence ==="
  delete_namespace
  delete_ingress_nginx
  delete_kind_cluster
  cleanup_hosts
  cleanup_certs
  cleanup_mkcert_trust
  log "Cleanup complete"
}

main "$@"
