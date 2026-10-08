#!/usr/bin/env python3
"""Grading Check 2: verifies that the basic attack suite was run and the
expected blocking behavior was observed for common attacks."""
import csv
import sys
from pathlib import Path

RESULT = Path(__file__).resolve().parent.parent / "results/attack_results.csv"


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


if not RESULT.exists():
    fail("../results/attack_results.csv not found")

with RESULT.open(newline="") as f:
    rows = list(csv.DictReader(f))

if not rows:
    fail("attack_results.csv is empty")

required_attacks = {"sqli", "xss", "pathtrav", "cmdinj"}
seen = {k: False for k in required_attacks}

status_ok = {
    "sqli": False,
    "xss": False,
    "pathtrav": False,
    "cmdinj": False,
}

for row in rows:
    attack = row.get("attack", "").strip().lower()
    code = row.get("code", "").strip()

    if attack in seen:
        seen[attack] = True

        if attack in {"sqli", "xss", "pathtrav"} and code == "403":
            status_ok[attack] = True

        elif attack == "cmdinj" and code in {"200", "403"}:
            status_ok[attack] = True

missing = [a for a in required_attacks if not seen[a]]
bad_status = [a for a in required_attacks if not status_ok[a]]

if not missing and not bad_status:
    print("PASS: basic attack suite completed and expected results recorded")
    sys.exit(0)

print("FAIL: missing expected basic attack results")
for a in sorted(required_attacks):
    print(f"  {a}: seen={seen[a]}, status_ok={status_ok[a]}")
sys.exit(1)
