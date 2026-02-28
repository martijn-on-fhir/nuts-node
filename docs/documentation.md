# Nuts Node — Complete Developer Documentation

> Compiled from [nuts-node.readthedocs.io](https://nuts-node.readthedocs.io/en/stable/), [wiki.nuts.nl](https://wiki.nuts.nl), and [GitHub](https://github.com/nuts-foundation/nuts-node).
> Covers **v6.x** (stable). Latest release: **v6.1.11** (Feb 2026).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Core Concepts](#2-core-concepts)
3. [Running the Node (Docker)](#3-running-the-node-docker)
4. [Running the Node (Native Binary)](#4-running-the-node-native-binary)
5. [Configuration Reference](#5-configuration-reference)
6. [Architecture & Deployment](#6-architecture--deployment)
7. [API Reference](#7-api-reference)
8. [Integration Workflow (Step-by-Step)](#8-integration-workflow-step-by-step)
9. [Discovery Service](#9-discovery-service)
10. [OAuth2 / Access Tokens](#10-oauth2--access-tokens)
11. [Verifiable Credentials](#11-verifiable-credentials)
12. [Storage](#12-storage)
13. [Security & Production Checklist](#13-security--production-checklist)
14. [Supported Protocols & Formats](#14-supported-protocols--formats)
15. [Monitoring & Health](#15-monitoring--health)
16. [Troubleshooting / FAQ](#16-troubleshooting--faq)
17. [Ecosystem & Tooling](#17-ecosystem--tooling)

---

## 1. Overview

**Nuts Node** is an open-source, decentralized identity network node built on W3C Self-Sovereign Identity (SSI) concepts, designed primarily for the healthcare domain but applicable to any trust network.

It provides:

- **`did:web` and `did:nuts`** — Decentralized Identifier (DID) methods
- **OpenID4VC** — OpenID4VCI (Verifiable Credential Issuance) and OpenID4VP (Verifiable Presentations)
- **PEX** — Presentation Exchange for credential negotiation
- **Private key management** — Filesystem, HashiCorp Vault, Azure Key Vault backends
- **Discovery Service** — Decentralized service/endpoint discovery
- **OAuth2 Authorization** — VP Token Grant and Authorization Code Flow with OpenID4VP

Written in **Go** (97%), licensed under **GPL-3.0**.

**Source:** https://github.com/nuts-foundation/nuts-node
**Docs:** https://nuts-node.readthedocs.io/en/stable/
**Wiki:** https://wiki.nuts.nl

---

## 2. Core Concepts

### 2.1 Subjects

In v6, you no longer manage DIDs directly — you manage **subjects**. Each subject can have multiple DIDs (one per enabled DID method, e.g., `did:web` + `did:nuts`). You choose a subject identifier or let the node generate one.

### 2.2 DIDs (Decentralized Identifiers)

DIDs are W3C standard identifiers. The Nuts node supports:

| DID Method | Description |
|---|---|
| `did:web` | Web-based DID resolution via `.well-known` |
| `did:nuts` | Nuts-network-specific (legacy, gRPC-based) |
| `did:key` | Resolution only |
| `did:jwk` | Resolution only |

Enabled methods are controlled via `didmethods` config (default: `['web','nuts']`).

### 2.3 Verifiable Credentials (VCs)

W3C Verifiable Credentials are attestations (claims) about a subject, signed by an issuer. Key VC types in the Nuts ecosystem:

- **NutsOrganizationCredential** — Organization name + city
- **NutsUraCredential** — URA (healthcare registration) credential
- **NutsEmployeeCredential** — User/employee identity (often self-attested)
- **DiscoveryRegistrationCredential** — Metadata for discovery (e.g., authServerURL)

### 2.4 Verifiable Presentations (VPs)

VPs bundle one or more VCs with a proof from the holder. Used in OAuth2 flows and Discovery Service registrations.

### 2.5 Presentation Exchange (PEX)

A standard for specifying what credentials a verifier requires. Used in Discovery Service Definitions and Policy Definitions.

### 2.6 Discovery Service

A centralized-per-use-case registry where participants register their VPs (containing VCs) to be discoverable. Each use case has a **Service Definition** JSON file.

### 2.7 Policy Definitions

JSON files that map OAuth2 scopes to Presentation Definitions. They instruct the node which credentials a caller must present to get an access token for a given scope.

---

## 3. Running the Node (Docker)

### Quick Start (Docker CLI)

```bash
docker run --name nuts -p 8080:8080 -p 8081:8081 \
  -e NUTS_STRICTMODE=false \
  -e NUTS_HTTP_INTERNAL_ADDRESS=":8081" \
  -e NUTS_URL="http://nuts" \
  nutsfoundation/nuts-node:latest
```

### Docker Compose

```yaml
services:
  nuts:
    image: nutsfoundation/nuts-node:latest
    environment:
      NUTS_STRICTMODE: false
      NUTS_URL: http://nuts
      NUTS_HTTP_INTERNAL_ADDRESS: ":8081"
    ports:
      - 8080:8080
      - 8081:8081
    volumes:
      - nuts-data:/nuts/data
      - ./config:/nuts/config:ro

volumes:
  nuts-data:
```

### Container Details

| Path | Purpose |
|---|---|
| `/nuts/config/` | Config directory (mount read-only). Default for `nuts.yaml`, discovery defs, policy defs, TLS certs. |
| `/nuts/data/` | Data directory for node-managed storage. Must be writable. Back this up. |
| Port `8080` | Public-facing HTTP interface |
| Port `8081` | Internal HTTP interface (APIs for your app) |
| Port `5555` | gRPC (only needed for `did:nuts` network) |

Container runs as user **18081** (non-root). If mounting a host data dir, set ownership:
```bash
chown -R 18081:18081 /path/to/host/data-dir
```

### Development Image

A dev image with built-in HTTPS tunnel (via GitHub auth) is available:
```
nutsfoundation/nuts-node:dev
```

### Health Check

```
GET http://localhost:8081/health
```

---

## 4. Running the Node (Native Binary)

### Build from Source

Requires Go 1.22+:

```bash
go build -ldflags="-w -s \
  -X 'github.com/nuts-foundation/nuts-node/core.GitCommit=GIT_COMMIT' \
  -X 'github.com/nuts-foundation/nuts-node/core.GitBranch=GIT_BRANCH' \
  -X 'github.com/nuts-foundation/nuts-node/core.GitVersion=GIT_VERSION'" \
  -o /path/to/nuts
```

### Start the Server

```bash
nuts server
```

### ES256K (Koblitz) Support

```bash
go build -tags jwx_es256k
```

---

## 5. Configuration Reference

Configuration can be provided via:
1. **CLI flags** (highest priority): `nuts --parameter value`
2. **Environment variables**: `NUTS_PARAMETER=value`
3. **YAML config file** (default: `./nuts.yaml`): `parameter: value`
4. **Defaults** (lowest priority)

Nested config: `nested.parameter` → `NUTS_NESTED_PARAMETER` → `nested:\n  parameter:`

### Core Server Options

| Key | Default | Description |
|---|---|---|
| `configfile` | `./config/nuts.yaml` | Path to config file |
| `datadir` | `./data` | Data storage directory |
| `didmethods` | `[web,nuts]` | Enabled DID methods |
| `strictmode` | `true` | Enforce production-safe settings |
| `url` | *(required)* | Public-facing URL (HTTPS in strict mode) |
| `verbosity` | `info` | Log level: trace/debug/info/warn/error |
| `loggerformat` | `text` | Log format: text/json |
| `internalratelimiter` | `true` | Rate-limit expensive internal calls |

### HTTP

| Key | Default | Description |
|---|---|---|
| `http.public.address` | `:8080` | Public HTTP interface |
| `http.internal.address` | `127.0.0.1:8081` | Internal HTTP interface |
| `http.internal.auth.type` | *(empty)* | `token_v2` for JWT bearer auth on `/internal` |
| `http.internal.auth.authorizedkeyspath` | *(empty)* | Path to authorized_keys for JWT signers |
| `http.internal.auth.audience` | *(hostname)* | Expected JWT audience |
| `http.log` | `metadata` | Request logging: nothing/metadata/metadata-and-body |
| `http.clientipheader` | `X-Forwarded-For` | Header for client IP in audit logs |
| `http.cache.maxbytes` | `10485760` | HTTP client response cache size |
| `httpclient.timeout` | `30s` | HTTP client timeout |

### Crypto / Key Storage

| Key | Default | Description |
|---|---|---|
| `crypto.storage` | *(must be set in strict)* | `fs`, `vaultkv`, `azure-keyvault`, `external` |
| `crypto.vault.address` | | Vault address (overrides `VAULT_ADDR`) |
| `crypto.vault.token` | | Vault token (overrides `VAULT_TOKEN`) |
| `crypto.vault.pathprefix` | `kv` | Vault KV path prefix |
| `crypto.vault.timeout` | `5s` | Vault client timeout |
| `crypto.azurekv.url` | | Azure Key Vault URL |
| `crypto.azurekv.auth.type` | `default` | `default` or `managed_identity` |
| `crypto.azurekv.hsm` | `false` | Use HSM-backed keys |
| `crypto.azurekv.timeout` | `10s` | Azure KV client timeout |

### Auth

| Key | Default | Description |
|---|---|---|
| `auth.authorizationendpoint.enabled` | `false` | Enable OAuth2 Authorization Endpoint (OpenID4VP/VCI) |

### Discovery

| Key | Default | Description |
|---|---|---|
| `discovery.definitions.directory` | `./config/discovery` | Directory for discovery service definition JSON files |
| `discovery.server.ids` | `[]` | IDs of services this node serves |
| `discovery.client.refreshinterval` | `10m` | Sync interval with discovery servers |

### Storage

| Key | Default | Description |
|---|---|---|
| `storage.sql.connection` | *(SQLite in datadir)* | SQL connection string (Postgres/MySQL recommended for prod) |
| `storage.session.redis.address` | | Redis address for sessions |
| `storage.session.redis.database` | | Redis DB prefix |
| `storage.session.memcached.address` | `[]` | Memcached addresses for sessions |

### Policy

| Key | Default | Description |
|---|---|---|
| `policy.directory` | `./config/policy` | Directory for policy definition JSON files |

### PKI

| Key | Default | Description |
|---|---|---|
| `pki.softfail` | `true` | Don't reject certs if revocation status unknown |
| `pki.maxupdatefailhours` | `4` | Max hours a denylist update can fail |

### JSON-LD

| Key | Default | Description |
|---|---|---|
| `jsonld.contexts.localmapping` | *(various)* | Map external URLs to local files |
| `jsonld.contexts.remoteallowlist` | *(various)* | Allowed external context URLs (strict mode) |

### did:nuts / gRPC (Legacy)

| Key | Default | Description |
|---|---|---|
| `tls.certfile` | | gRPC TLS certificate PEM |
| `tls.certkeyfile` | | gRPC TLS private key PEM |
| `tls.truststorefile` | `./config/ssl/truststore.pem` | Trusted CA certificates |
| `network.grpcaddr` | `:5555` | gRPC listen address |
| `network.nodedid` | | DID of the node operator |
| `network.bootstrapnodes` | `[]` | Bootstrap nodes (host:port) |

---

## 6. Architecture & Deployment

### HTTP Interface Layout

```
PUBLIC (:8080)                         INTERNAL (127.0.0.1:8081)
├── /.well-known   (DID, OAuth2 meta)  ├── /internal/vdr/v2   (DID/Subject mgmt)
├── /oauth2        (OAuth2 flows)      ├── /internal/vcr/v2   (VC Registry)
├── /statuslist    (VC revocations)    ├── /internal/auth/v2  (Auth/Tokens)
├── /discovery     (Discovery server)  ├── /internal/discovery/v1  (Discovery)
├── /n2n           (Node-to-node)      ├── /internal/crypto   (Key management)
└── /public        (IRMA auth)         ├── /internal/didman   (DID Manager)
                                       ├── /health            (Health check)
                                       └── /status/diagnostics
```

### Recommended Architecture

```
                    ┌─────────────────────┐
                    │   Reverse Proxy     │
                    │  (TLS termination)  │
                    └─────┬───────┬───────┘
                          │       │
              Public :8080│       │Internal :8081
                    ┌─────┴───────┴───────┐
                    │     Nuts Node       │
                    │                     │
                    ├── SQL DB (PG/MySQL) │
                    ├── Key Store (Vault) │
                    └── Redis (sessions)  │
                    └─────────────────────┘
                          │
                    ┌─────┴───────┐
                    │  Your App   │
                    │ (TypeScript)│
                    └─────────────┘
```

**Key points:**
- Always deploy behind a reverse proxy that handles TLS
- Internal interface (`/internal`) must NEVER be exposed publicly
- Public interface needs HTTPS with a publicly trusted certificate
- In production: use PostgreSQL or MySQL (not SQLite), Vault for keys

---

## 7. API Reference

The Nuts Node exposes several OpenAPI-specified APIs. Specs are in the repo under `docs/_static/<engine>/<version>.yaml`.

### API Modules

| Module | Base Path | Description |
|---|---|---|
| **VDR v2** | `/internal/vdr/v2` | Subject & DID management |
| **VCR v2** | `/internal/vcr/v2` | VC issuing, searching, wallet, revocation |
| **Auth v2** | `/internal/auth/v2` | Access tokens, token introspection |
| **Discovery v1** | `/internal/discovery/v1` | Service registration & search |
| **DID Manager** | `/internal/didman` | Legacy DID document/service management |
| **Crypto** | `/internal/crypto` | Key management |
| **Network** | `/internal/network/v1` | Network/peer management (did:nuts) |
| **Monitoring** | `/health`, `/status/diagnostics` | Health & diagnostics |

### API Authentication

For production, secure `/internal` with JWT bearer tokens:

```yaml
http:
  internal:
    auth:
      type: token_v2
      authorizedkeyspath: /path/to/authorized_keys
```

The admin configures trusted public keys; the API client signs JWTs with the private key.

---

## 8. Integration Workflow (Step-by-Step)

This is the complete workflow for integrating your application with the Nuts Node.

### Step 1: Create a Subject

Create an identity (subject) for each organization/tenant you manage:

```http
POST /internal/vdr/v2/subject
Content-Type: application/json

{
  "subject": "my_organization"
}
```

**Response:**
```json
{
  "subject": "my_organization",
  "documents": [
    {
      "id": "did:nuts:B8PUHs2AUHbFF1xLLK4eZjgErEcMXHxs68FteY7NDtCY"
    },
    {
      "id": "did:web:example.com:iam:657f064a-ebef-4f0f-aa87-88ed32db3142"
    }
  ]
}
```

The `subject` field is optional — if omitted, an ID is generated for you.

### Step 2: List DIDs for a Subject

```http
GET /internal/vdr/v2/subject/my_organization
```

**Response:**
```json
[
  "did:nuts:B8PUHs2AUHbFF1xLLK4eZjgErEcMXHxs68FteY7NDtCY",
  "did:web:example.com:iam:657f064a-ebef-4f0f-aa87-88ed32db3142"
]
```

### Step 3: Issue a Verifiable Credential

Issue a `NutsOrganizationCredential` from one of the subject's DIDs:

```http
POST /internal/vcr/v2/issuer/vc
Content-Type: application/json

{
  "@context": "https://nuts.nl/credentials/v1",
  "type": "NutsOrganizationCredential",
  "issuer": "did:web:example.com:iam:issuer",
  "credentialSubject": {
    "id": "did:web:example.com:iam:657f064a-ebef-4f0f-aa87-88ed32db3142",
    "organization": {
      "name": "Care Bears Hospital",
      "city": "Amsterdam"
    }
  },
  "withStatusList2021Revocation": true
}
```

**Response:** Full VC with proof, credential status, etc.

### Step 4: Load a Credential into a Wallet

If a credential was issued by another party (received out-of-band), load it into the holder's wallet:

```http
POST /internal/vcr/v2/holder/{did}/vc
Content-Type: application/json

{
  ... (the full Verifiable Credential JSON)
}
```

Replace `{did}` with the holder's DID.

### Step 5: Activate a Discovery Service

Register the subject on a Discovery Service so others can find them:

```http
POST /internal/discovery/v1/{serviceDefinitionId}/{subjectId}
Content-Type: application/json

{
  "registrationParameters": {
    "fhir": "https://api.example.com/fhir",
    "contact": "admin@example.com"
  }
}
```

- `200 OK` = immediately registered
- `202 Accepted` = queued, will retry

### Step 6: Search the Discovery Service

Find other participants:

```http
GET /internal/discovery/v1/{serviceDefinitionId}?organization_name=Care*
```

Matching is case-insensitive; `*` = wildcard.

**Response:**
```json
[
  {
    "id": "did:web:example.com:iam:657f#049fb56e",
    "credential_subject_id": "did:web:example.com:iam:657f",
    "fields": {
      "organization_name": "Care Bears Hospital"
    },
    "registrationParameters": {
      "authServerURL": "https://example.com/oauth2/other_subject",
      "fhir": "https://api.example.com/fhir",
      "contact": "admin@example.com"
    }
  }
]
```

The `authServerURL` is automatically added by the Nuts node.

### Step 7: Request an Access Token

Use the `authServerURL` from the search result to request an access token:

```http
POST /internal/auth/v2/{subjectId}/request-service-access-token
Content-Type: application/json

{
  "authorization_server": "https://example.com/oauth2/other_subject",
  "scope": "eOverdracht-sender",
  "token_type": "Bearer"
}
```

Optional: include additional credentials (e.g., `NutsEmployeeCredential`):

```json
{
  "authorization_server": "https://example.com/oauth2/other_subject",
  "scope": "eOverdracht-sender",
  "credentials": [
    {
      "@context": [
        "https://www.w3.org/2018/credentials/v1",
        "https://nuts.nl/credentials/v1"
      ],
      "type": ["VerifiableCredential", "NutsEmployeeCredential"],
      "credentialSubject": {
        "name": "John Doe",
        "roleName": "Nurse",
        "identifier": "123456"
      }
    }
  ]
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

### Step 8: Call the Remote Resource Server

Use the access token to call the remote API:

```http
GET https://api.example.com/fhir/Patient/123
Authorization: Bearer eyJhbGciOiJSUzI...
```

### Step 9: Validate Incoming Access Tokens (Resource Server)

When your app receives a request with an access token, introspect it:

```http
POST /internal/auth/v2/accesstoken/introspect
Content-Type: application/x-www-form-urlencoded

token=eyJhbGciOiJSUzI...
```

**Response:**
```json
{
  "active": true,
  "iss": "https://example.com/oauth2/other_subject",
  "client_id": "https://example.com/oauth2/my_subject",
  "scope": "eOverdracht-sender",
  "organization_name": "Care Bears Hospital"
}
```

Fields from the Presentation Definition constraints are included as key/value pairs. Use these for authorization decisions.

---

## 9. Discovery Service

### Service Definition (JSON)

Each use case provides a service definition file. Place it in `discovery.definitions.directory`:

```json
{
  "id": "coffeecorner",
  "did_methods": ["web", "nuts"],
  "endpoint": "https://discovery-server.example.com/discovery/coffeecorner",
  "presentation_max_validity": 36000,
  "presentation_definition": {
    "id": "coffeecorner2024",
    "format": {
      "ldp_vc": { "proof_type": ["JsonWebSignature2020"] },
      "jwt_vp": { "alg": ["ES256"] }
    },
    "input_descriptors": [
      {
        "id": "NutsOrganizationCredential",
        "constraints": {
          "fields": [
            {
              "path": ["$.type"],
              "filter": { "type": "string", "const": "NutsOrganizationCredential" }
            },
            {
              "id": "organization_name",
              "path": ["$.credentialSubject.organization.name"],
              "filter": { "type": "string" }
            },
            {
              "path": ["$.credentialSubject.organization.city"],
              "filter": { "type": "string" }
            }
          ]
        }
      },
      {
        "id": "DiscoveryRegistrationCredential",
        "constraints": {
          "fields": [
            {
              "id": "auth_server_url",
              "path": ["$.credentialSubject.authServerURL"]
            }
          ]
        }
      }
    ]
  }
}
```

### Server vs Client

- **Server:** Set `discovery.server.ids` to the service definition IDs your node serves
- **Client:** Just load the service definition files. The node auto-syncs at `discovery.client.refreshinterval`

### Registration API

```http
POST /internal/discovery/v1/{serviceId}/{subjectId}
Content-Type: application/json

{
  "registrationParameters": {
    "fhir": "https://api.example.com/fhir"
  }
}
```

The `authServerURL` is automatically constructed as `https://<config.url>/oauth2/<subject_id>`.

### Search API

```http
GET /internal/discovery/v1/{serviceId}?organization_name=Hospital*
```

Search parameters correspond to constraint `id` fields in the Presentation Definition.

---

## 10. OAuth2 / Access Tokens

### Flows

The Nuts node implements two OAuth2 flows:

1. **VP Token Grant Type** — System-to-system, no user interaction. The client presents VCs directly.
2. **Authorization Code Flow with OpenID4VP** — User-interactive flow with JAR, PKCE, and DPoP.

### Token Types

| Type | Description |
|---|---|
| `DPoP` | Default. Proof-of-possession token. Mitigates token theft. Requires DPoP Proof header per request. |
| `Bearer` | Standard bearer token. Simpler but more vulnerable to MITM. |

### Policy Definitions

Policy files map scopes to Presentation Definitions. Place in `policy.directory`:

```json
{
  "coffeecorner": {
    "coffee": {
      "presentation_definition": {
        "id": "coffee-access",
        "input_descriptors": [
          {
            "id": "NutsOrganizationCredential",
            "constraints": {
              "fields": [
                {
                  "path": ["$.type"],
                  "filter": { "type": "string", "const": "NutsOrganizationCredential" }
                },
                {
                  "id": "organization_name",
                  "path": ["$.credentialSubject.organization.name"]
                }
              ]
            }
          }
        ]
      }
    }
  }
}
```

### DPoP Flow Details

When using DPoP tokens:
- The Nuts node handles key material for DPoP Proof headers
- Each request to the resource server needs a new DPoP Proof
- The resource server must verify the DPoP Proof using the public key hash from introspection
- The Nuts node provides a convenience API for DPoP Proof creation

### Revocation

VCs with `StatusList2021Entry` credential status are automatically validated during token requests. Issue with revocation:

```json
{ "withStatusList2021Revocation": true }
```

---

## 11. Verifiable Credentials

### Issue a VC

```http
POST /internal/vcr/v2/issuer/vc
Content-Type: application/json

{
  "@context": "https://nuts.nl/credentials/v1",
  "type": "NutsOrganizationCredential",
  "issuer": "did:web:example.com:iam:issuer_subject",
  "credentialSubject": {
    "id": "did:web:example.com:iam:holder_subject",
    "organization": {
      "name": "Hospital X",
      "city": "Rotterdam"
    }
  },
  "withStatusList2021Revocation": true,
  "expirationDate": "2026-12-31T23:59:59Z"
}
```

Parameters:
- `issuer` — DID of the issuer (must be managed by this node)
- `type` — VC type string
- `credentialSubject.id` — DID of the holder
- `@context` — JSON-LD context(s)
- `withStatusList2021Revocation` — Enable revocation (optional)
- `expirationDate` — ISO 8601 (optional)
- `format` — `ldp_vc` (default) or `jwt_vc`
- `publishToNetwork` — `true`/`false` (did:nuts network publishing)
- `visibility` — `public`/`private` (did:nuts network)

### Load a VC into a Wallet

```http
POST /internal/vcr/v2/holder/{holderDID}/vc
Content-Type: application/json

{ ... full VC JSON ... }
```

### Search VCs

```http
POST /internal/vcr/v2/search
Content-Type: application/json

{
  "query": {
    "@context": [
      "https://www.w3.org/2018/credentials/v1",
      "https://nuts.nl/credentials/v1"
    ],
    "type": ["VerifiableCredential", "NutsOrganizationCredential"],
    "credentialSubject": {
      "organization": {
        "name": "Hospital*"
      }
    }
  }
}
```

Fields `@context` and `type` are required for JSON-LD context resolution but are NOT used as search filters. Add `credentialSubject` fields to filter results. Use `*` for prefix matching.

### Revoke a VC

```http
DELETE /internal/vcr/v2/issuer/vc/{vcID}
```

### Trust Management

Before VCs from an issuer can be used, the issuer must be trusted:

```http
POST /internal/vcr/v2/verifier/trust
Content-Type: application/json

{
  "issuer": "did:web:other-vendor.com:iam:subject",
  "credentialType": "NutsOrganizationCredential"
}
```

List untrusted issuers:
```http
GET /internal/vcr/v2/verifier/{credentialType}/untrusted
```

Alternatively, edit `<datadir>/vcr/trusted_issuers.yaml` directly.

---

## 12. Storage

### SQL Database

| Backend | Connection String Example |
|---|---|
| **SQLite** (default, dev only) | Auto-created in `datadir`. Enable foreign keys: `?_foreign_keys=on&_journal_mode=WAL` |
| **PostgreSQL** (recommended) | `postgresql://user:pass@host:5432/nuts` |
| **MySQL** | `user:pass@tcp(host:3306)/nuts` |
| **MS SQL Server** | `sqlserver://user:pass@host:1433?database=nuts` |

Set via `storage.sql.connection`.

### Private Key Storage

| Backend | Config | Notes |
|---|---|---|
| **Filesystem** | `crypto.storage: fs` | Default. Keys stored unencrypted on disk. Dev only. |
| **HashiCorp Vault** | `crypto.storage: vaultkv` | Recommended for production. Uses Vault KV v1. |
| **Azure Key Vault** | `crypto.storage: azure-keyvault` | HSM support available. |
| **External** | `crypto.storage: external` | Implement the Nuts Secret Store API. Deprecated. |

### Session Storage

For session data (e.g., OAuth2 flows):

- **In-memory** (default): Lost on restart
- **Redis**: Set `storage.session.redis.address`
- **Memcached**: Set `storage.session.memcached.address`

### Important Notes

- **No clustering support** — Even with Redis, you cannot run multiple nodes against the same storage
- **Always backup** data directory and private keys
- **Search indexes** stored on disk even with external SQL; retain the data directory

---

## 13. Security & Production Checklist

### Strict Mode (default: enabled)

When `strictmode=true`:

- `url` must be HTTPS
- `crypto.storage` must be explicitly set
- `storage.sql.connection` must be explicitly set
- TLS required for gRPC (`did:nuts`)
- IRMA server runs in production mode
- `auth.contractvalidators` ignores `dummy`
- `auth.accesstokenlifespan` forced to 60s
- JSON-LD contexts only from allowlisted domains
- Internal rate limiter always enabled
- No wildcard CORS origins

### Production Deployment Checklist

- [ ] Enable `strictmode=true`
- [ ] Set `url` to your public HTTPS URL
- [ ] Use PostgreSQL or MySQL for `storage.sql.connection`
- [ ] Use Vault or Azure Key Vault for `crypto.storage`
- [ ] Deploy behind a reverse proxy with TLS termination
- [ ] Ensure `/internal` endpoints are NOT publicly accessible
- [ ] Configure `http.clientipheader` for correct audit logging
- [ ] Set up backup for data directory and private keys
- [ ] Configure Redis for session storage (production)
- [ ] Enable API authentication on `/internal` with `http.internal.auth.type: token_v2`
- [ ] Monitor `/health` endpoint
- [ ] Set appropriate `verbosity` level

### Public Endpoints Security

| Endpoint | Security |
|---|---|
| `/.well-known` | HTTPS, publicly trusted cert |
| `/oauth2` | HTTPS, publicly trusted cert |
| `/statuslist` | HTTPS, publicly trusted cert |
| `/discovery` | HTTPS, publicly trusted cert |
| `/n2n` | HTTPS, mTLS with network trust anchors |
| `/public` (IRMA) | HTTPS, publicly trusted cert |

---

## 14. Supported Protocols & Formats

### DID Methods

| Method | Create | Resolve | Notes |
|---|---|---|---|
| `did:web` | ✅ | ✅ | Primary method for v6 |
| `did:nuts` | ✅ | ✅ | Legacy, requires gRPC network |
| `did:key` | ❌ | ✅ | Resolution only |
| `did:jwk` | ❌ | ✅ | Resolution only |

### VC Formats

| Format | Description |
|---|---|
| `ldp_vc` | JSON-LD with Linked Data Proof (JsonWebSignature2020) |
| `jwt_vc` | JWT-encoded VC |

### VP Formats

| Format | Description |
|---|---|
| `ldp_vp` | JSON-LD VP |
| `jwt_vp` | JWT-encoded VP |

### Key Types

- ES256 (P-256) — default
- ES384 (P-384)
- ES512 (P-521)
- ES256K (secp256k1) — requires build tag `jwx_es256k`

### OAuth2 Standards

- RFC 7523 — JWT Profile for OAuth 2.0
- RFC 9449 — DPoP (Demonstrating Proof of Possession)
- RFC 7636 — PKCE
- RFC 9101 — JAR (JWT Secured Authorization Request)
- OpenID4VP — OpenID for Verifiable Presentations
- OpenID4VCI — OpenID for Verifiable Credential Issuance
- Nuts RFC021 — VP Token Grant Type

---

## 15. Monitoring & Health

### Health Endpoint

```http
GET /health
```

Returns health state of the node including `network.auth_config` status.

### Diagnostics

```http
GET /status/diagnostics
```

Returns diagnostic information: version, uptime, peer connections, network state.

### Key Metrics to Monitor

- CPU and memory usage
- API response times
- `/health` status
- Discovery service registration status
- Network connectivity (for `did:nuts`)

---

## 16. Troubleshooting / FAQ

### "Root transaction already exists"

Network state incompatible. Either:
1. Created transactions before connecting to a network → Remove data directory, rejoin
2. Wrong bootstrap node configured → Fix bootstrap node config

### "NutsComm endpoint mismatch"

The NutsComm service endpoint on the `network.nodeDID` document must match the TLS certificate's SAN. Check all three: DID document, NutsComm endpoint, TLS certificate.

### "Can't introspect token"

Only the node that issued a token can introspect it. Ensure you're calling the correct node.

### Discovery registration returns 202

The node accepted the request but couldn't reach the discovery server yet. It will retry. Check logs for details.

### VC search returns no results

Ensure the issuer is trusted via `/internal/vcr/v2/verifier/trust`. By default, no issuers are trusted.

---

## 17. Ecosystem & Tooling

### Official Tools

| Tool | URL | Description |
|---|---|---|
| **Nuts Admin** | https://github.com/nuts-foundation/nuts-admin | Web UI for administering identities |
| **Nuts Network Local** | https://github.com/nuts-foundation/nuts-network-local | Local dev network setup |
| **Go Nuts Client** | https://github.com/nuts-foundation/go-nuts-client | Go client library (generated from OpenAPI) |
| **Java Nuts Client** | https://github.com/reinkrul/java-nuts-client | Java client library (generated from OpenAPI) |
| **Hashicorp Vault Proxy** | https://github.com/nuts-foundation/hashicorp-vault-proxy | Vault integration proxy |

### Generating a TypeScript Client

Since the Nuts Node APIs are specified in OpenAPI 3.0, you can generate a TypeScript client:

```bash
# Download the OpenAPI specs from the repo
# Located at: docs/_static/<module>/<version>.yaml

# Use openapi-generator or openapi-typescript-codegen
npx openapi-typescript-codegen \
  --input ./vdr-v2.yaml \
  --output ./src/generated/vdr \
  --client axios

npx openapi-typescript-codegen \
  --input ./vcr-v2.yaml \
  --output ./src/generated/vcr \
  --client axios

npx openapi-typescript-codegen \
  --input ./auth-v2.yaml \
  --output ./src/generated/auth \
  --client axios

npx openapi-typescript-codegen \
  --input ./discovery-v1.yaml \
  --output ./src/generated/discovery \
  --client axios
```

### TypeScript Integration Example

```typescript
import axios from 'axios';

const NUTS_INTERNAL = 'http://localhost:8081';

// 1. Create a subject
async function createSubject(id: string) {
  const res = await axios.post(`${NUTS_INTERNAL}/internal/vdr/v2/subject`, {
    subject: id,
  });
  return res.data; // { subject, documents[] }
}

// 2. Get DIDs for a subject
async function getSubjectDIDs(subjectId: string): Promise<string[]> {
  const res = await axios.get(`${NUTS_INTERNAL}/internal/vdr/v2/subject/${subjectId}`);
  return res.data;
}

// 3. Issue a credential
async function issueCredential(issuerDID: string, holderDID: string, orgName: string, city: string) {
  const res = await axios.post(`${NUTS_INTERNAL}/internal/vcr/v2/issuer/vc`, {
    '@context': 'https://nuts.nl/credentials/v1',
    type: 'NutsOrganizationCredential',
    issuer: issuerDID,
    credentialSubject: {
      id: holderDID,
      organization: { name: orgName, city },
    },
    withStatusList2021Revocation: true,
  });
  return res.data;
}

// 4. Register on discovery service
async function activateService(serviceId: string, subjectId: string, endpoints: Record<string, string>) {
  const res = await axios.post(
    `${NUTS_INTERNAL}/internal/discovery/v1/${serviceId}/${subjectId}`,
    { registrationParameters: endpoints }
  );
  return res.status; // 200 or 202
}

// 5. Search for participants
async function searchDiscovery(serviceId: string, query: Record<string, string>) {
  const params = new URLSearchParams(query);
  const res = await axios.get(`${NUTS_INTERNAL}/internal/discovery/v1/${serviceId}?${params}`);
  return res.data; // SearchResult[]
}

// 6. Request access token
async function requestAccessToken(subjectId: string, authServer: string, scope: string) {
  const res = await axios.post(
    `${NUTS_INTERNAL}/internal/auth/v2/${subjectId}/request-service-access-token`,
    {
      authorization_server: authServer,
      scope,
      token_type: 'Bearer',
    }
  );
  return res.data; // { access_token, token_type, expires_in }
}

// 7. Introspect incoming token (resource server side)
async function introspectToken(token: string) {
  const res = await axios.post(
    `${NUTS_INTERNAL}/internal/auth/v2/accesstoken/introspect`,
    `token=${encodeURIComponent(token)}`,
    { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
  );
  return res.data; // { active, iss, client_id, scope, organization_name, ... }
}
```

---

## Key Links

| Resource | URL |
|---|---|
| ReadTheDocs (stable) | https://nuts-node.readthedocs.io/en/stable/ |
| Wiki | https://wiki.nuts.nl |
| GitHub | https://github.com/nuts-foundation/nuts-node |
| API Specs (interactive) | https://nuts-node.readthedocs.io/en/stable/pages/integrating/api.html |
| Docker Hub | https://hub.docker.com/r/nutsfoundation/nuts-node |
| Slack Community | https://join.slack.com/t/nuts-foundation/ |
| Nuts Specifications | https://nuts-foundation.gitbook.io |
