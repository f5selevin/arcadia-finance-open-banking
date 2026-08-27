# Arcadia Finance Open Banking services

This application is taken from the original [Arcadia Finance Open Banking repository](https://github.com/yoctoalex/arcadia-finance/tree/master/openbanking).

The OpenAPI mock is split into three independently built API services. A fourth image provides Swagger UI for interactively calling those APIs. Each image listens on port `8080`:

| Service    | Endpoints                                | Container image                                                                                                                                                                      |
| ---------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Banks      | `/banks`, `/banks/{bankId}`              | [`ghcr.io/f5selevin/arcadia-finance-open-banking/banks:latest`](https://github.com/f5selevin/arcadia-finance-open-banking/pkgs/container/arcadia-finance-open-banking%2Fbanks)       |
| Accounts   | `/accounts` and nested account endpoints | [`ghcr.io/f5selevin/arcadia-finance-open-banking/accounts:latest`](https://github.com/f5selevin/arcadia-finance-open-banking/pkgs/container/arcadia-finance-open-banking%2Faccounts) |
| Payments   | `/payments` and nested payment endpoints | [`ghcr.io/f5selevin/arcadia-finance-open-banking/payments:latest`](https://github.com/f5selevin/arcadia-finance-open-banking/pkgs/container/arcadia-finance-open-banking%2Fpayments) |
| Swagger UI | `/swagger/`                              | [`ghcr.io/f5selevin/arcadia-finance-open-banking/swagger:latest`](https://github.com/f5selevin/arcadia-finance-open-banking/pkgs/container/arcadia-finance-open-banking%2Fswagger)   |

## Run an image

```shell README.md
docker run --rm -p 8080:8080 ghcr.io/f5selevin/arcadia-finance-open-banking/banks:latest
docker run --rm -p 8080:8080 ghcr.io/f5selevin/arcadia-finance-open-banking/accounts:latest
docker run --rm -p 8080:8080 ghcr.io/f5selevin/arcadia-finance-open-banking/payments:latest
docker run --rm -p 8081:8080 ghcr.io/f5selevin/arcadia-finance-open-banking/swagger:latest
```

## Build locally

```shell README.md
docker build -f Dockerfile.banks -t openbanking-banks:latest .
docker build -f Dockerfile.accounts -t openbanking-accounts:latest .
docker build -f Dockerfile.payments -t openbanking-payments:latest .
docker build -f Dockerfile.swagger -t openbanking-swagger:latest .
```

## Publishing

The `Build and publish service images` GitHub Actions workflow builds all four Dockerfiles on every push to `main`, and can also be run manually. It authenticates with the repository-provided `GITHUB_TOKEN` and always pushes only the `latest` tag to GitHub Container Registry; no version tags are maintained.
