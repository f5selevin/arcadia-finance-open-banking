#!/usr/bin/env bash
set -uo pipefail

METADATA_URL="${METADATA_URL:-http://10.1.1.4:5123/metadata}"
DOMAIN_SUFFIX="${DOMAIN_SUFFIX:-spec-security.f5se.com}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-1}"
METADATA_RETRY_SECONDS="${METADATA_RETRY_SECONDS:-10}"
METADATA_TIMEOUT_SECONDS="${METADATA_TIMEOUT_SECONDS:-10}"
REQUEST_TIMEOUT_MS="${REQUEST_TIMEOUT_MS:-10000}"
WORK_DIR="$(pwd)"
METADATA_BODY="$(mktemp)"
METADATA_ERROR="$(mktemp)"

log() {
  printf '%s [traffic-generator] [%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$1" "$2"
}

cleanup() {
  local exit_code=$?
  rm -f "${METADATA_BODY}" "${METADATA_ERROR}"
  log INFO "Traffic generator stopped with exit code ${exit_code}"
}

trap cleanup EXIT
trap 'log WARN "Received SIGTERM; stopping"; exit 143' TERM
trap 'log WARN "Received SIGINT; stopping"; exit 130' INT

log INFO "Starting Open Banking Postman/Newman traffic generator"
log INFO "Process: pid=$$ user=$(id -u):$(id -g) hostname=$(hostname) working_directory=${WORK_DIR}"
log INFO "Configuration: metadata_url=${METADATA_URL} domain_suffix=${DOMAIN_SUFFIX} metadata_retry_seconds=${METADATA_RETRY_SECONDS} metadata_timeout_seconds=${METADATA_TIMEOUT_SECONDS} request_timeout_ms=${REQUEST_TIMEOUT_MS} iteration_interval_seconds=${INTERVAL_SECONDS}"
log INFO "Runtime: node=$(node --version 2>&1) npm=$(npm --version 2>&1) newman=$(newman --version 2>&1) openapi2postmanv2=$(openapi2postmanv2 --version 2>&1)"
log INFO "OpenAPI source: ${WORK_DIR}/api/openbanking.json ($(wc -c < ./api/openbanking.json) bytes)"
log INFO "OpenAPI definition: title=$(jq -r '.info.title // "unknown"' ./api/openbanking.json) version=$(jq -r '.info.version // "unknown"' ./api/openbanking.json) paths=$(jq '.paths | length' ./api/openbanking.json) operations=$(jq '[.paths[] | keys[] | select(. == "get" or . == "post" or . == "put" or . == "patch" or . == "delete")] | length' ./api/openbanking.json)"

METADATA_ATTEMPT=0
while true; do
  METADATA_ATTEMPT=$((METADATA_ATTEMPT + 1))
  : >"${METADATA_BODY}"
  : >"${METADATA_ERROR}"
  log INFO "Metadata attempt ${METADATA_ATTEMPT} started: GET ${METADATA_URL}"
  METADATA_STARTED="$(date +%s)"
  CURL_RESULT="$(curl --silent --show-error --location \
    --connect-timeout "${METADATA_TIMEOUT_SECONDS}" \
    --max-time "${METADATA_TIMEOUT_SECONDS}" \
    --output "${METADATA_BODY}" \
    --write-out 'http_code=%{http_code} remote_ip=%{remote_ip} remote_port=%{remote_port} bytes=%{size_download} dns_seconds=%{time_namelookup} connect_seconds=%{time_connect} first_byte_seconds=%{time_starttransfer} total_seconds=%{time_total}' \
    "${METADATA_URL}" 2>"${METADATA_ERROR}")"
  CURL_EXIT=$?
  METADATA_ELAPSED=$(( $(date +%s) - METADATA_STARTED ))
  log INFO "Metadata attempt ${METADATA_ATTEMPT} completed: curl_exit=${CURL_EXIT} elapsed_seconds=${METADATA_ELAPSED} ${CURL_RESULT:-no_metrics}"

  if [[ -s "${METADATA_ERROR}" ]]; then
    while IFS= read -r line; do log ERROR "Metadata attempt ${METADATA_ATTEMPT} curl: ${line}"; done <"${METADATA_ERROR}"
  fi

  if [[ -s "${METADATA_BODY}" ]]; then
    log INFO "Metadata attempt ${METADATA_ATTEMPT} response body: $(tr '\n' ' ' <"${METADATA_BODY}")"
  else
    log WARN "Metadata attempt ${METADATA_ATTEMPT} returned an empty response body"
  fi

  PETNAME="$(jq -er '.petname | select(type == "string" and length > 0)' "${METADATA_BODY}" 2>/dev/null || true)"
  if [[ ${CURL_EXIT} -eq 0 && "${CURL_RESULT}" == http_code=2* && -n "${PETNAME}" ]]; then
    log INFO "Metadata attempt ${METADATA_ATTEMPT} succeeded: petname=${PETNAME}"
    break
  fi

  log WARN "Metadata attempt ${METADATA_ATTEMPT} failed: endpoint, JSON response, or petname is unavailable"
  log INFO "Next metadata attempt is scheduled in ${METADATA_RETRY_SECONDS} seconds"
  sleep "${METADATA_RETRY_SECONDS}"
