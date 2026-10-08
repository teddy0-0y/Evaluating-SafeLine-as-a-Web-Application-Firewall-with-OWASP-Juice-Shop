#!/usr/bin/env bash
# Step 6: Basic OWASP Top 10 attack testing.
# Sends four common attack payloads to the same Juice Shop search endpoint
# (/rest/products/search?q=) through the SafeLine WAF and records the HTTP
# status code returned for each one.
#
#   403 = blocked by SafeLine
#   401 = reached Juice Shop, authentication failed
#   200 = reached Juice Shop, returned normally

set -u

TARGET="${TARGET:-http://juice.lab}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
OUT="$RESULTS_DIR/attack_results.csv"
mkdir -p "$RESULTS_DIR"

declare -A PAYLOADS=(
  [pathtrav]='../../../../etc/passwd'
  [cmdinj]=';id;'
  [sqli]='1 and 1=2 union select 1'
  [xss]='<img src=x onerror=alert(1)>'
)
ORDER=(pathtrav cmdinj sqli xss)

echo "attack,code" > "$OUT"
for attack in "${ORDER[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -G \
    --data-urlencode "q=${PAYLOADS[$attack]}" \
    "$TARGET/rest/products/search")
  echo "$attack,$code"
  echo "$attack,$code" >> "$OUT"
done

echo "[+] Wrote to $(cd "$RESULTS_DIR" && pwd)/attack_results.csv"
