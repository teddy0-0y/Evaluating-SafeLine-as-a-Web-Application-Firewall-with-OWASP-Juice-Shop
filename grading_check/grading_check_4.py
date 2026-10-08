#!/usr/bin/env python3
"""Grading Check 4: verifies that the post-tuning advanced attack results show
the expected blocking behavior for the $(id) and whoami payloads."""
import csv
import sys
from pathlib import Path

STATUS_KEYS = ["status", "http_code", "code", "response_code"]
NAME_KEYS = ["attack", "attack_type", "type", "name", "test", "label", "payload"]


def find_file(filename):
    candidates = [
        Path("../results") / filename,
        Path("./results") / filename,
        Path("results") / filename,
        Path(filename),
        Path.home() / "waf-lab" / "results" / filename,
        Path(__file__).resolve().parent.parent / "results" / filename,
        Path(__file__).resolve().parent / "results" / filename,
        Path(__file__).resolve().parent / filename,
    ]

    for path in candidates:
        p = path.expanduser().resolve()
        if p.exists():
            return p
    return None


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


def load_rows(path):
    return list(csv.DictReader(path.open()))


POST = find_file("advanced_post_tuning.csv")
if POST is None:
    print("FAIL: advanced_post_tuning.csv not found")
    sys.exit(1)
post_rows = load_rows(POST)
if not post_rows:
    print("FAIL: advanced_post_tuning.csv must not be empty")
    sys.exit(1)
id_blocked = False
whoami_blocked = False
for row in post_rows:
    name = get_name(row)
    status = get_status(row)
    if status == 403 and ("$(id)" in name or "%24%28id%29" in name):
        id_blocked = True
    if status == 403 and "whoami" in name:
        whoami_blocked = True

if id_blocked and whoami_blocked:
    print("PASS: post-tuning policy blocks the expected advanced attacks")
    print(f"  $(id) blocked: {id_blocked}")
    print(f"  whoami blocked: {whoami_blocked}")
    sys.exit(0)
else:
    print("FAIL: post-tuning policy check failed")
    print(f"  $(id) blocked: {id_blocked}")
    print(f"  whoami blocked: {whoami_blocked}")
    sys.exit(1)
