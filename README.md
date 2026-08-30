# Arcadia Finance Open Banking API services

This application is taken from the original [Arcadia Finance Open Banking API repository](https://github.com/yoctoalex/arcadia-finance/tree/master/openbanking).

The OpenAPI mock is split into three independently built API services. A fourth image provides Swagger UI for interactively calling those APIs. Each image listens on port `8080`:

| Service    | Endpoints                                | Container image                                                      |
| ---------- | ---------------------------------------- | -------------------------------------------------------------------- |
| Banks      | `/banks`, `/banks/{bankId}`              | `docker.io/interestingstorage/partner-spec-security:banks-latest`    |
| Accounts   | `/accounts` and nested account endpoints | `docker.io/interestingstorage/partner-spec-security:accounts-latest` |
| Payments   | `/payments` and nested payment endpoints | `docker.io/interestingstorage/partner-spec-security:payments-latest` |
| Swagger UI | `/swagger/`                              | `docker.io/interestingstorage/partner-spec-security:swagger-latest`  |

## Run an image

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
```
