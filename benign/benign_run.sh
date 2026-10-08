#!/usr/bin/env bash
# Step 3: Benign user workflow.
# Replays a normal Juice Shop session through the WAF (home page, product
# search, login, basket, order history) and records each HTTP status code.
# None of these legitimate requests should be blocked (403).
#
# Prerequisite: the account below was registered and one order placed
# through the browser (see docs/LAB_GUIDE.md, Step 3).
#
# Output: results/benign_results.csv  (step,method,url,status)

set -u

TARGET="${TARGET:-http://juice.lab}"
EMAIL="${JUICE_EMAIL:-student@gmail.com}"
PASSWORD="${JUICE_PASSWORD:-tartans}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
OUT="$RESULTS_DIR/benign_results.csv"
mkdir -p "$RESULTS_DIR"

echo "step,method,url,status" > "$OUT"

req() {
  # $1 = step name, $2 = method, $3 = url, rest = extra curl args
  local step="$1" method="$2" url="$3"; shift 3
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X "$method" "$@" "$url")
  echo "$step,$method,$url,$code" >> "$OUT"
  printf '%-14s %-5s %s -> %s\n' "$step" "$method" "$url" "$code"
}

req homepage GET "$TARGET/"
req search   GET "$TARGET/rest/products/search?q=apple"
req products GET "$TARGET/api/Products"

# Log in and capture the auth token and basket id.
LOGIN_JSON=$(curl -s --max-time 10 -X POST -H 'Content-Type: application/json' \
  --data-raw "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  -w '\n%{http_code}' "$TARGET/rest/user/login")
LOGIN_CODE=$(echo "$LOGIN_JSON" | tail -n1)
LOGIN_BODY=$(echo "$LOGIN_JSON" | sed '$d')
echo "login,POST,$TARGET/rest/user/login,$LOGIN_CODE" >> "$OUT"
printf '%-14s %-5s %s -> %s\n' login POST "$TARGET/rest/user/login" "$LOGIN_CODE"

TOKEN=$(echo "$LOGIN_BODY" | python3 -c 'import sys,json; print(json.load(sys.stdin)["authentication"]["token"])' 2>/dev/null || true)
BID=$(echo "$LOGIN_BODY" | python3 -c 'import sys,json; print(json.load(sys.stdin)["authentication"]["bid"])' 2>/dev/null || true)

if [ -n "$TOKEN" ]; then
  AUTH=(-H "Authorization: Bearer $TOKEN")
  req whoami        GET "$TARGET/rest/user/whoami" "${AUTH[@]}"
  [ -n "$BID" ] && req basket GET "$TARGET/rest/basket/$BID" "${AUTH[@]}"
  req order_history GET "$TARGET/rest/order-history" "${AUTH[@]}"
else
  echo "[!] Login failed - did you register $EMAIL in Step 3?" >&2
fi

echo "[+] Wrote $(cd "$RESULTS_DIR" && pwd)/benign_results.csv"
