#!/usr/bin/env bash
set -uo pipefail

readonly LOG_FILE="/var/log/connectivity-check.log"
readonly CHECK_TIMEOUT_SECONDS="5"
readonly PING_COUNT="3"
readonly INTERFACE_NAME="eth0"

DRY_RUN="false"
CRITICAL_ONLY="false"

PASSED_COUNT="0"
FAILED_COUNT="0"
SKIPPED_COUNT="0"
CRITICAL_FAILED="0"

log_message() {
  local level="$1"
  local message="$2"
  local timestamp

  timestamp="$(date "+%Y-%m-%d %H:%M:%S")"
  echo "${timestamp} ${level} ${message}" | sudo tee -a "${LOG_FILE}" >/dev/null
}

ensure_log_file() {
  sudo touch "${LOG_FILE}"
  sudo chmod 0644 "${LOG_FILE}"
}

increment_passed() {
  PASSED_COUNT="$((PASSED_COUNT + 1))"
}

increment_failed() {
  FAILED_COUNT="$((FAILED_COUNT + 1))"
}

increment_skipped() {
  SKIPPED_COUNT="$((SKIPPED_COUNT + 1))"
}

mark_critical_failure() {
  CRITICAL_FAILED="1"
}

report_pass() {
  local check_name="$1"
  local detail="$2"

  echo "[PASS] ${check_name} - ${detail}"
  log_message "[PASS]" "${check_name} - ${detail}"
  increment_passed
}

report_fail() {
  local check_name="$1"
  local detail="$2"
  local is_critical="$3"

  echo "[FAIL] ${check_name} - ${detail}"
  log_message "[FAIL]" "${check_name} - ${detail}"
  increment_failed

  if [[ "${is_critical}" == "true" ]]; then
    mark_critical_failure
  fi
}

report_skip() {
  local check_name="$1"
  local detail="$2"

  echo "[SKIP] ${check_name} - ${detail}"
  log_message "[SKIP]" "${check_name} - ${detail}"
  increment_skipped
}

run_ping_check() {
  local check_name="$1"
  local target_ip="$2"
  local is_critical="$3"

  if [[ "${CRITICAL_ONLY}" == "true" && "${is_critical}" != "true" ]]; then
    report_skip "${check_name}" "Skipped by --critical-only"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    report_skip "${check_name}" "DRY-RUN: Would run ping -c ${PING_COUNT} -W ${CHECK_TIMEOUT_SECONDS} ${target_ip}"
    return
  fi

  local ping_output
  ping_output="$(ping -c "${PING_COUNT}" -W "${CHECK_TIMEOUT_SECONDS}" "${target_ip}" 2>&1)"
  local ping_rc="$?"

  if [[ "${ping_rc}" -eq 0 ]]; then
    report_pass "${check_name}" "ping to ${target_ip} succeeded"
  else
    report_fail "${check_name}" "ping to ${target_ip} failed (rc=${ping_rc}): ${ping_output}" "${is_critical}"
  fi
}

run_port_check() {
  local check_name="$1"
  local target_ip="$2"
  local target_port="$3"
  local is_critical="$4"

  if [[ "${CRITICAL_ONLY}" == "true" && "${is_critical}" != "true" ]]; then
    report_skip "${check_name}" "Skipped by --critical-only"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    report_skip "${check_name}" "DRY-RUN: Would run nc -zv -w ${CHECK_TIMEOUT_SECONDS} ${target_ip} ${target_port}"
    return
  fi

  local nc_output
  nc_output="$(nc -zv -w "${CHECK_TIMEOUT_SECONDS}" "${target_ip}" "${target_port}" 2>&1)"
  local nc_rc="$?"

  if [[ "${nc_rc}" -eq 0 ]]; then
    report_pass "${check_name}" "port ${target_port} on ${target_ip} reachable"
  else
    report_fail "${check_name}" "port ${target_port} on ${target_ip} unreachable (rc=${nc_rc}): ${nc_output}" "${is_critical}"
  fi
}

