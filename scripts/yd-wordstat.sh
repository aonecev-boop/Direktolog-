#!/usr/bin/env bash
# yd-wordstat.sh — Wordstat API wrapper (Yandex Cloud Search API, on-demand only)
# NOT part of the automatic /direct audit flow — call manually for keyword
# research. Separate credentials/billing from Direct and Metrika (Yandex Cloud
# API key, not OAuth).
#
# Region is hardcoded to 1 (Москва и МО) by default — that's this account's
# actual targeting region (same RegionIds value used on live ad groups), so
# every call defaults to it instead of requiring it to be re-derived each time.
#
# RATE LIMIT: this API key is capped at 100 requests/hour
# (search-api.wordstatRequestsPerHour.rate). Bulk keyword sweeps (e.g. "run
# Wordstat over every keyword in the account") must be batched at ≤100
# calls/hour — do not fire more in a loop expecting them to succeed, they
# will fail with error code 8 "rate quota limit exceed" and silently waste
# the phrases past #100 until the hour rolls over.
#
# Usage:
#   ./yd-wordstat.sh top <phrase> [num_phrases]
#       Top related search phrases + volume for a phrase (default num=20).
#   ./yd-wordstat.sh region <phrase>
#       Regional search-volume distribution for a phrase. Prints the
#       Москва и МО (region 1) figure first, then the overall top-10 regions
#       for context.
#   ./yd-wordstat.sh raw <method> <json_body>
#       Escape hatch: arbitrary POST to
#       searchapi.api.cloud.yandex.net/v2/wordstat/<method>
#
# Examples:
#   ./yd-wordstat.sh top "шкаф-купе на заказ" 20
#   ./yd-wordstat.sh region "гардеробная на заказ"

set -euo pipefail

SECRETS_FILE="${HOME}/.secrets/yandex-search-api.json"
API_BASE="https://searchapi.api.cloud.yandex.net/v2/wordstat"
OUR_REGION_ID="1"   # Москва и МО — этот аккаунт таргетируется только сюда

if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "ERROR: Credentials not found at $SECRETS_FILE" >&2
    exit 1
fi

API_KEY=$(jq -r '.api_key' "$SECRETS_FILE")

if [[ -z "$API_KEY" || "$API_KEY" == "null" ]]; then
    echo "ERROR: api_key not found in $SECRETS_FILE" >&2
    exit 1
fi

CMD="${1:?Usage: yd-wordstat.sh <top|region|raw> [args...]}"

case "$CMD" in
    top)
        PHRASE="${2:?Usage: yd-wordstat.sh top <phrase> [num_phrases]}"
        NUM="${3:-20}"
        curl -s -X POST "${API_BASE}/topRequests" \
            -H "Authorization: Api-Key ${API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg p "$PHRASE" --argjson n "$NUM" '{phrase: $p, numPhrases: $n}')" \
            | jq '.'
        ;;
    region)
        PHRASE="${2:?Usage: yd-wordstat.sh region <phrase>}"
        RESPONSE=$(curl -s -X POST "${API_BASE}/regions" \
            -H "Authorization: Api-Key ${API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg p "$PHRASE" '{phrase: $p}')")

        if echo "$RESPONSE" | jq -e '.code' > /dev/null 2>&1; then
            echo "API ERROR:" >&2
            echo "$RESPONSE" | jq '.' >&2
            exit 1
        fi

        echo "$RESPONSE" | jq --arg r "$OUR_REGION_ID" '
            {
                "Москва и МО (наш регион, код 1)": (.results[] | select(.region == $r)),
                "Топ-10 регионов (для контекста)": (.results | sort_by(-(.count | tonumber)) | .[0:10])
            }'
        ;;
    raw)
        METHOD="${2:?Usage: yd-wordstat.sh raw <method> <json_body>}"
        BODY="${3:-\{\}}"
        curl -s -X POST "${API_BASE}/${METHOD}" \
            -H "Authorization: Api-Key ${API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$BODY" \
            | jq '.'
        ;;
    *)
        echo "ERROR: Unknown command '$CMD'. Use: top, region, raw" >&2
        exit 1
        ;;
esac
