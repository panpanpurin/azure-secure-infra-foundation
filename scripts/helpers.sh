#!/usr/bin/env bash
# Shared helpers for infrastructure validation scripts.

set -euo pipefail

: "${REPO_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${TF_DIR:=${REPO_ROOT}/terraform}"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

log() {
  printf '%s\n' "$*"
}

log_section() {
  printf '\n=== %s ===\n' "$1"
}

log_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '  [PASS] %s\n' "$1"
}

log_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '  [FAIL] %s\n' "$1" >&2
}

log_skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf '  [SKIP] %s\n' "$1"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_fail "Required command not found: ${cmd}"
    exit 1
  fi
}

require_tf_state() {
  if [[ ! -d "${TF_DIR}/.terraform" ]]; then
    log_fail "Terraform not initialized. Run: make init"
    exit 1
  fi

  if ! terraform -chdir="${TF_DIR}" output -json >/dev/null 2>&1; then
    log_fail "No Terraform state/outputs found. Run: make apply"
    exit 1
  fi
}

load_tf_outputs() {
  require_tf_state
  TF_OUTPUTS_JSON="$(terraform -chdir="${TF_DIR}" output -json)"
}

tf_output() {
  local name="$1"
  local value
  value="$(jq -r --arg name "$name" '.[$name].value // empty' <<<"${TF_OUTPUTS_JSON}")"
  if [[ -z "${value}" || "${value}" == "null" ]]; then
    return 1
  fi
  printf '%s' "${value}"
}

tf_output_optional() {
  tf_output "$1" 2>/dev/null || true
}

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [[ "${actual}" == "${expected}" ]]; then
    log_pass "${label}"
  else
    log_fail "${label} (expected '${expected}', got '${actual}')"
  fi
}

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"

  if grep -Fq "${needle}" <<<"${haystack}"; then
    log_pass "${label}"
  else
    log_fail "${label} (missing '${needle}')"
  fi
}

assert_not_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"

  if grep -Fq "${needle}" <<<"${haystack}"; then
    log_fail "${label} (unexpected '${needle}')"
  else
    log_pass "${label}"
  fi
}

skip_if_missing_output() {
  local output_name="$1"
  local reason="$2"

  if ! tf_output "${output_name}" >/dev/null 2>&1; then
    log_skip "${reason}"
    return 0
  fi
  return 1
}

print_summary() {
  log_section "Summary"
  log "  Passed : ${PASS_COUNT}"
  log "  Failed : ${FAIL_COUNT}"
  log "  Skipped: ${SKIP_COUNT}"

  if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    log ""
    log "Validation failed."
    exit 1
  fi

  log ""
  log "Validation passed."
}