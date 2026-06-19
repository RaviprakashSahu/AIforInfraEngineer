#!/usr/bin/env bash
set -euo pipefail

readonly HEALTH_URL="http://localhost:80"
readonly CHECK_INTERVAL_SECONDS="30"
readonly APACHE_SERVICE="apache2"
readonly LOG_FILE="/var/log/payment-monitor.log"
readonly THREAD_DUMP_DIR="/var/log"
readonly PID_FILE="/tmp/payment-monitor.pid"
readonly STATE_FILE="/tmp/payment-monitor.state"

DRY_RUN="false"
RUN_ONCE="false"
ROLLBACK_ONLY="false"
MONITOR_RUNNING="true"

log() {
  local message="$1"
  local timestamp
  timestamp="$(date "+%Y-%m-%d %H:%M:%S")"
  echo "${timestamp} ${message}" | sudo tee -a "${LOG_FILE}" >/dev/null
}

ensure_log_file() {
  sudo mkdir -p "${THREAD_DUMP_DIR}"
  sudo touch "${LOG_FILE}"
  sudo chmod 0644 "${LOG_FILE}"
}

current_service_state() {
  sudo systemctl is-active "${APACHE_SERVICE}" 2>/dev/null || true
}

save_original_service_state() {
  local state
  state="$(current_service_state)"
  echo "${state}" > "${STATE_FILE}"
  log "Captured original ${APACHE_SERVICE} state: ${state}"
}

restore_original_service_state() {
  if [[ ! -f "${STATE_FILE}" ]]; then
    log "No saved state file found at ${STATE_FILE}; skipping service state restore"
    return
  fi

  local original_state
  original_state="$(cat "${STATE_FILE}")"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log "DRY-RUN: Would restore ${APACHE_SERVICE} to original state: ${original_state}"
    return
  fi

  case "${original_state}" in
    active)
      log "Restoring ${APACHE_SERVICE} to active state"
      sudo systemctl start "${APACHE_SERVICE}"
      ;;
    inactive|failed|activating|deactivating)
      log "Restoring ${APACHE_SERVICE} to non-active state (${original_state}) by stopping service"
      sudo systemctl stop "${APACHE_SERVICE}" || true
      ;;
    *)
      log "Original state ${original_state} is unknown; skipping service restore"
      ;;
  esac
}

capture_thread_dump() {
  local dump_file
  dump_file="${THREAD_DUMP_DIR}/apache-thread-dump-$(date "+%Y%m%d-%H%M%S").log"
  sudo touch "${dump_file}"

  log "Capturing Apache thread dump to ${dump_file}"

  local pids
  pids="$(pgrep -x "${APACHE_SERVICE}" || true)"

  if [[ -z "${pids}" ]]; then
    log "No ${APACHE_SERVICE} processes found for thread dump"
    return
  fi

  local pid
  while IFS= read -r pid; do
    if [[ -z "${pid}" ]]; then
      continue
    fi

    if command -v gstack >/dev/null 2>&1; then
      {
        echo "========== PID ${pid} (gstack) =========="
        sudo timeout 10s gstack "${pid}" || true
      } | sudo tee -a "${dump_file}" >/dev/null
    elif command -v pstack >/dev/null 2>&1; then
      {
        echo "========== PID ${pid} (pstack) =========="
        sudo timeout 10s pstack "${pid}" || true
      } | sudo tee -a "${dump_file}" >/dev/null
    else
      {
        echo "========== PID ${pid} (/proc stack fallback) =========="
        sudo cat "/proc/${pid}/stack" || true
      } | sudo tee -a "${dump_file}" >/dev/null
    fi
  done <<< "${pids}"
}

restart_apache() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    log "DRY-RUN: Would capture Apache thread dump and restart ${APACHE_SERVICE}"
    return
  fi

  capture_thread_dump
  log "Restarting ${APACHE_SERVICE}"
  sudo systemctl restart "${APACHE_SERVICE}"
  log "Restart command completed for ${APACHE_SERVICE}"
}

health_status_code() {
  curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "${HEALTH_URL}" || echo "000"
}

monitor_once() {
  local status
  status="$(health_status_code)"
  log "Health check ${HEALTH_URL} returned HTTP ${status}"

  if [[ "${status}" != "200" ]]; then
    log "Health check failed (HTTP ${status}); initiating recovery"
    restart_apache
  else
    log "Health check succeeded"
  fi
}

write_pid_file() {
  if [[ -f "${PID_FILE}" ]]; then
    local existing_pid
    existing_pid="$(cat "${PID_FILE}")"
    if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" >/dev/null 2>&1; then
      log "Monitor already running with PID ${existing_pid}; refusing duplicate start"
      echo "Monitor already running with PID ${existing_pid}" >&2
      exit 1
    fi
  fi

  echo "$$" > "${PID_FILE}"
}

cleanup_pid_file() {
  if [[ -f "${PID_FILE}" ]]; then
    local existing_pid
    existing_pid="$(cat "${PID_FILE}")"
    if [[ "${existing_pid}" == "$$" ]]; then
      rm -f "${PID_FILE}"
    fi
  fi
}

rollback() {
  MONITOR_RUNNING="false"

  if [[ -f "${PID_FILE}" ]]; then
    local running_pid
    running_pid="$(cat "${PID_FILE}")"

    if [[ -n "${running_pid}" ]] && [[ "${running_pid}" != "$$" ]] && kill -0 "${running_pid}" >/dev/null 2>&1; then
      if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY-RUN: Would stop running monitor process ${running_pid}"
      else
        log "Stopping running monitor process ${running_pid}"
        kill "${running_pid}" || true
      fi
    fi
  fi

  restore_original_service_state
  cleanup_pid_file
  log "Rollback completed"
}

usage() {
  cat <<'EOF'
Usage: payment-monitor.sh [--daemon] [--once] [--dry-run] [--rollback]

Options:
  --daemon    Run continuously (default behavior)
  --once      Run a single health check and exit
  --dry-run   Print/log actions without restarting apache
  --rollback  Stop monitor loop and restore original apache state
EOF
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --daemon)
        RUN_ONCE="false"
        ;;
      --once)
        RUN_ONCE="true"
        ;;
      --dry-run)
        DRY_RUN="true"
        ;;
      --rollback)
        ROLLBACK_ONLY="true"
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

parse_args "$@"
ensure_log_file

if [[ "${ROLLBACK_ONLY}" == "true" ]]; then
  log "Rollback requested via CLI"
  rollback
  exit 0
fi

write_pid_file

save_original_service_state

if [[ "${RUN_ONCE}" == "true" ]]; then
  trap 'log "Received termination signal in single-run mode"; rollback; exit 0' INT TERM
  monitor_once
  rollback
  exit 0
fi

trap 'log "Received termination signal in daemon mode"; rollback; exit 0' INT TERM
trap 'log "Unexpected error in daemon mode; triggering rollback"; rollback; exit 1' ERR

log "Starting payment monitor daemon loop. Interval=${CHECK_INTERVAL_SECONDS}s URL=${HEALTH_URL}"
while [[ "${MONITOR_RUNNING}" == "true" ]]; do
  monitor_once
  sleep "${CHECK_INTERVAL_SECONDS}"
done
