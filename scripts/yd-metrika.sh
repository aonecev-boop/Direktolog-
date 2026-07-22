#!/usr/bin/env bash
# yd-metrika.sh — Yandex Metrika Reporting/Management API wrapper (on-demand only)
# NOT part of the automatic /direct audit flow — call manually when a deeper
# analysis needs visits/goals data cross-referenced with Direct campaigns.
#
# Usage:
#   ./yd-metrika.sh counters
#       List available counters (id, name, site)
#   ./yd-metrika.sh stat <counter_id> [date_from] [date_to] [goal_id]
#       Visits/goal performance for a counter over a date range.
#       date_from/date_to default to last 30 days. goal_id optional
#       (adds goal reach/conversion metrics for that specific goal).
#   ./yd-metrika.sh raw <path> [query_string]
#       Escape hatch: arbitrary GET to api-metrika.yandex.net/<path>?<query_string>
#
# Examples:
#   ./yd-metrika.sh counters
#   ./yd-metrika.sh stat 45203580 2026-06-01 2026-06-30
#   ./yd-metrika.sh stat 45203580 2026-06-01 2026-06-30 123456

set -euo pipefail

SECRETS_FILE="${HOME}/.secrets/yandex-metrika.json"
API_BASE="https://api-metrika.yandex.net"

if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "ERROR: Credentials not found at $SECRETS_FILE" >&2
    exit 1
fi

OAUTH_TOKEN=$(jq -r '.oauth_token' "$SECRETS_FILE")

if [[ -z "$OAUTH_TOKEN" || "$OAUTH_TOKEN" == "null" ]]; then
    echo "ERROR: oauth_token not found in $SECRETS_FILE" >&2
    exit 1
fi

CMD="${1:?Usage: yd-metrika.sh <counters|stat|raw> [args...]}"

call_api() {
    local path="$1"
    local query="${2:-}"
    curl -s -G "${API_BASE}/${path}" \
        -H "Authorization: OAuth ${OAUTH_TOKEN}" \
        --data-urlencode "${query}"
}

case "$CMD" in
    counters)
        curl -s "${API_BASE}/management/v1/counters" \
            -H "Authorization: OAuth ${OAUTH_TOKEN}" \
            | jq '.counters[] | {id, name, site, status}'
        ;;
    stat)
        COUNTER_ID="${2:?Usage: yd-metrika.sh stat <counter_id> [date_from] [date_to] [goal_id]}"
        DATE_FROM="${3:-$(date -d '-30 days' +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d)}"
        DATE_TO="${4:-$(date +%Y-%m-%d)}"
        GOAL_ID="${5:-}"

        METRICS="ym:s:visits,ym:s:users,ym:s:pageviews,ym:s:bounceRate,ym:s:avgVisitDurationSeconds"
        if [[ -n "$GOAL_ID" ]]; then
            METRICS="${METRICS},ym:s:goal${GOAL_ID}reaches,ym:s:goal${GOAL_ID}conversionRate"
        fi

        RESPONSE=$(curl -s -G "${API_BASE}/stat/v1/data" \
            -H "Authorization: OAuth ${OAUTH_TOKEN}" \
            --data-urlencode "ids=${COUNTER_ID}" \
            --data-urlencode "metrics=${METRICS}" \
            --data-urlencode "date1=${DATE_FROM}" \
            --data-urlencode "date2=${DATE_TO}")

        if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
            echo "API ERROR:" >&2
            echo "$RESPONSE" | jq '.errors' >&2
            exit 1
        fi

        echo "$RESPONSE" | jq '.'
        ;;
    raw)
        PATH_ARG="${2:?Usage: yd-metrika.sh raw <path> [query_string]}"
        QUERY="${3:-}"
        call_api "$PATH_ARG" "$QUERY" | jq '.'
        ;;
    *)
        echo "ERROR: Unknown command '$CMD'. Use: counters, stat, raw" >&2
        exit 1
        ;;
esac
