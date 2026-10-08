# Lab Guide

Full walkthrough of the SafeLine WAF evaluation. All client-side commands run on **vm3-kali** with this repository cloned to `~/waf-lab`.

Lab credentials for every VM: `student` / `tartans`.

---

## Phase 1 — Environment setup and baseline validation

### Step 1: Configure SafeLine (vm2-safeline)

SafeLine is already installed and running as a Docker service on VM2.

1. Log on to **vm2-safeline**.
2. Reset the SafeLine administrator password:
   ```bash
   sudo docker exec safeline-mgt resetadmin
   ```
   If prompted for a sudo password, enter `tartans`.
3. Record the `Initial password` printed by the command (it differs every time).
4. Open `https://192.168.100.20:9443/` in a browser on VM2 (accept the certificate warning).
5. Log in as `admin` with the password from step 3.
6. Go to **Applications → Add Application** and enter:

   | Field | Value |
   |---|---|
   | Domain | `juice.lab` |
   | Port | `80` (HTTP) — remove port `443` |
   | Mode | Reverse Proxy |
   | Upstream | `http://192.168.100.10:3000` |
   | Application Name | `JuiceShop` |

7. Click **Submit**.

### Step 2: Verify the protected application path

1. In Firefox on **vm3-kali**, open `http://juice.lab` and confirm the Juice Shop homepage loads.
2. Confirm the WAF path works and the direct path is blocked:
   ```bash
   curl -I http://juice.lab/
   curl -I --connect-timeout 3 http://192.168.100.10:3000 || echo "Blocked (expected)"
   ```
   The first returns `HTTP/1.1 200 OK`; the second times out.

### Step 3: Benign user workflow

This creates a valid user session and an order, which the later Track Order XSS test needs.

1. In Firefox, open `http://juice.lab`. If logged in, **Account → Logout**.
2. **Account → Login → Not yet a customer?** and register:
   - Email: `student@gmail.com`
   - Password: `tartans`
   - Any security question and answer.
3. Log in with those credentials.
4. Search for any product, add one to the basket, open **Your Basket** and check out.
5. Enter a dummy delivery address, choose a delivery speed, and enter **made-up** card details.
6. Place the order and confirm it appears under **Orders & Payment → Order History**.

Then generate the benign results:

```bash
cd ~/waf-lab
./benign/benign_run.sh
cat results/benign_results.csv
```

#### Grading Check 1

```bash
cd ~/waf-lab/grading_check
python3 grading_check_1.py
```

Verifies that no benign request was blocked (no `403`).

---

## Phase 2 — Default WAF behavior evaluation

### Step 4: SQL injection (manual)

1. In Firefox on vm3-kali, log out, then **Account → Login**.
2. Email: `student@gmail.com' OR TRUE--`, any password, click **Log in**.
3. Observe that SafeLine blocks the request.
4. On vm2-safeline, open **Attacks**, find the most recent event from `192.168.100.30`, click the **Attack Count** box and confirm the attack type is **SQL Inj**. Events can take a few minutes to appear.

### Step 5: XSS (manual)

1. Log in as `student@gmail.com` / `tartans`.
2. **Account → Orders & Payment → Order History**, click the truck icon (**Track Order**).
3. In the URL, replace the value after `id=` with:
   ```
   <iframe%20src%3D"javascript:alert(%60You%20have%20been%20hacked!%60)">
   ```
4. Load the page and observe whether it is blocked or an alert appears.
5. In SafeLine **Attacks → EVENTS**, confirm the most recent event from `192.168.100.30` is classified as **XSS**.

### Step 6: Basic OWASP Top 10 attack testing

```bash
cd ~/waf-lab
./attacks/test.sh
```

All four payloads go to the same search endpoint, `/rest/products/search?q=`:

| Attack | Payload |
|---|---|
| SQL injection | `1 and 1=2 union select 1` |
| XSS | `<img src=x onerror=alert(1)>` |
| Path traversal | `../../../../etc/passwd` |
| Command injection | `;id;` |

Expected output:

```
pathtrav,403
cmdinj,200
sqli,403
xss,403
[+] Wrote to /home/student/waf-lab/results/attack_results.csv
```

HTTP status interpretation:

- `403` — blocked by SafeLine
- `401` — reached Juice Shop, authentication failed
- `200` — reached Juice Shop and returned normally

#### Why command injection returned 200

Open `http://juice.lab/#/search?q=%3Bid%3B` in Firefox. Juice Shop calls `http://juice.lab/rest/products/search?q=%3Bid%3B` and returns:

```json
{ "status": "success", "data": [] }
```

The request **reached Juice Shop**, but there is **no evidence of command execution**: the search API treats the payload as an ordinary string, roughly `SELECT * FROM Products WHERE name LIKE '%;id;%'`. SafeLine did not block it, and nothing was executed either.

