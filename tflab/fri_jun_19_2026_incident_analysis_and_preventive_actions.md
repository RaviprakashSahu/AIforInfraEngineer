# Copilot Chat Conversation Export: Incident analysis and preventive actions

**User:** @karthik-zippy
**Thread URL:** https://github.com/copilot/c/03232557-629b-4894-a136-d69b364aae6a

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

1. **Chronological incident timeline**
- **01:44** — Change window opened for deployment of **CHG-20240318-0047**.
- **01:47** — Change **CHG-20240318-0047** deployed by automated pipeline; monitoring shows **NSG update applied** at **01:47:31**.
- **01:48** — Post-change routing snapshot shows a new static route for **10.0.2.0/24 via 10.0.1.254** added while the previous direct route to **10.0.2.0/24** still exists.
- **01:48** — Monitoring warning: **vm-app → vm-db latency = 287ms** (threshold 50ms).
- **01:48** — Application warning: **DB response time elevated to 320ms** (was 4ms) at **01:48:05**.
- **01:49** — Monitoring critical: **vm-app → vm-db connectivity = FAILED**.
- **01:49** — Connectivity test to **10.0.2.10** shows **100% packet loss**.
- **01:49** — Application error: **DB connection timeout attempt 1/3** at **01:49:12**.
- **01:49** — Application error: **DB connection timeout attempt 2/3** at **01:49:15**.
- **01:49** — Application error: **DB connection failed; switching to read-only mode** at **01:49:18**.
- **01:49** — Application error: **Write transactions suspended** at **01:49:18**.
- **01:49** — Monitoring critical: **payment-service.db_connection = TIMEOUT** at **01:49:30**.
- **01:50** — Monitoring critical: **payment-api.write_transactions = 0** (threshold >50/min).
- **01:52** — Application reports **/health returning 503**.
- **01:52** — Monitoring critical: **payment-api.health_check = FAILING (503 responses)**.

2. **Root cause statement**
- The incident was caused by the route table change that added a static route for **10.0.2.0/24 via 10.0.1.254**, after which app-to-DB latency rose, connectivity to **10.0.2.10** failed, and the application lost DB connectivity.

3. **5-Why analysis**
1. **Why did the application enter read-only mode and suspend writes?**  
   Because the application logged repeated **DB connection timeouts** and then **DB connection FAILED — switching to read-only mode** at **01:49:18**.

2. **Why did DB connection timeouts occur?**  
   Because connectivity between **vm-app** and **vm-db** failed, as shown by monitoring at **01:49:00** and the **100% packet loss** ping test to **10.0.2.10** at **01:49**.

3. **Why did vm-app to vm-db connectivity fail?**  
   Because immediately after the change, the routing table included a new static route for **10.0.2.0/24 via 10.0.1.254**, and the failure symptoms began right after that change.  

4. **Why did that routing change affect connectivity to the DB subnet?**  
   The logs show that **10.0.2.0/24** had previously been directly reachable on **eth0**, and after the change an additional gateway-based route to the same destination was added. The logs do **not** show route selection behavior or gateway health.  
   **Insufficient evidence** beyond the correlation between the added route and the connectivity failure.

5. **Why was this risky change introduced into production?**  
   The change record shows it was executed as a **Standard — NSG + Route Table Update** via **automated pipeline** and approved by **J.Smith**.  
   **Insufficient evidence** on why the specific static route was added or why validation did not prevent impact.

4. **Contributing factors**
- The route table was modified for the DB subnet **10.0.2.0/24** immediately before the incident symptoms began.
- After the change, there were **two routes** present for **10.0.2.0/24**: one direct and one via **10.0.1.254**.
- The issue affected a critical dependency: **vm-app → vm-db** connectivity.
- Application behavior amplified user impact: when DB connectivity failed, the app **switched to read-only mode** and **suspended write transactions**.
- Health checks degraded to **503**, indicating service-level impact beyond just internal DB latency.

5. **Preventive actions (ranked by impact)**
1. **Add automated post-change connectivity validation for critical paths (app-to-DB) immediately after route-table changes, with automatic rollback on failure.**  
   High impact; directly addresses the failure pattern seen at **01:48–01:49**.

2. **Require explicit validation for any route changes affecting critical subnets such as 10.0.2.0/24 before completing deployment.**  
   High impact; the incident evidence ties impact to the route-table modification.

3. **Alert specifically on route-table changes to DB-connected subnets and correlate them with connectivity/latency alarms.**  
   High impact; would shorten detection and attribution.

4. **Separate NSG-only and route-table changes into independently validated deployment steps.**  
   Medium impact; the logs show both were part of one standard change, which complicates fault isolation.

5. **Add a health check for DB reachability as part of application dependency monitoring before write-path degradation occurs.**  
   Medium impact; monitoring detected latency and connectivity issues, but earlier dependency gating may reduce service impact.
