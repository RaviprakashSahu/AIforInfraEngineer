# Copilot Chat Conversation Export: Incident analysis and preventive actions report

**User:** @karthik-zippy
**Thread URL:** https://github.com/copilot/c/18ba2bb6-03e7-4ee5-be21-dabd172792d4

## @karthik-zippy

```
You are a senior infrastructure incident analyst.
Using the logs provided, produce:
  1. Chronological incident timeline (HH:MM format)
  2. Root cause statement (one sentence)
  3. 5-Why analysis
  4. Contributing factors
  5. Preventive actions (ranked by impact)

Constraints:
  - Base all findings ONLY on the log evidence provided
  - If evidence is insufficient for a finding, state: 'Insufficient evidence'
  - Do not speculate beyond what the logs show

--- LOG SOURCES ---
[Source 1: Change Record + Application Log]
=== Change Record CHG-20240318-0047 ===
Type:     Standard — NSG + Route Table Update
Deployed: 2024-03-18 01:47:31 UTC (automated pipeline)
Approved: J.Smith (network-architect)
Changes applied:
  ADDED:    NSG rule AllowHTTPS (inbound 443 from 0.0.0.0/0 to snet-app)
  ADDED:    NSG rule AllowHTTP  (inbound 80  from 0.0.0.0/0 to snet-app)
  MODIFIED: Route table rt-app — added static route:
            10.0.2.0/24 via gateway 10.0.1.254

Application Log (01:47–01:52 UTC):
01:48:05 WARN  AppServer — DB response time elevated: 320ms (was: 4ms)
01:49:12 ERROR AppServer — DB connection timeout (attempt 1/3) after 3000ms
01:49:15 ERROR AppServer — DB connection timeout (attempt 2/3) after 3000ms
01:49:18 ERROR AppServer — DB connection FAILED — switching to read-only mode
01:49:18 ERROR AppServer — Write transactions suspended
01:52:00 ERROR AppServer — Health check FAILING — /health returning 503

[Source 2: Network Routing Table]
=== BEFORE change (snapshot 01:44 UTC) ===
Destination    Gateway       Genmask           Flags  Iface
0.0.0.0        10.0.1.1      0.0.0.0           UG     eth0
10.0.1.0       0.0.0.0       255.255.255.0     U      eth0
10.0.2.0       0.0.0.0       255.255.255.0     U      eth0

=== AFTER change (snapshot 01:48 UTC) ===
Destination    Gateway       Genmask           Flags  Iface
0.0.0.0        10.0.1.1      0.0.0.0           UG     eth0
10.0.1.0       0.0.0.0       255.255.255.0     U      eth0
10.0.2.0       10.0.1.254    255.255.255.0     UGH    eth0  <-- ADDED
10.0.2.0       0.0.0.0       255.255.255.0     U      eth0

Connectivity test 01:49 UTC:
ping -c3 10.0.2.10: 3 packets transmitted, 0 received, 100% packet loss

[Source 3: Monitoring Alerts]
01:44:00 INFO     Change window open — deploying CHG-20240318-0047
01:47:31 INFO     NSG update applied
01:48:00 WARNING  vm-app → vm-db latency=287ms (threshold: 50ms)
01:49:00 CRITICAL vm-app → vm-db connectivity=FAILED
01:49:30 CRITICAL payment-service.db_connection=TIMEOUT
01:50:00 CRITICAL payment-api.write_transactions=0 (threshold: >50/min)
01:52:00 CRITICAL payment-api.health_check=FAILING (503 responses)
--- END ---

```

## Copilot

**1. Chronological incident timeline**

- **01:44** — Change window opened for deployment of **CHG-20240318-0047**.  
  Evidence: Source 3 `01:44:00 INFO Change window open — deploying CHG-20240318-0047`

- **01:47** — Change **CHG-20240318-0047** deployed by automated pipeline.  
  Evidence: Source 1 `Deployed: 2024-03-18 01:47:31 UTC`

- **01:47** — NSG update applied.  
  Evidence: Source 3 `01:47:31 INFO NSG update applied`

- **01:48** — Post-change routing table snapshot shows a new static route for **10.0.2.0/24 via 10.0.1.254** while the existing direct route to **10.0.2.0/24** remains present.  
  Evidence: Source 1 change record; Source 2 `AFTER change (snapshot 01:48 UTC)`

- **01:48** — Monitoring detects elevated latency from **vm-app → vm-db** to **287ms**.  
  Evidence: Source 3 `01:48:00 WARNING vm-app → vm-db latency=287ms`

- **01:48** — Application logs elevated DB response time to **320ms** from **4ms** baseline.  
  Evidence: Source 1 `01:48:05 WARN AppServer — DB response time elevated: 320ms (was: 4ms)`

- **01:49** — Connectivity test to **10.0.2.10** fails with **100% packet loss**.  
  Evidence: Source 2 `Connectivity test 01:49 UTC: ping -c3 10.0.2.10: 3 packets transmitted, 0 received, 100% packet loss`

- **01:49** — Monitoring declares **vm-app → vm-db connectivity=FAILED**.  
  Evidence: Source 3 `01:49:00 CRITICAL vm-app → vm-db connectivity=FAILED`