run_dns_check() {
  local check_name="$1"
  local hostname="$2"
  local is_critical="$3"

  if [[ "${CRITICAL_ONLY}" == "true" && "${is_critical}" != "true" ]]; then
    report_skip "${check_name}" "Skipped by --critical-only"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    report_skip "${check_name}" "DRY-RUN: Would run nslookup -timeout=${CHECK_TIMEOUT_SECONDS} ${hostname}"
    return
  fi

  local dns_output
  dns_output="$(nslookup -timeout="${CHECK_TIMEOUT_SECONDS}" "${hostname}" 2>&1)"
  local dns_rc="$?"

  if [[ "${dns_rc}" -eq 0 ]]; then
    report_pass "${check_name}" "nslookup for ${hostname} succeeded"
  else
    report_fail "${check_name}" "nslookup for ${hostname} failed (rc=${dns_rc}): ${dns_output}" "${is_critical}"
  fi
}

run_default_route_check() {
  local check_name="$1"
  local is_critical="$2"

  if [[ "${CRITICAL_ONLY}" == "true" && "${is_critical}" != "true" ]]; then
    report_skip "${check_name}" "Skipped by --critical-only"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    report_skip "${check_name}" "DRY-RUN: Would run ip route show | grep default"
    return
  fi

  local route_output
  route_output="$(ip route show 2>&1)"
  local route_rc="$?"

  if [[ "${route_rc}" -ne 0 ]]; then
    report_fail "${check_name}" "ip route show failed (rc=${route_rc}): ${route_output}" "${is_critical}"
    return
  fi

  local default_output
  default_output="$(printf '%s\n' "${route_output}" | grep "default" 2>&1)"
  local grep_rc="$?"

  if [[ "${grep_rc}" -eq 0 ]]; then
    report_pass "${check_name}" "default route found: ${default_output}"
  else
    report_fail "${check_name}" "default route not found" "${is_critical}"
  fi
}

run_tc_qdisc_check() {
  local check_name="$1"
  local interface_name="$2"
  local is_critical="$3"

  if [[ "${CRITICAL_ONLY}" == "true" && "${is_critical}" != "true" ]]; then
    report_skip "${check_name}" "Skipped by --critical-only"
    return
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    report_skip "${check_name}" "DRY-RUN: Would run tc qdisc show dev ${interface_name}"
    return
  fi

  local tc_output
  tc_output="$(tc qdisc show dev "${interface_name}" 2>&1)"
  local tc_rc="$?"

  if [[ "${tc_rc}" -ne 0 ]]; then
    report_fail "${check_name}" "tc qdisc query failed (rc=${tc_rc}): ${tc_output}" "${is_critical}"
    return
  fi

  if printf '%s\n' "${tc_output}" | grep -E "netem|delay" >/dev/null 2>&1; then
    report_fail "${check_name}" "artificial latency detected on ${interface_name}: ${tc_output}" "${is_critical}"
  else
    report_pass "${check_name}" "no artificial latency detected on ${interface_name}"
  fi
}

usage() {
  cat <<'EOF'
Usage: connectivity-check.sh [--dry-run] [--critical-only] [--help]

Options:
  --dry-run        Print checks that would run without executing them
  --critical-only  Run only critical checks
  --help, -h       Show this help message
EOF
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN="true"
        ;;
      --critical-only)
        CRITICAL_ONLY="true"
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done
}

print_summary() {
  echo "Summary: passed=${PASSED_COUNT}, failed=${FAILED_COUNT}, skipped=${SKIPPED_COUNT}"
  log_message "[INFO]" "Summary: passed=${PASSED_COUNT}, failed=${FAILED_COUNT}, skipped=${SKIPPED_COUNT}"
}

parse_args "$@"
ensure_log_file

log_message "[INFO]" "Starting connectivity validation (dry-run=${DRY_RUN}, critical-only=${CRITICAL_ONLY})"

run_ping_check "Gateway ping" "10.0.0.1" "true"
run_ping_check "Self ping" "10.0.0.4" "true"
run_ping_check "Internet ping" "8.8.8.8" "true"

run_ping_check "App server ping" "10.0.1.10" "false"
run_ping_check "DB server ping" "10.0.2.10" "false"

run_port_check "PostgreSQL port check" "10.0.2.10" "5432" "false"
run_port_check "App health port check" "10.0.1.10" "8080" "false"

run_dns_check "DNS resolution" "google.com" "true"

run_default_route_check "Default route check" "true"

run_tc_qdisc_check "tc qdisc latency check" "${INTERFACE_NAME}" "false"

print_summary

if [[ "${CRITICAL_FAILED}" -eq 1 ]]; then
  log_message "[INFO]" "Connectivity validation finished with CRITICAL failures"
  exit 1
fi

log_message "[INFO]" "Connectivity validation finished without CRITICAL failures"
exit 0