#### Grading Check 2

```bash
cd ~/waf-lab/grading_check
python3 grading_check_2.py
```

### Step 7: Advanced attack testing

Sending every payload to one endpoint is repeatable but unrealistic. The advanced script picks an endpoint suited to each attack:

| Attack | Method / endpoint | Payload | Reason |
|---|---|---|---|
| SQL injection | `POST /rest/user/login` | `' or 1=1--` in email | Login forms query the database |
| XSS | `GET /rest/products/search?q=` | `<img src=x onerror=alert(1)>` | Search input may be reflected |
| Command injection (semicolon) | `POST /rest/user/login` | `;cat /etc/passwd` in password | Shell command chaining |
| Command injection (substitution) | `POST /rest/user/login` | `$(id)` in password | Shell command substitution |
| Command injection (pipe) | `POST /rest/user/login` | `\| whoami` in password | Pipe-based execution |

```bash
cd ~/waf-lab
./attacks/advanced_attack.sh
cp results/advanced_attack_results.csv results/advanced_pre_tuning.csv
```

#### Grading Check 3

```bash
cd ~/waf-lab/grading_check
python3 grading_check_3.py
```

Verifies that at least one attack was blocked and that the `$(id)` and `whoami` variants were **not** blocked before tuning.

### Step 8: Advanced results analysis

```bash
cat ~/waf-lab/results/advanced_pre_tuning.csv
```

| Attack | Payload | HTTP code | Interpretation |
|---|---|---|---|
| SQL injection | `' or 1=1--` | 403 | Blocked by WAF |
| XSS | `<img src=x onerror=alert(1)>` | 403 | Blocked by WAF |
| Command injection | `;cat /etc/passwd` | 403 | Blocked by WAF |
| Command injection variant | `$(id)` | 401 | Passed WAF, authentication failed |
| Command injection variant | `\| whoami` | 401 | Passed WAF, authentication failed |

A `401` means the request was **not blocked** and was processed by Juice Shop.

In the SafeLine console (`https://192.168.100.20:9443/`) → **Attacks**, open the most recent event from `192.168.100.30`. The **yellow** Attack Count box marks an audited request. Its action is **Audited** and its attack type **Command Injection**: SafeLine recognised it but, under the default policy, logged it instead of blocking it. Click **Detail** to inspect the request body.

#### Baseline performance

```bash
cd ~/waf-lab
./benign/perf_run.sh http://juice.lab/ 20 results/perf_before_tuning.csv
```

---

## Phase 3 — Policy tuning and operational observation

### Step 9: Firewall policy tuning

#### Strict mode for command injection

1. In the SafeLine console, go to **Attacks → SEMANTICS ANALYSIS**.
2. Set **CMD Inj** to **Strict Mode**.

SafeLine now blocks every request it classifies as command injection, including the `| whoami` variant that was previously only audited.

#### Custom rule: detect shell command substitution

1. **Allow & Deny → CUSTOM RULES → Add Rules**.
2. Configure:

   | Field | Value |
   |---|---|
   | Type | Deny Rule |
   | Name | `Detect Shell Command Substitution` |
   | Match Target | Req Body |
   | Operator | Contains |
   | Content | `$(` |
   | Enabled | ✓ |

3. Click **Submit**.

Any request body containing `$(` is now rejected before it reaches Juice Shop.

### Step 10: Re-test after tuning

```bash
cd ~/waf-lab
./attacks/advanced_attack.sh
cp results/advanced_attack_results.csv results/advanced_post_tuning.csv
cat results/advanced_post_tuning.csv
```

All advanced command-injection payloads should now return **403 Forbidden**.

#### Grading Check 4

```bash
cd ~/waf-lab/grading_check
python3 grading_check_4.py
```

### Step 11: False positives and performance

#### False-positive observation

```bash
cd ~/waf-lab
./benign/benign_load.sh
cat results/benign_load.csv
```

If every response is `200`, no false-positive-like blocking was observed for this benign workload.

#### Performance measurement

```bash
cd ~/waf-lab
./benign/perf_run.sh http://juice.lab/ 20 results/perf_after_tuning.csv
```

Both files use the columns `run,time_total`. Compare the averages to see whether stricter filtering adds latency.

#### Grading Check 5

```bash
cd ~/waf-lab/grading_check
python3 grading_check_5.py
```

Prints `avg_before`, `avg_after` and `delta`.

---

## Conclusion

SafeLine, as an application-layer reverse proxy, is better suited than a network firewall to catching web-specific attacks such as SQL injection and XSS. In this lab it blocked several common attacks by default, but some command-injection variants were only audited until CMD Inj strict mode and a custom `$(` deny rule were added. WAF effectiveness depends on rule coverage and policy configuration; tighter rules should be weighed against false positives and latency, and a WAF should complement — not replace — secure application design and input validation.
