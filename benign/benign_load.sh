#!/usr/bin/env bash
# Step 11: False-positive observation.
# Sends a burst of ordinary requests (home page, product list, normal
# searches) through the WAF after policy tuning. If every response is 200,
# no false-positive-like blocking was observed for this workload.
#
# Usage: ./benign_load.sh [rounds]   (default 20)
# Output: results/benign_load.csv  (round,request,status,time_total)

set -u

TARGET="${TARGET:-http://juice.lab}"
ROUNDS="${1:-20}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
OUT="$RESULTS_DIR/benign_load.csv"
mkdir -p "$RESULTS_DIR"

REQUESTS=(
  "/"
  "/api/Products"
  "/rest/products/search?q=apple"
  "/rest/products/search?q=juice"
  "/rest/products/search?q=banana"
)

echo "round,request,status,time_total" > "$OUT"
for ((i = 1; i <= ROUNDS; i++)); do
  for path in "${REQUESTS[@]}"; do
    result=$(curl -s -o /dev/null -w '%{http_code},%{time_total}' --max-time 10 "$TARGET$path")
    echo "$i,$path,$result" >> "$OUT"
  done
done

total=$(($(wc -l < "$OUT") - 1))
blocked=$(awk -F, 'NR > 1 && $3 == 403' "$OUT" | wc -l)
non200=$(awk -F, 'NR > 1 && $3 != 200' "$OUT" | wc -l)
echo "[+] $total requests sent, $blocked blocked (403), $non200 non-200"
echo "[+] Wrote $(cd "$RESULTS_DIR" && pwd)/benign_load.csv"