- **01:49** — Application DB connection timeout attempt **1/3** after **3000ms**.  
  Evidence: Source 1 `01:49:12 ERROR AppServer — DB connection timeout (attempt 1/3) after 3000ms`

- **01:49** — Application DB connection timeout attempt **2/3** after **3000ms**.  
  Evidence: Source 1 `01:49:15 ERROR AppServer — DB connection timeout (attempt 2/3) after 3000ms`

- **01:49** — Application fails DB connection, switches to **read-only mode**, and suspends write transactions.  
  Evidence: Source 1 `01:49:18 ERROR AppServer — DB connection FAILED — switching to read-only mode` and `01:49:18 ERROR AppServer — Write transactions suspended`

- **01:49** — Monitoring reports **payment-service.db_connection=TIMEOUT**.  
  Evidence: Source 3 `01:49:30 CRITICAL payment-service.db_connection=TIMEOUT`

- **01:50** — Monitoring reports **payment-api.write_transactions=0**.  
  Evidence: Source 3 `01:50:00 CRITICAL payment-api.write_transactions=0 (threshold: >50/min)`

- **01:52** — Application health check begins returning **503**.  
  Evidence: Source 1 `01:52:00 ERROR AppServer — Health check FAILING — /health returning 503`; Source 3 `01:52:00 CRITICAL payment-api.health_check=FAILING (503 responses)`

---

**2. Root cause statement**

The incident was caused by the route table change at **01:47:31 UTC** that added a static route for **10.0.2.0/24 via 10.0.1.254**, after which app-to-DB latency rose sharply and connectivity to **10.0.2.10** failed, leading to DB timeouts, read-only mode, suspended writes, and failing health checks.

---

**3. 5-Why analysis**

1. **Why did the application start failing health checks and returning 503?**  
   Because the application switched to read-only mode, suspended write transactions, and later reported `/health` failing.  
   Evidence: Source 1 at `01:49:18` and `01:52:00`

2. **Why did the application switch to read-only mode and suspend writes?**  
   Because DB connection attempts timed out and then failed.  
   Evidence: Source 1 at `01:49:12`, `01:49:15`, `01:49:18`

3. **Why did DB connections time out?**  
   Because connectivity between **vm-app** and **vm-db** degraded and then failed.  
   Evidence: Source 3 at `01:48:00` and `01:49:00`; Source 2 connectivity test at `01:49`

4. **Why did vm-app to vm-db connectivity degrade and fail?**  
   Because immediately after the network change, the routing table included a newly added static route for **10.0.2.0/24 via 10.0.1.254**, coinciding with the onset of latency and packet loss.  
   Evidence: Source 1 change record; Source 2 after-change routing table; Source 3 timing correlation  
   Note: The logs show correlation and route change presence, but not packet-path tracing proving exact forwarding behavior.

5. **Why was that route introduced into production?**  
   It was part of approved standard change **CHG-20240318-0047** deployed by an automated pipeline.  
   Evidence: Source 1 change record  
   **Why it was needed or why it was incorrect:** **Insufficient evidence**

---

**4. Contributing factors**

- **Network route table was modified at the same deployment time as the incident onset.**  
  Evidence: Source 1, Source 2, Source 3

- **A new static route to 10.0.2.0/24 was added while a direct route to the same subnet remained present in the routing table.**  
  Evidence: Source 2 after-change snapshot  
  Impact interpretation beyond coexistence: **Insufficient evidence**

- **Connectivity degradation began within less than a minute of the deployed change.**  
  Evidence: change at `01:47:31`; latency alert at `01:48:00`; app warning at `01:48:05`

- **Connectivity to 10.0.2.10 showed 100% packet loss during the incident.**  
  Evidence: Source 2 connectivity test at `01:49`

- **Application behavior amplified user-visible impact by entering read-only mode and suspending writes once DB connectivity failed.**  
  Evidence: Source 1 at `01:49:18`

- **NSG changes were deployed in the same change set as the route table update, making isolation of the exact failing sub-change harder from these logs alone.**  
  Evidence: Source 1 lists both NSG additions and route table modification  
  Exact contribution of NSG rules: **Insufficient evidence**

---

**5. Preventive actions (ranked by impact)**

1. **Add automated post-change connectivity validation for critical dependencies (for example, vm-app → vm-db) immediately after route-table/network changes, with automatic rollback on failure.**  
   Supported by evidence: failure appeared within 1–2 minutes of deployment and was detectable by latency/connectivity checks.

2. **Require route-change guardrails to detect overlapping or duplicate routes to the same destination subnet before deployment.**  
   Supported by evidence: after-change table shows both a direct route and a gateway route for `10.0.2.0/24`.

3. **Separate route-table changes from NSG changes into independently validated deployments.**  
   Supported by evidence: both were included in the same change record, reducing clarity of impact isolation.

4. **Add a pre-production or pipeline-stage network path test specifically for database subnet reachability after route modifications.**  
   Supported by evidence: the incident centered on loss of reachability to `10.0.2.10` following the route update.

5. **Alert directly on sudden DB latency regression immediately following infrastructure changes and tie alerts to active change records.**  
   Supported by evidence: latency rose from ~4ms to 287–320ms almost immediately after deployment.

If you want, I can also reformat this into a formal **RCA report template** suitable for incident review.
