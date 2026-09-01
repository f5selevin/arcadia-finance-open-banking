#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="openbanking-traffic-generator.service"
SERVICE_USER="${SERVICE_USER:-ubuntu}"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
IMAGE_NAME="${TRAFFIC_IMAGE:-openbanking-traffic-generator:latest}"
CONTAINER_NAME="${TRAFFIC_CONTAINER:-openbanking-traffic-generator}"
METADATA_URL="${METADATA_URL:-http://10.1.1.4:5123/metadata}"
DOMAIN_SUFFIX="${DOMAIN_SUFFIX:-spec-security.f5se.com}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-1}"
METADATA_RETRY_SECONDS="${METADATA_RETRY_SECONDS:-10}"
METADATA_TIMEOUT_SECONDS="${METADATA_TIMEOUT_SECONDS:-10}"
REQUEST_TIMEOUT_MS="${REQUEST_TIMEOUT_MS:-10000}"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this installer as root (for example: sudo $0)" >&2
  exit 1
fi

for command in docker systemctl; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Required command not found: ${command}" >&2
    exit 1
  fi
done

if [[ ! -f "${APP_DIR}/Dockerfile.traffic" || ! -f "${APP_DIR}/traffic-generator/entrypoint.sh" || ! -f "${APP_DIR}/api/openbanking.json" ]]; then
  echo "Traffic generator sources were not found under ${APP_DIR}" >&2
  exit 1
fi

if ! id "${SERVICE_USER}" >/dev/null 2>&1; then
  echo "Service user does not exist: ${SERVICE_USER}" >&2
  exit 1
fi

SERVICE_GROUP="$(id -gn "${SERVICE_USER}")"
INSTALL_DIR="/opt/openbanking-traffic-generator"

echo "Installing traffic generator files in ${INSTALL_DIR}"
install -d -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" -m 0755 \
  "${INSTALL_DIR}/traffic-generator" "${INSTALL_DIR}/api"
install -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" -m 0644 \
  "${APP_DIR}/Dockerfile.traffic" "${INSTALL_DIR}/Dockerfile.traffic"
install -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" -m 0755 \
  "${APP_DIR}/traffic-generator/entrypoint.sh" "${INSTALL_DIR}/traffic-generator/entrypoint.sh"
install -o "${SERVICE_USER}" -g "${SERVICE_GROUP}" -m 0644 \
  "${APP_DIR}/api/openbanking.json" "${INSTALL_DIR}/api/openbanking.json"

echo "Building ${IMAGE_NAME}"
docker build --pull -f "${INSTALL_DIR}/Dockerfile.traffic" -t "${IMAGE_NAME}" "${INSTALL_DIR}"

cat >"${UNIT_PATH}" <<EOF
[Unit]
Description=Open Banking Postman traffic generator
Wants=network-online.target docker.service
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker rm -f ${CONTAINER_NAME}
ExecStart=/usr/bin/docker run --name ${CONTAINER_NAME} --network host -e METADATA_URL=${METADATA_URL} -e DOMAIN_SUFFIX=${DOMAIN_SUFFIX} -e INTERVAL_SECONDS=${INTERVAL_SECONDS} -e METADATA_RETRY_SECONDS=${METADATA_RETRY_SECONDS} -e METADATA_TIMEOUT_SECONDS=${METADATA_TIMEOUT_SECONDS} -e REQUEST_TIMEOUT_MS=${REQUEST_TIMEOUT_MS} ${IMAGE_NAME}
ExecStop=-/usr/bin/docker stop -t 10 ${CONTAINER_NAME}
ExecStopPost=-/usr/bin/docker rm -f ${CONTAINER_NAME}

[Install]
WantedBy=multi-user.target
EOF

chmod 0644 "${UNIT_PATH}"
systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}"

echo "Installed and started ${SERVICE_NAME}."
echo "View traffic with: journalctl -u ${SERVICE_NAME} -f"
