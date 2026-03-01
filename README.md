# Nuts Node (Local Development)

A Docker-based local development setup for the [Nuts Node](https://github.com/nuts-foundation/nuts-node) — a decentralized identity network node for healthcare, built on W3C Self-Sovereign Identity (SSI) standards.

## What is Nuts?

[Nuts](https://nuts.nl) is an open-source infrastructure for decentralized healthcare identity and data exchange in the Netherlands. A Nuts Node enables organizations to:

- **Create and manage decentralized identities** (DIDs) for organizations
- **Issue and verify credentials** (Verifiable Credentials) that prove organizational attributes
- **Exchange access tokens** using OAuth2 flows backed by verifiable presentations
- **Discover other participants** in the network through a distributed discovery protocol

## Quick Start

### Prerequisites

- [Docker](https://www.docker.com/) and Docker Compose

### Start the Nuts Node

```bash
docker compose up -d
```

This starts the Nuts Node container with:
- **Port 8080** — Public HTTP interface (OAuth2, DID resolution)
- **Port 8081** — Internal HTTP interface (management APIs)

The first startup takes ~40 seconds while IRMA schemas are downloaded. Verify the node is ready:

```bash
# Health check
curl http://localhost:8081/health

# Node diagnostics
curl http://localhost:8081/status/diagnostics
```

### First-Time Initialization

After the node is healthy, run the init script to create an organization identity and register it on the local discovery service:

```bash
docker compose --profile init up init-node
```

This runs a one-shot container that:
1. Waits for the Nuts Node to be healthy
2. Creates a subject (`dev-organization`) with a `did:web` DID
3. Issues a `NutsOrganizationCredential` (self-issued, with org name and city)
4. Loads the credential into the holder's wallet
5. Registers the organization on the `local-dev` discovery service

The script is **idempotent** — it skips subject creation if `dev-organization` already exists.

#### Customizing the Organization

Set environment variables to override the default org name and city:

```bash
ORG_NAME="My Hospital" ORG_CITY="Rotterdam" docker compose --profile init up init-node
```

#### Verifying Initialization

```bash
# List subjects — should show "dev-organization"
curl http://localhost:8081/internal/vdr/v2/subject

# Search discovery — should return the registered organization
curl http://localhost:8081/internal/discovery/v1/local-dev
```

---

## API Reference

All management APIs are on the internal interface (port 8081). The base URL for all examples below is `http://localhost:8081`.

| Module | Endpoint | Purpose |
|--------|----------|---------|
| **VDR** | `/internal/vdr/v2` | Subject & DID management |
| **VCR** | `/internal/vcr/v2` | Credential issuance, search, wallet, revocation |
| **Auth** | `/internal/auth/v2` | Access token generation & introspection |
| **Discovery** | `/internal/discovery/v1` | Service registration & participant search |
| **Monitoring** | `/health`, `/status/diagnostics` | Health & diagnostics |

---

## Feature Usage

### 1. Subject & DID Management

A **subject** represents an organization. Each subject gets one or more DIDs (one per enabled DID method). In this setup, each subject gets a `did:web` DID.

#### Create a Subject

```bash
curl -X POST http://localhost:8081/internal/vdr/v2/subject \
  -H "Content-Type: application/json" \
  -d '{"subject": "my-organization"}'
```

Response includes the DID document(s) created for the subject.

#### List All Subjects

```bash
curl http://localhost:8081/internal/vdr/v2/subject
```

Returns a map of subject IDs to their DIDs:
```json
{
  "dev-organization": ["did:web:localhost%3A8080:iam:69d4a4ca-..."],
  "my-organization": ["did:web:localhost%3A8080:iam:abc12345-..."]
}
```

#### Get DIDs for a Subject

```bash
curl http://localhost:8081/internal/vdr/v2/subject/my-organization
```

Returns an array of DID strings for that subject.

#### Deactivate a Subject

```bash
curl -X DELETE http://localhost:8081/internal/vdr/v2/subject/my-organization
```

This deactivates all DIDs associated with the subject.

---

### 2. Verifiable Credentials

Verifiable Credentials (VCs) are signed attestations about a subject. The main credential type in the Nuts ecosystem is `NutsOrganizationCredential` (org name + city).

#### Issue a Credential

Issue a `NutsOrganizationCredential` from a subject's DID:

```bash
# First, get the DID for your subject
DID=$(curl -s http://localhost:8081/internal/vdr/v2/subject/dev-organization | sed 's/.*"\(did:[^"]*\)".*/\1/')

# Issue the credential
curl -X POST http://localhost:8081/internal/vcr/v2/issuer/vc \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"NutsOrganizationCredential\",
    \"issuer\": \"${DID}\",
    \"credentialSubject\": {
      \"id\": \"${DID}\",
      \"organization\": {
        \"name\": \"My Hospital\",
        \"city\": \"Amsterdam\"
      }
    },
    \"withStatusList2021Revocation\": false
  }"
```

**Notes:**
- `issuer` must be a DID managed by this node
- `credentialSubject.id` is the holder's DID (same DID for self-issued credentials)
- `withStatusList2021Revocation: true` enables revocation support
- The `visibility` option is only supported for `did:nuts`, not `did:web`

#### Load a Credential into the Wallet

Issued credentials are **not** automatically loaded into the holder's wallet. You must explicitly load them:

```bash
# Issue and capture the credential
CREDENTIAL=$(curl -s -X POST http://localhost:8081/internal/vcr/v2/issuer/vc \
  -H "Content-Type: application/json" \
  -d '{ ... }')

# Load it into the holder's wallet (use subject ID, not DID)
curl -X POST http://localhost:8081/internal/vcr/v2/holder/dev-organization/vc \
  -H "Content-Type: application/json" \
  -d "${CREDENTIAL}"
```

#### List Credentials in a Wallet

```bash
curl http://localhost:8081/internal/vcr/v2/holder/dev-organization/vc
```

Returns an array of all VCs in the subject's wallet.

#### Search Credentials (JSON-LD)

Search for credentials across all wallets using JSON-LD queries:

```bash
curl -X POST http://localhost:8081/internal/vcr/v2/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": {
      "@context": [
        "https://www.w3.org/2018/credentials/v1",
        "https://nuts.nl/credentials/v1"
      ],
      "type": ["VerifiableCredential", "NutsOrganizationCredential"],
      "credentialSubject": {
        "organization": {
          "name": "My Hospital"
        }
      }
    }
  }'
```

**Note:** The `@context` and `type` fields are required for JSON-LD resolution but are not used as search filters. Add `credentialSubject` fields to filter results.

#### Revoke a Credential

Revoke a credential by its ID (only works if issued with `withStatusList2021Revocation: true`):

```bash
curl -X DELETE "http://localhost:8081/internal/vcr/v2/issuer/vc/{vcID}"
```

Replace `{vcID}` with the credential's `id` field (URL-encoded).

---

### 3. Discovery Service

The discovery service lets organizations register themselves so others can find them. This setup includes a `local-dev` discovery service that requires a `NutsOrganizationCredential`.

#### Register on a Discovery Service

Register a subject on the local discovery service. The subject's wallet must contain a matching credential first:

```bash
curl -X POST http://localhost:8081/internal/discovery/v1/local-dev/dev-organization \
  -H "Content-Type: application/json"
```

**Responses:**
- `200 OK` — immediately registered
- `202 Accepted` — queued, will retry in background
- `412 Precondition Failed` — missing credentials in wallet

You can optionally include registration parameters (e.g., FHIR endpoint URL):

```bash
curl -X POST http://localhost:8081/internal/discovery/v1/local-dev/dev-organization \
  -H "Content-Type: application/json" \
  -d '{
    "registrationParameters": {
      "fhir": "https://api.example.com/fhir"
    }
  }'
```

#### Search the Discovery Service

List all registered participants:

```bash
curl http://localhost:8081/internal/discovery/v1/local-dev
```

Response:
```json
[
  {
    "credential_subject_id": "did:web:localhost%3A8080:iam:69d4a4ca-...",
    "fields": {
      "organization_name": "Dev Organization",
      "organization_city": "Amsterdam"
    },
    "registrationParameters": {}
  }
]
```

The `fields` keys correspond to the `id` values defined in the discovery service definition's input descriptor constraints.

#### Deactivate a Discovery Registration

```bash
curl -X DELETE http://localhost:8081/internal/discovery/v1/local-dev/dev-organization
```

---

### 4. Access Tokens (OAuth2)

The Nuts Node implements OAuth2 flows backed by Verifiable Presentations. Use these to securely call remote APIs.

#### Request a Service Access Token

Request an access token to call another organization's API:

```bash
curl -X POST http://localhost:8081/internal/auth/v2/dev-organization/request-service-access-token \
  -H "Content-Type: application/json" \
  -d '{
    "authorization_server": "https://other-node.example.com/oauth2/their-subject",
    "scope": "local-dev",
    "token_type": "Bearer"
  }'
```

**Parameters:**
- `authorization_server` — The other party's OAuth2 server URL (found via discovery's `authServerURL`)
- `scope` — The access scope (must match a policy definition on the remote node)
- `token_type` — `Bearer` (simple) or `DPoP` (proof-of-possession, more secure)

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI...",
  "token_type": "Bearer",
  "expires_in": 900
}
```

#### Include User Credentials

For flows that require user identity (e.g., `NutsEmployeeCredential`):

```bash
curl -X POST http://localhost:8081/internal/auth/v2/dev-organization/request-service-access-token \
  -H "Content-Type: application/json" \
  -d '{
    "authorization_server": "https://other-node.example.com/oauth2/their-subject",
    "scope": "local-dev",
    "token_type": "Bearer",
    "credentials": [
      {
        "@context": ["https://www.w3.org/2018/credentials/v1", "https://nuts.nl/credentials/v1"],
        "type": ["VerifiableCredential", "NutsEmployeeCredential"],
        "credentialSubject": {
          "name": "John Doe",
          "roleName": "Nurse",
          "identifier": "123456"
        }
      }
    ]
  }'
