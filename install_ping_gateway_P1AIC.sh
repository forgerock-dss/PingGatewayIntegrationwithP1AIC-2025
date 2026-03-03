#!/usr/bin/env bash
# install_ping_gateway_P1AIC.sh
# Usage: ./install_ping_gateway_P1AIC.sh http|https|start|stop

set -euo pipefail
IFS=$'\n\t'

# --- script bundle location (ZIP/JAR/templates live here) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- modify these parameters to match your environment ---
PING_ZIP="${SCRIPT_DIR}/XXXXXXXXXX" #For example ${SCRIPT_DIR}/PingGateway-2025.11.1.zip
SAMPLE_JAR_SRC="${SCRIPT_DIR}/XXXXXXXXXX" #For example ${SCRIPT_DIR}/PingGateway-sample-application-2025.11.1.jar
VERSION="identity-gateway-XXXXXXXXXX" #For example for /PingGateway-2025.11.1.zip use identity-gateway-2025.11.1
BASE_INSTALL="XXXXXXXXXXX" #For example /opt/pingGatewayAICIntegration-2025/pingGatewayDeployment"

HOST="pinggateway.test.com"
SAMPLE_HOST="sample.test.com"
AM_HOST="https://openam-<TENANT>/am" #replace the <TENANT> with your P1AIC tenant FQDN
REALM="/alpha" #If needed replace with your realm

AGENT_ID="pinggateway_agent_cdsso"
AGENT_SECRET="XXXXXXXXXX" #Set the Secret as configured in the Gateway configuration in P1AIC

HTTP_PORT=9000
HTTPS_PORT=9443
SAMPLE_HTTP=9001
SAMPLE_HTTPS=9444
KEYSTORE_PASS="XXXXXXXXXX" #Set a secure keystore password
# --- end modify config ---

# --- derived paths ---
CONFIG_DIR="${BASE_INSTALL}/${VERSION}/ping_gateway_config"
BIN_DIR="${BASE_INSTALL}/${VERSION}/bin"
LOG_DIR="${CONFIG_DIR}/logs"
SAMPLE_DIR="${BASE_INSTALL}/sample_app"

BOOTSTRAP_LOG="${LOG_DIR}/bootstrap.out"
PGW_CONSOLE="${LOG_DIR}/console.out"
SAMPLE_LOG="${SAMPLE_DIR}/console.log"

PGW_PID="${LOG_DIR}/pinggateway.pid"
SAMPLE_PID="${SAMPLE_DIR}/sample_app.pid"

BASE_URI="http://${SAMPLE_HOST}:${SAMPLE_HTTP}"
AM_JWK_URL="${AM_HOST}/oauth2/realms${REALM}/connect/jwk_uri"
REDIRECT_URI="/home/cdsso/redirect"
AGENT_SECRET_B64="$(printf '%s' "${AGENT_SECRET}" | base64 | tr -d '\n')"

CMD="${1:-}"

info(){ printf '%s\n' "$*"; }
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage(){
  cat <<EOF
Usage: ./install_ping_gateway_P1AIC.sh http|https|start|stop

Script bundle directory:
  ${SCRIPT_DIR}

Product install directory:
  ${BASE_INSTALL}

Logs:
  PingGateway bootstrap: ${BOOTSTRAP_LOG}
  PingGateway runtime:   ${PGW_CONSOLE}
  Sample app:            ${SAMPLE_LOG}
EOF
  exit 1
}

