# Arcadia Finance Open Banking API services

This application is taken from the original [Arcadia Finance Open Banking API repository](https://github.com/yoctoalex/arcadia-finance/tree/master/openbanking).

The OpenAPI mock is split into three independently built API services. A fourth image provides Swagger UI for interactively calling those APIs. Each image listens on port `8080`:
| Service | Endpoints | Container image |
| ---------- | ---------------------------------------- | -------------------------------------------------------------------- |
| Banks | `/banks`, `/banks/{bankId}` | `docker.io/interestingstorage/partner-spec-security:banks-latest` |
| Accounts | `/accounts` and nested account endpoints | `docker.io/interestingstorage/partner-spec-security:accounts-latest` |
| Payments | `/payments` and nested payment endpoints | `docker.io/interestingstorage/partner-spec-security:payments-latest` |
| Swagger UI | `/swagger/` | `docker.io/interestingstorage/partner-spec-security:swagger-latest` |
| Traffic generator | OpenAPI-generated requests via Newman | `ghcr.io/f5selevin/arcadia-finance-open-banking/traffic:latest` |

```shell README.md
docker run --rm -p 8080:8080 docker.io/interestingstorage/partner-spec-security:banks-latest
docker run --rm -p 8080:8080 docker.io/interestingstorage/partner-spec-security:accounts-latest
docker run --rm -p 8080:8080 docker.io/interestingstorage/partner-spec-security:payments-latest
docker run --rm -p 8081:8080 docker.io/interestingstorage/partner-spec-security:swagger-latest
```

## Build locally

```shell README.md
docker build -f Dockerfile.banks -t openbanking-banks:latest .
docker build -f Dockerfile.accounts -t openbanking-accounts:latest .
docker build -f Dockerfile.payments -t openbanking-payments:latest .
docker build -f Dockerfile.swagger -t openbanking-swagger:latest .
docker build -f Dockerfile.traffic -t openbanking-traffic-generator:latest .
```

## Traffic generator

The traffic image follows the upstream `Dockerfile.postman` approach: it uses
`openapi-to-postmanv2` to generate a Postman collection from `api/openbanking.json`, then runs the
entire collection with the Newman CLI in a continuous loop. It obtains the namespace from the
metadata `petname` and targets `https://<petname>.spec-security.f5se.com`. Request failures are
expected while the domain is being provisioned and do not stop the loop.

Install, register, and start the separate Docker container as a systemd service from a local checkout:

```shell README.md
sudo ./udf/install-traffic-generator.sh
```

Alternatively, download and execute the installer directly from GitHub on a UDF host:

```shell README.md
curl --fail --silent --show-error --location \
  https://raw.githubusercontent.com/f5selevin/arcadia-finance-open-banking/main/udf/install-traffic-generator.sh \
  | sudo bash
```

The installer always checks GHCR for the latest traffic image before starting the service. View its
logs with:

```shell README.md
journalctl -u openbanking-traffic-generator.service -f
```