```

#### Introspect an Incoming Access Token

When your application receives a request with an access token, validate it:

```bash
curl -X POST http://localhost:8081/internal/auth/v2/accesstoken/introspect \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "token=eyJhbGciOiJSUzI..."
```

**Response:**
```json
{
  "active": true,
  "iss": "https://other-node.example.com/oauth2/their-subject",
  "client_id": "https://localhost:8080/oauth2/dev-organization",
  "scope": "local-dev",
  "organization_name": "Other Hospital"
}
```

Use the introspection response fields for authorization decisions in your application.

---

### 5. Trust Management

Before credentials from external issuers can be used, you must explicitly trust them.

#### Trust an Issuer

```bash
curl -X POST http://localhost:8081/internal/vcr/v2/verifier/trust \
  -H "Content-Type: application/json" \
  -d '{
    "issuer": "did:web:other-node.example.com:iam:their-subject",
    "credentialType": "NutsOrganizationCredential"
  }'
```

#### List Untrusted Issuers

```bash
curl http://localhost:8081/internal/vcr/v2/verifier/NutsOrganizationCredential/untrusted
```

#### Remove Trust

```bash
curl -X DELETE http://localhost:8081/internal/vcr/v2/verifier/trust \
  -H "Content-Type: application/json" \
  -d '{
    "issuer": "did:web:other-node.example.com:iam:their-subject",
    "credentialType": "NutsOrganizationCredential"
  }'
