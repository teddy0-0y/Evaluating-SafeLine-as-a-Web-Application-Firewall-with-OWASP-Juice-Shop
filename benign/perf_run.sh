#!/usr/bin/env bash
# Step 8 / Step 11: Performance measurement.
# Requests a URL N times and records curl's total response time per request.
#
# Usage: ./benign/perf_run.sh <url> <count> <output.csv>
#   e.g. ./benign/perf_run.sh http://juice.lab/ 20 results/perf_before_tuning.csv
#
# Output columns: run,time_total

set -u

if [ $# -ne 3 ]; then
  echo "Usage: $0 <url> <count> <output.csv>" >&2
  exit 1
fi

URL="$1"
COUNT="$2"
OUT="$3"
mkdir -p "$(dirname "$OUT")"

echo "run,time_total" > "$OUT"
for ((i = 1; i <= COUNT; i++)); do
  t=$(curl -s -o /dev/null -w '%{time_total}' --max-time 10 "$URL")
  echo "$i,$t" >> "$OUT"
done

avg=$(awk -F, 'NR > 1 { s += $2; n++ } END { if (n) printf "%.4f", s / n }' "$OUT")
echo "[+] $COUNT requests to $URL, average time_total=${avg}s"
echo "[+] Wrote $OUT"
