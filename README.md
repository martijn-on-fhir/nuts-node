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

Wait a few seconds for initial setup, then verify:

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
4. Registers the organization on the `local-dev` discovery service

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
curl "http://localhost:8081/internal/discovery/v1/local-dev?organization_name=*"
```

## APIs

The Nuts Node exposes these internal APIs on port 8081:

| Module | Endpoint | Purpose |
|--------|----------|---------|
| **VDR** | `/internal/vdr/v2` | Subject & DID management |
| **VCR** | `/internal/vcr/v2` | Credential issuance, search, wallet, revocation |
| **Auth** | `/internal/auth/v2` | Access token generation & introspection |
| **Discovery** | `/internal/discovery/v1` | Service registration & participant search |

### Example: Create a subject with a DID

```bash
curl -X POST http://localhost:8081/internal/vdr/v2/subject \
  -H "Content-Type: application/json" \
  -d '{"subject": "my-organization"}'
```

This returns a `did:web` document with key material managed by the node.

## Configuration

### Nuts Node (`config/nuts.yaml`)

The Nuts Node is configured via `config/nuts.yaml`, mounted read-only into the container:

| Setting | Value | Description |
|---------|-------|-------------|
| `strictmode` | `false` | Relaxed validation for development |
| `url` | `http://localhost:8080` | Public URL of the node |
| `didmethods` | `[web]` | Enabled DID methods |
| `http.internal.address` | `:8081` | Internal API listen address |
| `verbosity` | `debug` | Log level |
| `datadir` | `/nuts/data` | Persistent data directory |

### Additional Configuration Directories

- **`config/discovery/`** — Discovery service definition JSON files. These define what credentials are required for service registration and map search parameters to credential fields.
- **`config/policy/`** — Policy definition JSON files. These map OAuth2 scopes to presentation definitions, determining which credentials are needed for access token requests.

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

## Resources

- [Nuts Node Documentation](https://nuts-node.readthedocs.io/en/stable/)
- [Nuts Foundation](https://nuts.nl)
- [Nuts Node GitHub](https://github.com/nuts-foundation/nuts-node)
- [Nuts Community Wiki](https://wiki.nuts.nl)
