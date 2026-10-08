# Evaluating SafeLine as a Web Application Firewall with OWASP Juice Shop

**Team 1-800-RUNAWAY** — Yaqing Zhou, Yen-chu Chen, Leo Li

A hands-on lab that places [SafeLine](https://github.com/chaitin/SafeLine), an open-source self-hosted WAF, as a reverse proxy in front of the deliberately vulnerable [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/), then measures how well it blocks common web attacks, whether it interferes with normal users, and what latency it adds.

> ⚠️ **Lab use only.** Every script here targets an isolated lab network running an intentionally vulnerable application. Do not point them at systems you do not own or have permission to test. The credentials in this repo (`student` / `tartans`) are lab defaults, not real accounts.

## What the lab evaluates

| Dimension | Question |
|---|---|
| Attack detection & prevention | Does SafeLine block SQL injection, XSS, command injection and path traversal? |
| False-positive impact | Are legitimate actions (login, search, add to cart, checkout) incorrectly blocked? |
| Performance overhead | How much latency does the reverse proxy and stricter filtering add? |

## Topology

```
                    Virtual switch — 192.168.100.0/24
     ┌────────────────────┬────────────────────┬────────────────────┐
┌─────────────┐  HTTP ┌─────────────┐  HTTP ┌─────────────┐   ┌─────────────┐
│ VM1         │◀──────│ VM2         │◀──────│ VM3         │   │ VM4         │
│ Juice Shop  │       │ SafeLine WAF│       │ Kali client │   │ Monitoring  │
│ .10 :3000   │       │ .20 :80     │       │ .30         │   │ .40         │
└─────────────┘       └─────────────┘       └─────────────┘   └─────────────┘
```

| VM | Role | OS / Service | IP |
|---|---|---|---|
| VM1 | Web application server | Ubuntu 22.04 + OWASP Juice Shop | 192.168.100.10 |
| VM2 | SafeLine WAF (reverse proxy) | Ubuntu 22.04 + Docker + SafeLine | 192.168.100.20 |
| VM3 | Test client / attacker | Kali Linux | 192.168.100.30 |
| VM4 | Monitoring station | Ubuntu 22.04 + tcpdump / tshark | 192.168.100.40 |

`juice.lab` resolves to `192.168.100.20`. Traffic flows **VM3 → VM2 → VM1**; direct access from VM3 to VM1:3000 is blocked.

## Repository layout

```
.
├── attacks/
│   ├── test.sh               # Step 6  – basic attacks against one search endpoint
│   └── advanced_attack.sh    # Step 7/10 – per-attack endpoints (login & search APIs)
├── benign/
│   ├── benign_run.sh         # Step 3  – replays a normal user session
│   ├── benign_load.sh        # Step 11 – burst of benign traffic (false-positive check)
│   └── perf_run.sh           # Step 8/11 – response-time sampling
├── grading_check/
│   └── grading_check_1..5.py # verify each phase's results
├── results/                  # CSV output (git-ignored)
└── docs/
    └── LAB_GUIDE.md          # full step-by-step walkthrough
```

## Quick start (on VM3 / Kali)

```bash
git clone https://github.com/teddy0-0y/Evaluating-SafeLine-as-a-Web-Application-Firewall-with-OWASP-Juice-Shop.git ~/waf-lab
cd ~/waf-lab
chmod +x attacks/*.sh benign/*.sh

# make sure juice.lab points at the WAF
grep -q juice.lab /etc/hosts || echo "192.168.100.20 juice.lab" | sudo tee -a /etc/hosts
```

Then follow [`docs/LAB_GUIDE.md`](docs/LAB_GUIDE.md). In short:

| Phase | Run | Check |
|---|---|---|
| 1. Baseline | `./benign/benign_run.sh` | `grading_check_1.py` |
| 2. Default WAF | `./attacks/test.sh` | `grading_check_2.py` |
| | `./attacks/advanced_attack.sh` → copy to `advanced_pre_tuning.csv` | `grading_check_3.py` |
| | `./benign/perf_run.sh http://juice.lab/ 20 results/perf_before_tuning.csv` | |
| 3. Tuning | enable CMD Inj strict mode + `$(` deny rule, rerun advanced attacks → `advanced_post_tuning.csv` | `grading_check_4.py` |
| | `./benign/benign_load.sh`, `./benign/perf_run.sh … perf_after_tuning.csv` | `grading_check_5.py` |

Run the grading checks from inside `grading_check/` (check 5 uses relative paths):

```bash
cd grading_check && python3 grading_check_1.py
```

## Results summary

| Attack | Payload | Default policy | After tuning |
|---|---|---|---|
| SQL injection | `' or 1=1--` | 403 blocked | 403 blocked |
| XSS | `<img src=x onerror=alert(1)>` | 403 blocked | 403 blocked |
| Command injection | `;cat /etc/passwd` | 403 blocked | 403 blocked |
| Command substitution | `$(id)` | 401 passed WAF | 403 blocked (custom rule) |
| Pipe operator | `\| whoami` | 401 passed WAF (audited) | 403 blocked (strict mode) |

In the basic suite, `;id;` in the search query returned **200**: it reached Juice Shop but showed no evidence of command execution — the search API treats it as an ordinary string.

**Takeaways.** SafeLine blocks many common attacks out of the box, but default *balance* mode only audits some command-injection variants. Strict semantic analysis plus targeted custom rules closes the gap. Stronger filtering should always be re-checked for false positives and latency, and a WAF complements — never replaces — secure coding and input validation.

## References

1. Chaitin Tech, *SafeLine – Make your web apps secure*. https://github.com/chaitin/SafeLine
2. OWASP Foundation, *OWASP Juice Shop*. https://owasp.org/www-project-juice-shop/
3. OWASP Foundation, *OWASP Top 10:2025*. https://owasp.org/Top10/2025/
4. OWASP Foundation, *A05:2025 – Injection*. https://owasp.org/Top10/2025/A05_2025-Injection/
5. juice-shop/juice-shop, GitHub repository. https://github.com/juice-shop/juice-shop
6. Chaitin Tech, *Deploy SafeLine*. https://docs.waf.chaitin.com/en/GetStarted/Deploy