```

**Note:** Self-issued credentials (where the issuer and holder are the same DID) are automatically trusted. Trust management is only needed for credentials issued by external parties.

---

## Configuration

### Nuts Node (`config/nuts.yaml`)

The Nuts Node is configured via `config/nuts.yaml`, mounted read-only into the container:

| Setting | Value | Description |
|---------|-------|-------------|
| `strictmode` | `false` | Relaxed validation for development |
| `url` | `http://localhost:8080` | Public URL of the node |
| `didmethods` | `[web]` | Enabled DID methods |
| `http.public.address` | `:8080` | Public HTTP listen address |
| `http.internal.address` | `:8081` | Internal API listen address |
| `datadir` | `/nuts/data` | Persistent data directory |
| `verbosity` | `debug` | Log level |
| `crypto.storage` | `fs` | Key storage backend (filesystem) |
| `storage.sql.connection` | `sqlite:...` | Database connection string |
| `discovery.definitions.directory` | `/nuts/config/discovery` | Discovery definition files |
| `discovery.server.ids` | `[local-dev]` | Discovery services this node serves |
| `policy.directory` | `/nuts/config/policy` | Policy definition files |

### Discovery Definition (`config/discovery/local-dev.json`)

Defines the `local-dev` discovery service. Specifies what credentials are required for registration and which fields become searchable. The key parts are:

