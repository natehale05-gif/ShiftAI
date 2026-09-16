#!/usr/bin/env bash
# ShiftAI :: end-to-end check against a deployed (or locally running) project.
#
#   export SUPABASE_URL="https://<ref>.supabase.co"
#   export SUPABASE_ANON_KEY="..."
#   export USER_JWT="..."          # a signed-in user's access token
#   ./scripts/smoke-test.sh openai sk-...
set -euo pipefail

: "${SUPABASE_URL:?set SUPABASE_URL}"
: "${SUPABASE_ANON_KEY:?set SUPABASE_ANON_KEY}"
: "${USER_JWT:?set USER_JWT to the access token of a signed-in user}"

PROVIDER="${1:?usage: smoke-test.sh <provider> <api-key>}"
SECRET="${2:?usage: smoke-test.sh <provider> <api-key>}"
FN="$SUPABASE_URL/functions/v1"

auth=(-H "Authorization: Bearer $USER_JWT" -H "apikey: $SUPABASE_ANON_KEY" -H "content-type: application/json")

echo "==> storing $PROVIDER key"
curl -sS -X POST "$FN/keys" "${auth[@]}" \
  -d "{\"provider\":\"$PROVIDER\",\"secret\":\"$SECRET\"}" | tee /tmp/shiftai-store.json
echo

echo "==> listing keys (metadata only; no plaintext must appear)"
curl -sS "$FN/keys" "${auth[@]}"
echo

echo "==> confirming the key is NOT readable through the REST API"
if curl -sS "$SUPABASE_URL/rest/v1/ai_provider_keys?select=secret_id" \
     -H "Authorization: Bearer $USER_JWT" -H "apikey: $SUPABASE_ANON_KEY" \
   | grep -q "secret_id"; then
  echo "FAIL: secret_id was exposed to a client role" >&2
  exit 1
fi
echo "ok: secret_id is not reachable"

echo "==> proxying a completion"
curl -sS -X POST "$FN/ai-proxy" "${auth[@]}" \
  -d "{\"provider\":\"$PROVIDER\",\"model\":\"gpt-4o-mini\",\"payload\":{\"messages\":[{\"role\":\"user\",\"content\":\"reply with the word ok\"}]}}"
echo

echo "==> done"