need_file(){ [[ -f "$1" ]] || die "Missing file: $1"; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

alive(){ kill -0 "$1" >/dev/null 2>&1; }

stop_pid(){
  local pidfile="$1" label="$2"
  [[ -f "$pidfile" ]] || return 0
  local pid; pid="$(cat "$pidfile" 2>/dev/null || true)"
  if [[ -n "${pid}" ]] && alive "${pid}"; then
    info "Stopping ${label} (PID ${pid})"
    kill "${pid}" >/dev/null 2>&1 || true
    sleep 2
    alive "${pid}" && { info "${label} still running; forcing"; kill -9 "${pid}" >/dev/null 2>&1 || true; }
  fi
  rm -f "$pidfile" || true
}

stop_pat(){
  local pattern="$1"
  command -v pgrep >/dev/null 2>&1 || return 0
  pgrep -f "$pattern" >/dev/null 2>&1 || return 0
  info "Stopping processes by pattern: $pattern"
  pkill -f "$pattern" || true
  sleep 1
}

write_logfile(){
  local path="$1"
  mkdir -p "$(dirname "$path")"
  : > "$path"
}

env_check(){
  info "=== Environment check ==="
  info "Script bundle: ${SCRIPT_DIR}"
  info "Install dir:   ${BASE_INSTALL}"
  need_file "$PING_ZIP"
  need_file "$SAMPLE_JAR_SRC"
  need_cmd unzip
  need_cmd curl
  curl -fsS -m 5 "$AM_HOST" >/dev/null 2>&1 || die "Unable to reach AM: $AM_HOST"
}

confirm(){
  cat <<EOF

This will:
 - Install PingGateway (${CMD})
 - Deploy the sample app
 - Configure CDSSO route for P1AIC
 - Install into: ${BASE_INSTALL}

Proceed?
EOF
  read -r -p "Enter Y to continue: " c
  [[ "$c" == "Y" ]] || { info "Aborted."; exit 0; }
}

stop_sample(){
  info "=== Stopping Sample App ==="
  stop_pid "$SAMPLE_PID" "Sample app"
  stop_pat "$(basename "$SAMPLE_JAR_SRC")"
}

stop_pinggateway(){
  info "=== Stopping PingGateway ==="
  stop_pid "$PGW_PID" "PingGateway"
  [[ -x "${BIN_DIR}/stop.sh" ]] && "${BIN_DIR}/stop.sh" "$CONFIG_DIR" >/dev/null 2>&1 || true
  stop_pat openig
}

start_sample(){
  info "=== Starting Sample App ==="
  mkdir -p "$SAMPLE_DIR"
  write_logfile "$SAMPLE_LOG"
  stop_sample
  local jar="${SAMPLE_DIR}/$(basename "$SAMPLE_JAR_SRC")"
  [[ -f "$jar" ]] || die "Sample jar not found at ${jar}. Run install first."
  nohup java -jar "$jar" "$SAMPLE_HTTP" "$SAMPLE_HTTPS" >"$SAMPLE_LOG" 2>&1 &
  echo $! > "$SAMPLE_PID"
  info "Sample: http://${SAMPLE_HOST}:${SAMPLE_HTTP}/home"
  info "Log:    ${SAMPLE_LOG}"
}

start_pinggateway(){
  info "=== Starting PingGateway ==="
  write_logfile "$PGW_CONSOLE"
  stop_pinggateway
  [[ -x "${BIN_DIR}/start.sh" ]] || die "PingGateway start.sh not found. Run install first."
  nohup "${BIN_DIR}/start.sh" "$CONFIG_DIR" >"$PGW_CONSOLE" 2>&1 &
  echo $! > "$PGW_PID"
  info "Log: ${PGW_CONSOLE}"
}

deploy_pinggateway(){
  info "=== Deploying PingGateway ==="
  mkdir -p "$BASE_INSTALL" "$CONFIG_DIR" "$LOG_DIR"
  unzip -oq "$PING_ZIP" -d "$BASE_INSTALL"

  info "Bootstrap start/stop to initialise directories"
  write_logfile "$BOOTSTRAP_LOG"
  nohup "${BIN_DIR}/start.sh" "$CONFIG_DIR" >"$BOOTSTRAP_LOG" 2>&1 &
  sleep 5
  [[ -x "${BIN_DIR}/stop.sh" ]] && "${BIN_DIR}/stop.sh" "$CONFIG_DIR" >/dev/null 2>&1 || true
  stop_pat openig
  mkdir -p "${CONFIG_DIR}/config"
}

configure_ports(){
  local mode="$1"
  info "=== Configuring PingGateway (${mode}) ==="

  if [[ "$mode" == "http" ]]; then
    mkdir -p "${CONFIG_DIR}/bin"
    sed "s,{HTTP_PORT},${HTTP_PORT},g" "${SCRIPT_DIR}/admin.json.HTTP_ONLY" > "${CONFIG_DIR}/config/admin.json"
    info "Configured HTTP on port ${HTTP_PORT}"
  else
    need_cmd keytool
    mkdir -p "${CONFIG_DIR}/secrets" "${CONFIG_DIR}/bin"
    keytool -genkey -alias https-connector-key -keyalg RSA \
      -keystore "${CONFIG_DIR}/secrets/IG-keystore" \
      -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
      -dname "CN=${HOST},O=Example Corp,C=Ping"
    printf '%s' "$KEYSTORE_PASS" > "${CONFIG_DIR}/secrets/keystore.pass"
    echo "export IG_KEYSTORE_DIRECTORY=${CONFIG_DIR}/secrets" > "${CONFIG_DIR}/bin/env.sh"
    sed -e "s,{HTTP_PORT},${HTTP_PORT},g" -e "s,{HTTPS_PORT},${HTTPS_PORT},g" \
      "${SCRIPT_DIR}/admin.json.HTTPS" > "${CONFIG_DIR}/config/admin.json"
    info "Configured HTTPS on port ${HTTPS_PORT}"
  fi
}

deploy_sample(){
  info "=== Deploying Sample App ==="
  mkdir -p "$SAMPLE_DIR"
  cp "$SAMPLE_JAR_SRC" "$SAMPLE_DIR/"
}

configure_routes(){
  info "=== Configuring routes ==="
  mkdir -p "${CONFIG_DIR}/config/routes" "${CONFIG_DIR}/bin"
  touch "${CONFIG_DIR}/bin/env.sh"
  echo "export AGENT_SECRET_ID=${AGENT_SECRET_B64}" >> "${CONFIG_DIR}/bin/env.sh"

  sed "s,{BASE_URI},${BASE_URI},g" "${SCRIPT_DIR}/static-resources.json" \
    > "${CONFIG_DIR}/config/routes/static-resources.json"

  sed -e "s,{BASE_URI},${BASE_URI},g" \
      -e "s,{AM_HOST},${AM_HOST},g" \
      -e "s,{AM_REALM},${REALM},g" \
      -e "s,{IG_AGENT_ID},${AGENT_ID},g" \
      -e "s,{REDIRECT_URI},${REDIRECT_URI},g" \
      -e "s,{JWK_URL},${AM_JWK_URL},g" \
      "${SCRIPT_DIR}/cdsso-idc.json" > "${CONFIG_DIR}/config/routes/cdsso-idc.json"
}

install_flow(){
  local mode="$1"
  env_check
  confirm
  info "Removing existing install: ${BASE_INSTALL}"
  rm -rf "$BASE_INSTALL"

  deploy_pinggateway
  configure_ports "$mode"
  deploy_sample
  configure_routes

  start_sample
  start_pinggateway

  if [[ "$mode" == "https" ]]; then
    info "Access: https://${HOST}:${HTTPS_PORT}/home/cdsso"
  else
    info "Access: http://${HOST}:${HTTP_PORT}/home/cdsso"
  fi
  info "Done."
}

case "$CMD" in
  http|https) install_flow "$CMD" ;;
  start) start_sample; start_pinggateway; info "Access: https://${HOST}:${HTTPS_PORT}/home/cdsso  OR  http://${HOST}:${HTTP_PORT}/home/cdsso" ;;
  stop) stop_pinggateway; stop_sample; info "Stopped." ;;
  *) usage ;;
esac