- **`presentation_definition`** — A [Presentation Exchange](https://identity.foundation/presentation-exchange/) definition that describes required credentials
- **`input_descriptors`** — Each descriptor maps credential fields (via JSONPath) to searchable fields (via `id`)
- **`format`** — Supported VC/VP proof formats (`ldp_vc` with `JsonWebSignature2020`, `jwt_vp` with `ES256`)

### Policy Definition (`config/policy/local-dev.json`)

Maps OAuth2 scopes to Presentation Definitions. When a remote party requests an access token with scope `local-dev`, the node checks that the caller presents credentials matching this policy.

---

## Project Structure

```
nuts-node/
├── config/
│   ├── nuts.yaml              # Nuts Node configuration
│   ├── discovery/
│   │   └── local-dev.json     # Discovery service definition
│   └── policy/
│       └── local-dev.json     # Policy definition
├── docs/
│   └── documentation.md       # Complete developer reference
├── scripts/
│   └── init-node.sh           # Post-startup initialization script
├── docker-compose.yml         # Nuts Node container setup
└── README.md
```

## Documentation

See [`docs/documentation.md`](docs/documentation.md) for the complete developer reference covering:

- Nuts Node concepts and architecture
- Full API reference with examples
- Integration workflow (step-by-step)
- Discovery and policy configuration
- OAuth2 / access token flows
- Verifiable credential lifecycle
- Production deployment and security

## Useful Commands

```bash
# Start the Nuts Node
docker compose up -d

# Initialize the node (first-time setup)
docker compose --profile init up init-node

# View Nuts Node logs
docker compose logs -f

# Stop the Nuts Node
docker compose down

# Stop and remove all data (clean slate)
docker compose down -v
```

## Troubleshooting

### Node fails to start with "permission denied"

The container needs write access to the data volume. This setup uses `user: root` for simplicity. If you see permission errors, run `docker compose down -v` to recreate the volume.

### Healthcheck fails / node takes long to start

The first startup downloads IRMA schemas (~40 seconds). The healthcheck `start_period` is set to 30 seconds. If your network is slow, increase it in `docker-compose.yml`.

### "missing credentials" on discovery registration

The credential must be in the holder's wallet before registering on a discovery service. After issuing a credential, explicitly load it into the wallet:

```bash
curl -X POST http://localhost:8081/internal/vcr/v2/holder/{subject}/vc \
  -H "Content-Type: application/json" \
  -d '{ ... credential JSON ... }'
```

### VC search returns no results

- For JSON-LD search (`/internal/vcr/v2/search`): Ensure `@context` and `type` are included in the query
- For credentials from external issuers: Ensure the issuer is trusted via `/internal/vcr/v2/verifier/trust`

### Discovery registration returns 202

The node accepted the request but couldn't reach the discovery server yet. It will retry automatically. Check logs for details.

## Resources

- [Nuts Node Documentation](https://nuts-node.readthedocs.io/en/stable/)
- [Nuts Foundation](https://nuts.nl)
- [Nuts Node GitHub](https://github.com/nuts-foundation/nuts-node)
- [Nuts Community Wiki](https://wiki.nuts.nl)
