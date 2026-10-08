#!/usr/bin/env python3
"""Grading Check 1: verifies that the benign workflow completed and that
legitimate requests were not incorrectly blocked by the WAF."""
import csv
import sys
from pathlib import Path

RESULT = Path(__file__).resolve().parent.parent / "results/benign_results.csv"
STATUS_KEYS = ["status", "http_code", "code", "response_code", "http status"]


def get_status(row):
    lower = {str(k).strip().lower(): str(v).strip() for k, v in row.items()}
    for key in STATUS_KEYS:
        if key in lower and lower[key].isdigit():
            return int(lower[key])
    for v in lower.values():
        if v.isdigit() and len(v) == 3:
            return int(v)
    return None


if not RESULT.exists():
    print("FAIL: ../results/benign_results.csv not found")
    sys.exit(1)

rows = list(csv.DictReader(RESULT.open()))
if not rows:
    print("FAIL: benign_results.csv is empty")
    sys.exit(1)

statuses = [get_status(r) for r in rows]
statuses = [s for s in statuses if s is not None]

if not statuses:
    print("FAIL: no HTTP status codes found in benign_results.csv")
    sys.exit(1)

blocked = sum(1 for s in statuses if s == 403)
if blocked == 0:
    print(f"PASS: benign workflow completed ({len(statuses)} requests, 0 blocked)")
    sys.exit(0)
else:
    print(f"FAIL: {blocked} benign requests were blocked")
    sys.exit(1)