done

TARGET_HOST="${PETNAME}.${DOMAIN_SUFFIX}"
BASE_URL="https://${TARGET_HOST}"
log INFO "Resolved traffic target from metadata: namespace=${PETNAME} host=${TARGET_HOST} base_url=${BASE_URL}"

RUN_NUMBER=0
while true; do
  RUN_NUMBER=$((RUN_NUMBER + 1))
  RUN_STARTED="$(date +%s)"
  log INFO "Traffic run ${RUN_NUMBER} started"
  log INFO "Traffic run ${RUN_NUMBER} DNS lookup for ${TARGET_HOST} follows"
  if ! nslookup "${TARGET_HOST}" 2>&1 | while IFS= read -r line; do log INFO "DNS: ${line}"; done; then
    log WARN "Traffic run ${RUN_NUMBER}: DNS lookup failed; Newman will still run the collection"
  fi

  log INFO "Traffic run ${RUN_NUMBER}: generating a fresh Postman collection from OpenAPI"
  openapi2postmanv2 \
    -s ./api/openbanking.json \
    -p \
    -o collection.json \
    -O folderStrategy=Tags,parametersResolution=Schema,stackLimit=50,schemaFaker=true 2>&1 |
    while IFS= read -r line; do log INFO "openapi2postmanv2: ${line}"; done
  CONVERTER_EXIT=${PIPESTATUS[0]}

  if [[ ${CONVERTER_EXIT} -ne 0 || ! -s collection.json ]]; then
    log ERROR "Traffic run ${RUN_NUMBER}: collection generation failed with exit code ${CONVERTER_EXIT}"
    log INFO "Traffic run ${RUN_NUMBER}: retrying in ${INTERVAL_SECONDS} seconds"
    sleep "${INTERVAL_SECONDS}"
    continue
  fi

  COLLECTION_BYTES="$(wc -c < collection.json)"
  COLLECTION_REQUESTS="$(jq '[.. | objects | select(has("request"))] | length' collection.json 2>/dev/null || echo unknown)"
  log INFO "Traffic run ${RUN_NUMBER}: collection generated successfully; bytes=${COLLECTION_BYTES} requests=${COLLECTION_REQUESTS}"
  log INFO "Traffic run ${RUN_NUMBER}: starting Newman against ${BASE_URL}; request failures are expected and will not stop future runs"

  newman run collection.json \
    --env-var "baseUrl=${BASE_URL}" \
    --insecure \
    --verbose \
    --color off \
    --timeout-request "${REQUEST_TIMEOUT_MS}" 2>&1 |
    while IFS= read -r line; do log INFO "newman run ${RUN_NUMBER}: ${line}"; done
  NEWMAN_EXIT=${PIPESTATUS[0]}
  RUN_ELAPSED=$(( $(date +%s) - RUN_STARTED ))

  if [[ ${NEWMAN_EXIT} -eq 0 ]]; then
    log INFO "Traffic run ${RUN_NUMBER} completed successfully: newman_exit=${NEWMAN_EXIT} elapsed_seconds=${RUN_ELAPSED}"
  else
    log WARN "Traffic run ${RUN_NUMBER} completed with request or assertion failures: newman_exit=${NEWMAN_EXIT} elapsed_seconds=${RUN_ELAPSED}"
  fi

  log INFO "Traffic run ${RUN_NUMBER} finished; next run starts in ${INTERVAL_SECONDS} seconds"
  sleep "${INTERVAL_SECONDS}"
done
