#!/bin/sh
set -e

NUTS_INTERNAL="http://nuts-node:8081"
SUBJECT="dev-organization"
ORG_NAME="${ORG_NAME:-Dev Organization}"
ORG_CITY="${ORG_CITY:-Amsterdam}"

echo "==> Waiting for Nuts Node to be healthy..."
until curl -sf "${NUTS_INTERNAL}/health" > /dev/null 2>&1; do
  echo "    Node not ready yet, retrying in 2s..."
  sleep 2
done
echo "==> Nuts Node is healthy."

# Step 1: Create subject (idempotent — skip if already exists)
echo "==> Checking if subject '${SUBJECT}' exists..."
EXISTING=$(curl -sf "${NUTS_INTERNAL}/internal/vdr/v2/subject" 2>/dev/null || echo "[]")

if echo "${EXISTING}" | grep -q "\"${SUBJECT}\""; then
  echo "    Subject '${SUBJECT}' already exists, skipping creation."
else
  echo "==> Creating subject '${SUBJECT}'..."
  curl -sf -X POST "${NUTS_INTERNAL}/internal/vdr/v2/subject" \
    -H "Content-Type: application/json" \
    -d "{\"subject\": \"${SUBJECT}\"}"
  echo ""
  echo "    Subject created."
fi

# Step 2: Get the DID for the subject
echo "==> Retrieving DID for subject '${SUBJECT}'..."
DIDS=$(curl -sf "${NUTS_INTERNAL}/internal/vdr/v2/subject/${SUBJECT}")
DID=$(echo "${DIDS}" | sed 's/.*"\(did:[^"]*\)".*/\1/')
echo "    DID: ${DID}"

# Step 3: Issue a NutsOrganizationCredential
echo "==> Issuing NutsOrganizationCredential..."
CREDENTIAL=$(curl -sf -X POST "${NUTS_INTERNAL}/internal/vcr/v2/issuer/vc" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"NutsOrganizationCredential\",
    \"issuer\": \"${DID}\",
    \"credentialSubject\": {
      \"id\": \"${DID}\",
      \"organization\": {
        \"name\": \"${ORG_NAME}\",
        \"city\": \"${ORG_CITY}\"
      }
    },
    \"visibility\": \"public\",
    \"withStatusList2021Revocation\": false
  }")
echo "    Credential issued."

# Step 4: Register on the local discovery service
echo "==> Registering on discovery service 'local-dev'..."
curl -sf -X POST "${NUTS_INTERNAL}/internal/discovery/v1/local-dev/${DID}" \
  -H "Content-Type: application/json"
echo ""
echo "    Registered on discovery service."

echo ""
echo "==> Initialization complete!"
echo "    Subject: ${SUBJECT}"
echo "    DID:     ${DID}"
echo "    Org:     ${ORG_NAME} (${ORG_CITY})"
