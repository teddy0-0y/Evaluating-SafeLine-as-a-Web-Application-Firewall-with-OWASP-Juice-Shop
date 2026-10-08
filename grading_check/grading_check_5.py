#!/usr/bin/env python3
"""Grading Check 5: verifies that response times were measured before and
after tuning to observe performance overhead."""
import csv
import sys
from pathlib import Path

BEFORE = Path("../results/perf_before_tuning.csv")
AFTER = Path("../results/perf_after_tuning.csv")


def extract_numbers(path):
    nums = []
    rows = list(csv.DictReader(path.open()))
    for row in rows:
        for key in ["time_total", "latency", "response_time", "time"]:
            if key in row and row[key]:
                try:
                    nums.append(float(row[key]))
                    break
                except ValueError:
                    pass
    return nums


for path in [BEFORE, AFTER]:
    if not path.exists():
        print(f"FAIL: {path} not found")
        sys.exit(1)

before = extract_numbers(BEFORE)
after = extract_numbers(AFTER)

if len(before) < 3 or len(after) < 3:
    print("FAIL: need at least 3 timing samples in each performance file")
    sys.exit(1)

avg_before = sum(before) / len(before)
avg_after = sum(after) / len(after)
delta = avg_after - avg_before

print("PASS: performance measurement completed")
print(f"  avg_before={avg_before:.4f}s")
print(f"  avg_after={avg_after:.4f}s")
print(f"  delta={delta:.4f}s")
