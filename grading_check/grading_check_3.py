#!/usr/bin/env python3
"""Grading Check 3: verifies that the advanced attack baseline was collected
before applying any custom SafeLine rules."""
import csv
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
RESULT = BASE_DIR / "results" / "advanced_pre_tuning.csv"

STATUS_KEYS = ["status", "http_code", "code", "response_code"]
NAME_KEYS = ["attack", "attack_type", "type", "name", "test", "label", "payload"]


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


def get_status(row):
    lower = {str(k).strip().lower(): str(v).strip() for k, v in row.items()}

    for key in STATUS_KEYS:
        if key in lower and lower[key].isdigit():
            return int(lower[key])

    for v in lower.values():
        if v.isdigit() and len(v) == 3:
            return int(v)

    return None


def get_name(row):
    lower = {str(k).strip().lower(): str(v).strip() for k, v in row.items()}
    parts = []

    for key in NAME_KEYS:
        if key in lower and lower[key]:
            parts.append(lower[key].lower())

    for key, value in lower.items():
        if key not in NAME_KEYS and value:
            parts.append(value.lower())

    return " ".join(parts)


if not RESULT.exists():
    fail(f"{RESULT} not found")

rows = list(csv.DictReader(RESULT.open()))
if not rows:
    fail("advanced_pre_tuning.csv is empty")

blocked = 0
not_blocked = 0
id_variant_ok = False
whoami_variant_ok = False

for row in rows:
    name = get_name(row)
    status = get_status(row)

    if status == 403:
        blocked += 1
    elif status is not None:
        not_blocked += 1

    if status is not None and ("$(id)" in name or "%24%28id%29" in name) and status != 403:
        id_variant_ok = True

    if status is not None and "whoami" in name and status != 403:
        whoami_variant_ok = True

print(f"Using file: {RESULT}")

if blocked >= 1 and not_blocked >= 1 and id_variant_ok and whoami_variant_ok:
    print("PASS: advanced pre-tuning baseline collected")
    print(f"  blocked={blocked}, not_blocked={not_blocked}")
    sys.exit(0)
else:
    print("FAIL: advanced pre-tuning baseline does not match expected pattern")
    print(f"  blocked={blocked}, not_blocked={not_blocked}")
    print(f"  $(id) not blocked before tuning: {id_variant_ok}")
    print(f"  whoami not blocked before tuning: {whoami_variant_ok}")
    sys.exit(1)
