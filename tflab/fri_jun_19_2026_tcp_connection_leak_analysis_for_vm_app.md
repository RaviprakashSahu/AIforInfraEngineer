# Copilot Chat Conversation Export: TCP connection leak analysis for vm-app

**User:** @karthik-zippy
**Thread URL:** https://github.com/copilot/c/69d3ed6c-ce3b-42e0-9a33-765fd9665bb9

## @karthik-zippy

```
You are a senior infrastructure capacity planning engineer.

Analyse this 90-day historical trend data for an Azure payment processing
environment (vm-app, vm-db). Data is weekly snapshots.

Answer:
1. Which metric shows the most concerning trend, and why — concerning means
   the RATE of change, not just the current value.
2. The DB Connections metric grew from 2.1 to 7.3 over 90 days with no drop
   or plateau at any point. What does a perfectly monotonic increase with no
   variance suggest about the underlying cause, compared to a trend that
   fluctuates with daily/weekly load patterns?
3. If this DB Connections trend continues at the same rate, on what date
   would it reach the alert threshold of 16/20 connections?
4. Disk % grew from 12.4% to 34.4% — a 22-point increase in 90 days.
   At this rate, when would vm-app's disk reach 85%?
   Is this an urgent concern or a 'watch and revisit' item?
5. CPU % stayed essentially flat (3.1% → 3.6%). What does flat CPU combined
   with rising memory and disk usage suggest about what kind of workload
   change is occurring? (Hint: think about what consumes memory/disk but
   not CPU.)
6. PRIORITY RANKING: Rank all 4 metrics by urgency of action needed, with
   justification for the ranking.
   
---Historical data(90day, weekly snapshots)---
epoch_day,timestamp,cpu_pct,mem_pct,disk_pct,db_connections
19800,2024-01-01 09:00:00,3.1,17.8,12.4,2.1
19807,2024-01-08 09:00:00,3.2,18.6,15.1,2.6
19814,2024-01-15 09:00:00,3.0,19.1,17.8,3.0
19821,2024-01-22 09:00:00,3.3,19.8,20.2,3.4
19828,2024-01-29 09:00:00,3.2,20.4,22.9,3.9
19835,2024-02-05 09:00:00,3.4,21.2,25.6,4.3
19842,2024-02-12 09:00:00,3.3,21.9,27.8,4.8
19849,2024-02-19 09:00:00,3.5,22.6,29.9,5.2
19856,2024-02-26 09:00:00,3.4,23.4,31.2,5.7
19863,2024-03-04 09:00:00,3.6,24.1,32.8,6.1
19870,2024-03-11 09:00:00,3.5,24.8,33.6,6.5
19877,2024-03-18 09:00:00,3.7,25.6,34.1,6.9
19884,2024-03-25 09:00:00,3.6,26.3,34.4,7.3
```

## Copilot

1. **Most concerning trend: `db_connections`**  
   Because of its **rate and shape**: it rises from **2.1 → 7.3** (+5.2, ~**248%** increase) in 90 days, and does so **perfectly monotonically** (every sample up, no pauses). That is more concerning than disk/memory’s rise because it suggests a persistent accumulating driver, not normal workload variation.

2. A **perfectly monotonic increase with no variance** usually suggests a **systematic/structural cause** (e.g., connection leak, unreleased pooled sessions, steadily increasing baseline worker/process count, config drift), rather than demand-driven load.  
   If it were normal business load growth, you’d usually see **oscillation** (weekday/weekend, batch windows, month-end effects), not a near-linear staircase every week.

3. **Projection to 16 connections (same linear rate):**  
   - Slope = \((7.3-2.1)/90 = 0.0578\) connections/day  
   - Needed from last point (7.3 → 16): \(8.7\) connections  
   - Time = \(8.7 / 0.0578 \approx 150.6\) days after **2024-03-25**  
   - Projected date: **~2024-08-22** (about Aug 22–23)

4. **Disk projection to 85% (same rate):**  
   - Slope = \((34.4-12.4)/90 = 0.2444\) percentage points/day  
   - Needed from last point (34.4 → 85): \(50.6\) points  
   - Time = \(50.6 / 0.2444 \approx 207\) days after **2024-03-25**  
   - Projected date: **~2024-10-18**  
   **Urgency:** not immediate firefight, but more than passive watch. I’d classify as **“watch closely + plan cleanup/capacity now”** (weekly tracking, storage growth attribution, threshold-based action plan).

5. **Flat CPU + rising memory/disk** suggests change in a **state-retaining or data-accumulating workload**, not compute-intensive work. Typical patterns:  
   - larger caches/in-memory state  
   - longer object/session lifetimes (possible leak)  
   - increased queue backlog/spool/temp files/log volume  
   - DB/session connection retention  
   In short: **more footprint per unit work**, not more CPU cycles per unit time.

6. **Priority ranking (highest urgency → lowest):**  
   1. **DB Connections** — fastest relative growth, perfectly monotonic, finite hard limit (20), could cause abrupt availability failures when exhausted.  
   2. **Disk %** — strong sustained rise; projected to critical in months, and disk-full events are high impact.  
   3. **Memory %** — consistent rise (17.8 → 26.3) but still moderate level; investigate trend and leak/cache behavior before it compounds.  
   4. **CPU %** — effectively flat and very low (3.1 → 3.6), no near-term capacity risk signal.

If you want, I can also give this as an **ops action plan** (what to check this week vs this month, with alert thresholds).

## @karthik-zippy

```
You are a senior infrastructure capacity planning engineer.

Analyse this 90-day historical trend data for an Azure payment processing
environment (vm-app, vm-db). Data is weekly snapshots.

Answer:
1. Which metric shows the most concerning trend, and why — concerning means
   the RATE of change, not just the current value.
2. The DB Connections metric grew from 2.1 to 7.3 over 90 days with no drop
   or plateau at any point. What does a perfectly monotonic increase with no
   variance suggest about the underlying cause, compared to a trend that
   fluctuates with daily/weekly load patterns?
3. If this DB Connections trend continues at the same rate, on what date
   would it reach the alert threshold of 16/20 connections?
4. Disk % grew from 12.4% to 34.4% — a 22-point increase in 90 days.
   At this rate, when would vm-app's disk reach 85%?
   Is this an urgent concern or a 'watch and revisit' item?
5. CPU % stayed essentially flat (3.1% → 3.6%). What does flat CPU combined
   with rising memory and disk usage suggest about what kind of workload
   change is occurring? (Hint: think about what consumes memory/disk but
   not CPU.)
6. PRIORITY RANKING: Rank all 4 metrics by urgency of action needed, with
   justification for the ranking.
   
---Historical data(90day, weekly snapshots)---
epoch_day,timestamp,cpu_pct,mem_pct,disk_pct,db_connections
19800,2024-01-01 09:00:00,3.1,17.8,12.4,2.1
19807,2024-01-08 09:00:00,3.2,18.6,15.1,2.6
19814,2024-01-15 09:00:00,3.0,19.1,17.8,3.0
19821,2024-01-22 09:00:00,3.3,19.8,20.2,3.4
19828,2024-01-29 09:00:00,3.2,20.4,22.9,3.9
19835,2024-02-05 09:00:00,3.4,21.2,25.6,4.3
19842,2024-02-12 09:00:00,3.3,21.9,27.8,4.8
19849,2024-02-19 09:00:00,3.5,22.6,29.9,5.2
19856,2024-02-26 09:00:00,3.4,23.4,31.2,5.7
19863,2024-03-04 09:00:00,3.6,24.1,32.8,6.1
19870,2024-03-11 09:00:00,3.5,24.8,33.6,6.5
19877,2024-03-18 09:00:00,3.7,25.6,34.1,6.9
19884,2024-03-25 09:00:00,3.6,26.3,34.4,7.3
```

## Copilot

My analysis is identical to the previous response — the data and questions are exactly the same, so the answers don't change. Here's a clean consolidated version:

---

## Infrastructure Capacity Analysis — Azure Payment Environment (90-day)

### 1. Most Concerning Trend by Rate of Change: **DB Connections**

| Metric | Start | End | Absolute Δ | Relative Δ |
|---|---|---|---|---|
| CPU % | 3.1 | 3.6 | +0.5 pp | +16% |
| Memory % | 17.8 | 26.3 | +8.5 pp | +48% |
| Disk % | 12.4 | 34.4 | +22.0 pp | +177% |
| DB Connections | 2.1 | 7.3 | +5.2 | **+248%** |

DB Connections wins on both relative rate and shape — a perfectly monotonic staircase with no variance. Its finite hard ceiling (20 connections) means exhaustion causes an abrupt availability failure, not a slow degradation.

---

### 2. Perfectly Monotonic Increase — What It Signals

| Pattern | Likely Cause |
|---|---|
| **Monotonic (this case)** | Structural / systematic driver — connection leak, unreleased pooled sessions, steadily growing worker process count, config drift |
| **Oscillating with load** | Demand-driven — weekday/weekend cycles, batch windows, month-end spikes |

A trend that never dips, even slightly, means **connections are being opened and never returned to the pool or closed**. Normal load growth always shows some oscillation as sessions end between bursts. A perfect staircase eliminates load-pattern explanations and points to a **leak or a continuously accumulating process count**.

---

### 3. Projection: DB Connections → Alert Threshold (16/20)

```
Slope  = (7.3 − 2.1) / 90 days = 0.0578 connections/day
Gap    = 16.0 − 7.3 = 8.7 connections remaining
Days   = 8.7 / 0.0578 ≈ 150 days from 2024-03-25
```

> **Projected breach of 16-connection alert: ~2024-08-22**
> Hard limit (20) breached: ~2024-10-16

**Action window: ~5 months to alert, ~7 months to hard failure** — tight for a payment processing system.

---

### 4. Projection: Disk % → 85%

```
Slope  = (34.4 − 12.4) / 90 days = 0.2444 pp/day
Gap    = 85.0 − 34.4 = 50.6 pp remaining
Days   = 50.6 / 0.2444 ≈ 207 days from 2024-03-25
```

> **Projected 85% disk: ~2024-10-18**

**Verdict: "Plan now, don't panic yet."**
- Not an immediate firefight, but far enough away to have meaningful lead time for attribution (logs? data growth? temp files?) and remediation (cleanup, quota enforcement, storage expansion).
- Weekly tracking with a defined trigger for escalation (e.g., "if slope increases or crosses 60%, act immediately").

---

### 5. Flat CPU + Rising Memory & Disk → Workload Characterization

**This pattern is diagnostic.** CPU stays low when work doesn't require heavy computation — it rises when threads are burning cycles. Memory and disk grow when:

| Driver | Memory Impact | Disk Impact | CPU Impact |
|---|---|---|---|
| Connection/session leaks | ✅ (held buffers) | ✅ (temp/log files) | ❌ |
| Growing data volume (logs, audit trails) | ❌ | ✅ | ❌ |
| Expanded in-memory cache/state | ✅ | ❌ | ❌ |
| Growing queue/spool backlog | ✅ | ✅ | ❌ |
| More idle worker processes | ✅ | ✅ | ❌ |

Given the **simultaneous rise in all three non-CPU metrics**, the most likely story is **accumulated state** — more open sessions/connections holding memory buffers, combined with those sessions generating log/temp/audit file growth on disk. This is consistent with the connection leak hypothesis from Question 2.

---

### 6. Priority Ranking — Urgency of Action

| Rank | Metric | Time to Critical | Action Required |
|---|---|---|---|
| 🔴 **1** | **DB Connections** | ~150 days to alert | **Immediate investigation** — instrument connection pool, audit open/close pairs, check for missing `connection.close()` or pool misconfiguration |
| 🟠 **2** | **Disk %** | ~207 days to 85% | **Plan this month** — attribute growth (logs? data? temp?), implement retention policies, schedule storage review |
| 🟡 **3** | **Memory %** | No hard ceiling in data, but 48% growth rate warrants tracking | **Monitor weekly** — identify what's holding memory, check if correlated with connection count (likely yes) |
| 🟢 **4** | **CPU %** | Effectively flat, no risk signal | **No action** — continue baseline monitoring |

**The key risk in a payment processing environment** is not gradual degradation — it's the step-function failure when DB connections exhaust. Unlike disk (which may cause slowness first) or memory (which may trigger swapping), a hard connection pool limit causes **immediate transaction failures**. That makes DB Connections the unambiguous #1 priority regardless of which metric has the largest absolute value today.

## @karthik-zippy

vm-app memory grew from 17.8% to 26.3% over 90 days while CPU stayed flat at ~3.3%.
This VM hosts a Java payment service (when running) with -Xmx4g configured on an
8GB RAM Standard_B2ms VM.

If this were JVM heap growth (a memory leak in the application), what would
you expect to see in jstat or jmap that would confirm it?
If this were OS-level cache/buffer growth (normal Linux behaviour), would this
be a concern at all? How would you distinguish the two from this trend data alone?
Write the exact command to capture JVM heap usage history if the payment
service were running, for use in next week's trend-capture.sh run.
respond it in chat

## Copilot

## JVM vs OS Cache: Diagnosing vm-app Memory Growth

---

### 1. What JVM Heap Leak Looks Like in `jstat` / `jmap`

**`jstat -gcutil <pid> 5000 20`** — this is your first tool. A heap leak shows:

| Column | Leak Signature | Normal (GC healthy) |
|---|---|---|
| `O` (Old Gen %) | **Climbs each GC cycle, never fully reclaims** | Drops after full GC, stays bounded |
| `YGC` / `FGC` | FGC frequency increases over time | FGC rare, YGC regular |
| `FGCT` | Full GC wall time grows (longer pauses) | Stays short and stable |
| `GCT` | Total GC time as % of uptime creeps up | Low and stable |

The **smoking gun** is Old Gen (`O`) that rises across multiple full GC cycles and **never returns to a consistent baseline**. Each GC cleans less and less.

**`jmap -histo:live <pid>`** then shows you *what* is leaking:

```
num     #instances         #bytes  class name
  1:        284921       45,587,360  [B                          ← byte arrays
  2:        198432       31,749,120  java.util.HashMap$Entry     ← map entries not released
  3:         87654       14,024,640  com.payment.SessionContext  ← your class, growing unbounded
```

If `SessionContext` or a connection/session wrapper is in the top 10 and instance count grows between captures — **that's your leak class**.

---

### 2. OS Cache/Buffer Growth — Should You Worry?

**No, not by itself.** Linux deliberately uses free RAM for page cache (`cached`) and buffers (`buffers`). This is normal and healthy — the kernel reclaims it instantly under memory pressure.

What `free -h` looks like in the normal case:

```
              total   used   free   shared  buff/cache   available
Mem:           7.8G   2.1G   512M     64M        5.1G        5.4G
```

`available` stays high even when `free` is low — the cache is not "used" in any harmful sense.

**It would only be a concern if:**
- `available` is trending toward zero (not just `free`)
- You see swap usage (`Swap: used` > 0 and growing)
- Applications start getting OOM-killed (`dmesg | grep -i oom`)

---

### 3. Distinguishing the Two From This Trend Data Alone

Honestly, **you cannot definitively distinguish them from this data** — and that's an important answer to give. Here's what the data *can* and *cannot* tell you:

| Signal | JVM Heap Leak | OS Cache Growth |
|---|---|---|
| Memory rises while CPU flat | ✅ consistent | ✅ consistent |
| Growth perfectly linear week-over-week | Possible (steady leak) | Also possible |
| **Correlates with DB connection rise** | **Strong yes** (leaked sessions hold heap + open connections) | Unlikely — cache growth is independent of connection state |
| **Would reset after service restart** | **Yes** — heap clears | No — OS cache refills quickly |
| Growth rate proportional to transaction volume | Yes | Not necessarily |

**The DB Connections correlation is your strongest diagnostic clue from this dataset alone.** Both metrics are monotonically increasing at similar rates with no variance. OS cache growth does not consume DB connections. A session/connection leak does both simultaneously — it holds a `SessionContext` object in heap *and* holds an open DB connection.

> **Working hypothesis from trend data:** JVM session or connection object leak in the payment service, not OS cache behaviour.

---

### 4. Exact Command for `trend-capture.sh`

```bash
# ── JVM heap snapshot for weekly trend-capture.sh ──────────────────────────
# Requires: $PAYMENT_PID resolved before this block runs
# Output:   appended to /var/log/capacity/jvm_heap_trend.csv

PAYMENT_PID=$(pgrep -f 'payment-service' | head -1)
CAPTURE_TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

if [ -z "$PAYMENT_PID" ]; then
  echo "${CAPTURE_TS},ERROR,service_not_running" \
    >> /var/log/capacity/jvm_heap_trend.csv
else
  # jstat columns: S0% S1% E%(Eden) O%(OldGen) M%(Metaspace)
  #                YGC YGCT FGC FGCT GCT
  JVM_STATS=$(jstat -gcutil "${PAYMENT_PID}" 1000 5 \
    | tail -1 \
    | awk '{print $4","$5","$6","$7","$8","$9","$10}')
  # fields: Eden%, OldGen%, Metaspace%, YGC, FGC, FGCT, GCT

  HEAP_USED_MB=$(jmap -histo:live "${PAYMENT_PID}" 2>/dev/null \
    | awk '/Total/{printf "%.1f", $3/1048576}')

  echo "${CAPTURE_TS},${PAYMENT_PID},${JVM_STATS},${HEAP_USED_MB}" \
    >> /var/log/capacity/jvm_heap_trend.csv
fi
```

**CSV output columns:**
```
timestamp | pid | eden_pct | oldgen_pct | metaspace_pct | ygc | fgc | fgct | gct | total_heap_live_mb
```

**What to watch week-over-week:**
- `oldgen_pct` climbing between snapshots → heap leak confirmed
- `fgc` count increasing → GC struggling to reclaim
- `total_heap_live_mb` approaching 4096 → `-Xmx4g` ceiling, OOM imminent

> ⚠️ Note: `jmap -histo:live` triggers a full GC pause — safe for weekly trend capture, but don't run it during peak payment processing windows. Schedule during your lowest-traffic hour.

## @karthik-zippy

```
Network tower deep dive 
---
DB connections from vm-app grew steadily from 2.1 to 7.3 over 90 days with zero variance.

1. From a network perspective, what TCP-level evidence (not application-level)
   would confirm connections are not being closed cleanly? What ss or netstat
   command would show lingering TCP connections in CLOSE_WAIT state?
2. CLOSE_WAIT state specifically indicates which side failed to close the connection
   — the client (vm-app) or server (vm-db)? Explain the TCP state machine reasoning.
3. Design a network-level early warning: what threshold on CLOSE_WAIT connection
   count would indicate a leak forming, well before the PostgreSQL connection
   count itself becomes concerning?

```

## Copilot

## Network Tower Deep Dive — TCP Connection Leak Analysis

---

### 1. TCP-Level Evidence & Commands

**What to look for — not application logs, pure TCP state:**

A clean connection close requires both sides to exchange `FIN`/`ACK` pairs (4-way teardown). When the application fails to call `connection.close()`, the socket lingers in **CLOSE_WAIT** on the side that received the `FIN` but never sent its own.

**Commands:**

```bash
# ── Primary: CLOSE_WAIT connections to PostgreSQL (port 5432) ──────────────
ss -tnp state close-wait dst <vm-db-ip>:5432

# ── Full breakdown of all TCP states to vm-db ──────────────────────────────
ss -tnp dst <vm-db-ip> | awk 'NR==1 || /5432/'

# ── Count by state (your weekly trend number) ──────────────────────────────
ss -tn dst <vm-db-ip>:5432 | awk 'NR>1 {print $1}' | sort | uniq -c | sort -rn

# ── Show owning PID/process (confirm it's the payment service) ──────────────
ss -tnp state close-wait dst <vm-db-ip>:5432 | grep -v Netid

# ── TIME_WAIT also matters — shows connections closed correctly by app ───────
ss -tn state time-wait dst <vm-db-ip>:5432 | wc -l
# If CLOSE_WAIT >> TIME_WAIT, the app is the problem, not the server
```

**What the output tells you:**

| State count pattern | Interpretation |
|---|---|
| `CLOSE_WAIT` growing, `TIME_WAIT` near zero | App never calling `close()` — **leak confirmed** |
| `TIME_WAIT` present, `CLOSE_WAIT` absent | Clean closes, server-side pooler may be recycling |
| `ESTABLISHED` count matches PostgreSQL `pg_stat_activity` | Healthy — connections match what app thinks it has |
| `ESTABLISHED` > `pg_stat_activity` active queries | Ghost connections — held open but idle |

```bash
# ── Cross-check: TCP ESTABLISHED vs PostgreSQL's view ──────────────────────
# Run on vm-app:
ss -tn state established dst <vm-db-ip>:5432 | wc -l

# Run on vm-db (psql):
psql -c "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"

# If vm-app TCP count > pg_stat_activity count → TCP layer is lying to the app
# (connections not being tracked properly by the pool)
```

---

### 2. CLOSE_WAIT — Which Side Failed? The TCP State Machine Answer

**CLOSE_WAIT always means the local side (vm-app) failed to close.**

Here is the exact state machine reasoning:

```
vm-app (client)              vm-db (server / PostgreSQL)
─────────────────            ───────────────────────────
ESTABLISHED                  ESTABLISHED
                             
                  ←─ FIN ─── (server decides to close, e.g. idle timeout)
                             
CLOSE_WAIT ◄───────────────  FIN_WAIT_1
  │
  │  Application should now call close() / send its own FIN
  │  If it doesn't → socket STAYS in CLOSE_WAIT indefinitely
  │
  └─ FIN ──►               FIN_WAIT_2 → TIME_WAIT → CLOSED
  
LAST_ACK → CLOSED
```

**The critical rule:**
> `CLOSE_WAIT` = *"I received a FIN from the remote side, acknowledged it, and am now waiting for my own application to tell me to close."*

The socket moves out of `CLOSE_WAIT` only when the **application calls `close()`** on the file descriptor. If the Java payment service:
- Has a connection in a pool that's marked "available" but the underlying socket received a FIN (e.g. PostgreSQL's `tcp_keepalives_idle` fired, or a network device timed out the flow)
- And the pool doesn't detect this (no validation query, no `testOnBorrow`)

Then the socket sits in `CLOSE_WAIT` **forever**, and the pool hands it back to the next transaction — which fails with `broken pipe` or `connection reset`, often misread as a transient error rather than a leak symptom.

**Why vm-db is NOT the problem here:**
- vm-db's side transitions to `FIN_WAIT_1 → FIN_WAIT_2 → TIME_WAIT → CLOSED`
- `TIME_WAIT` is self-clearing (lasts `2×MSL`, typically 60–120s)
- vm-db has already moved on — vm-app is holding the ghost

---

### 3. Network-Level Early Warning Threshold Design

**The goal:** catch the leak at TCP layer before PostgreSQL's `max_connections` becomes the constraint.

```bash
# ── Canary metric: CLOSE_WAIT count on port 5432 from vm-app ───────────────
CW_COUNT=$(ss -tn state close-wait dst <vm-db-ip>:5432 | grep -c 5432)
```

**Threshold design — three tiers:**

| Tier | CLOSE_WAIT Count | Meaning | Action |
|---|---|---|---|
| ✅ **Baseline** | 0–2 | Normal transient teardown | No action |
| 🟡 **Warn** | **≥ 3, sustained >5 min** | Pool not recycling properly | Page on-call, check pool config |
| 🔴 **Alert** | **≥ 5** | Active leak — connections accumulating | Immediate — restart pool, investigate |
| 💀 **Critical** | **≥ 8** | Approaching PostgreSQL headroom | Emergency — service impact imminent |

**Why these numbers relative to your data:**
- Current PostgreSQL count: **7.3** (growing at 0.058/day)
- PostgreSQL `max_connections` ceiling: **20**
- Headroom remaining: **~12.7 connections**
- A CLOSE_WAIT of ≥5 means ≥5 connections are held at TCP layer that PostgreSQL may still count as `idle` in `pg_stat_activity` — so your *effective* headroom is `20 − 7.3 − CW_count`

**Add this block to `trend-capture.sh`:**

```bash
# ── Weekly CLOSE_WAIT snapshot ─────────────────────────────────────────────
VM_DB_IP="<vm-db-private-ip>"
CAPTURE_TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

CW_COUNT=$(ss -tn state close-wait dst "${VM_DB_IP}":5432 2>/dev/null \
  | grep -c '5432' || echo 0)

EST_COUNT=$(ss -tn state established dst "${VM_DB_IP}":5432 2>/dev/null \
  | grep -c '5432' || echo 0)

TW_COUNT=$(ss -tn state time-wait dst "${VM_DB_IP}":5432 2>/dev/null \
  | grep -c '5432' || echo 0)

echo "${CAPTURE_TS},${CW_COUNT},${EST_COUNT},${TW_COUNT}" \
  >> /var/log/capacity/tcp_state_trend.csv

# Early warning trigger
if [ "${CW_COUNT}" -ge 3 ]; then
  logger -t capacity-warn \
    "CLOSE_WAIT threshold breached: ${CW_COUNT} connections to ${VM_DB_IP}:5432"
fi
```

**CSV columns:** `timestamp | close_wait | established | time_wait`

**The ratio that matters most:**
```
leak_ratio = CLOSE_WAIT / (CLOSE_WAIT + TIME_WAIT)
```
- Ratio near **0** → connections closing cleanly
- Ratio near **1** → almost nothing closing cleanly → **connection leak confirmed at TCP layer**, independent of anything the application logs say

## @karthik-zippy

```
DB connections grew monotonically from 2.1 to 7.3 average over 90 days on a
PostgreSQL 14 instance with max_connections=20.

1. Write the exact SQL query to identify connections that have been open the
   LONGEST without any query activity — the best indicator of leaked connections.
2. What does pg_stat_activity show for backend_start vs query_start that would
   distinguish 'leaked idle connection from 3 days ago' vs 'normal idle connection
   from 30 seconds ago waiting for the next request'?
3. If you confirmed a connection pool leak in the application, what is the
   PostgreSQL-side mitigation that buys time while the application bug is fixed
   WITHOUT requiring an application redeploy?
4. Write the exact SQL or configuration to implement that mitigation.
```

## Copilot

## PostgreSQL Deep Dive — Connection Leak Identification & Mitigation

---

### 1. Exact SQL — Longest Idle Connections (Leak Candidates)

```sql
-- ── Leaked connection candidates: idle longest with no recent query activity ──
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    backend_type,
    state,
    backend_start,
    query_start,
    state_change,
    -- How long the backend process has existed
    now() - backend_start                          AS backend_age,
    -- How long since the last query finished / state last changed
    now() - state_change                           AS idle_duration,
    -- How long since ANY query activity (NULL if never ran a query)
    now() - query_start                            AS since_last_query,
    -- The last query run on this connection (crucial for leak ID)
    left(query, 120)                               AS last_query_snippet
FROM pg_stat_activity
WHERE
    datname = current_database()
    AND state IN ('idle', 'idle in transaction')   -- active queries are fine
    AND pid <> pg_backend_pid()                    -- exclude this session
ORDER BY
    idle_duration DESC NULLS LAST;                 -- longest idle first
```

**Add this filter to isolate high-confidence leaks:**

```sql
-- ── High-confidence leak filter: idle > 10 minutes ─────────────────────────
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    backend_start,
    now() - backend_start   AS backend_age,
    now() - state_change    AS idle_duration,
    left(query, 120)        AS last_query
FROM pg_stat_activity
WHERE
    datname    = current_database()
    AND state  IN ('idle', 'idle in transaction')
    AND pid    <> pg_backend_pid()
    AND now() - state_change > interval '10 minutes'  -- tune to your pool timeout
ORDER BY
    idle_duration DESC;
```

**Weekly trend count — add to `trend-capture.sh`:**

```sql
-- ── Snapshot count for trending (pipe into CSV) ─────────────────────────────
SELECT
    now()                                           AS captured_at,
    count(*)                                        AS total_connections,
    count(*) FILTER (WHERE state = 'idle')          AS idle_count,
    count(*) FILTER (
        WHERE state = 'idle'
        AND now() - state_change > interval '5 minutes'
    )                                               AS idle_over_5min,
    count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn
FROM pg_stat_activity
WHERE datname = current_database()
AND   pid    <> pg_backend_pid();
```

---

### 2. `backend_start` vs `query_start` — Reading the Leak Signature

These two timestamps tell completely different stories:

| Column | What it records | Resets on? |
|---|---|---|
| `backend_start` | When the OS process for this connection was created | Never — process lifetime |
| `query_start` | When the **current or last query** began | Each new query |
| `state_change` | When `state` last changed (e.g. active→idle) | Each state transition |

**Leaked idle connection from 3 days ago:**

```
pid           │ 18432
state         │ idle
backend_start │ 2024-03-22 09:14:02  ← process created 3 days ago
query_start   │ 2024-03-22 09:14:09  ← last query ran at startup, never again
state_change  │ 2024-03-22 09:14:09  ← has been idle for 3 days straight
backend_age   │ 3 days 04:17:33
idle_duration │ 3 days 04:17:26      ← nearly equal to backend_age = LEAK
last_query    │ SET application_name = 'HikariPool-1'
```

> **Diagnostic rule:** `idle_duration ≈ backend_age` means the connection has done virtually nothing since it was opened. It was grabbed from somewhere and never returned. The last query being a pool handshake (`SET`, `SELECT 1`, `SET application_name`) confirms it was opened by the pool and never used.

**Normal idle connection waiting for next request:**

```
pid           │ 18901
state         │ idle
backend_start │ 2024-03-25 11:02:17  ← created recently, part of active pool
query_start   │ 2024-03-25 13:17:44  ← ran a query 30 seconds ago
state_change  │ 2024-03-25 13:17:44  ← went idle 30 seconds ago
backend_age   │ 2 hours 15 minutes
idle_duration │ 00:00:31             ← tiny idle gap = healthy pool connection
last_query    │ UPDATE payments SET status = $1 WHERE id = $2
```

> **Diagnostic rule:** `backend_age` >> `idle_duration` means the connection has a history of activity — it's been used recently and is sitting in the pool ready for the next request. This is healthy.

**`idle in transaction` — the dangerous third case:**

```
state         │ idle in transaction
backend_start │ 2024-03-25 08:00:01
query_start   │ 2024-03-25 08:00:04  ← transaction started at 08:00
state_change  │ 2024-03-25 08:00:04  ← and has not moved since
idle_duration │ 5 hours 17 minutes   ← open transaction, holding locks
```

> This is **worse than idle** — it holds row locks and prevents VACUUM. A payment service with long `idle in transaction` is actively blocking other transactions.

---

### 3. PostgreSQL-Side Mitigation — No Redeploy Required

The mitigation is **`idle_in_transaction_session_timeout`** combined with **`tcp_keepalives_idle`** set at the PostgreSQL level. These instruct PostgreSQL itself to terminate connections that have overstayed, buying time while the application bug is fixed.

**Three levers, in order of precision:**

| Parameter | What it kills | Scope |
|---|---|---|
| `idle_in_transaction_session_timeout` | Sessions stuck `idle in transaction` beyond N ms | Most targeted |
| `idle_session_timeout` *(PG14+)* | Sessions in plain `idle` state beyond N ms | Kills leaked idle connections directly |
| `tcp_keepalives_idle` | TCP-level dead connections the app never closed | Network layer safety net |

> `idle_session_timeout` was added in **PostgreSQL 14** — you have it. This is your primary weapon.

---

### 4. Exact SQL / Configuration to Implement

**Option A — Live, no restart required (`ALTER SYSTEM` + `pg_reload_conf`):**

```sql
-- ── Apply without restart — takes effect immediately after reload ────────────

-- Kill plain idle connections held longer than 10 minutes
-- Tune this to slightly above your connection pool's own idle timeout
ALTER SYSTEM SET idle_session_timeout = '10min';

-- Kill 'idle in transaction' connections held longer than 5 minutes
-- Payment transactions should never take 5 minutes — this is safe
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';

-- TCP keepalive: detect dead peers at OS level (seconds)
-- idle=60s, interval=10s, count=3 probes before kill
ALTER SYSTEM SET tcp_keepalives_idle    = 60;
ALTER SYSTEM SET tcp_keepalives_interval = 10;
ALTER SYSTEM SET tcp_keepalives_count   = 3;

-- Apply all the above without a restart
SELECT pg_reload_conf();

-- Verify settings took effect
SELECT name, setting, unit, context
FROM pg_settings
WHERE name IN (
    'idle_session_timeout',
    'idle_in_transaction_session_timeout',
    'tcp_keepalives_idle',
    'tcp_keepalives_interval',
    'tcp_keepalives_count'
);
```

**Option B — Per-role (surgical — only affects the payment service user):**

```sql
-- ── Scope timeouts to the payment service role only ─────────────────────────
-- Doesn't affect DBA sessions, monitoring users, or other services

ALTER ROLE payment_svc
    SET idle_session_timeout            = '10min'
    SET idle_in_transaction_session_timeout = '5min';

-- No reload needed for ALTER ROLE — applies to new connections immediately
-- Existing leaked connections: terminate manually or wait for next connect cycle
```

**Option C — Manually terminate current leaks immediately:**

```sql
-- ── One-shot: terminate all connections idle > 10 minutes RIGHT NOW ─────────
-- Run this after setting the timeouts to clear the existing backlog

SELECT
    pg_terminate_backend(pid),
    pid,
    usename,
    now() - state_change AS idle_for,
    left(query, 80)      AS last_query
FROM pg_stat_activity
WHERE
    datname  = current_database()
    AND state = 'idle'
    AND pid  <> pg_backend_pid()
    AND now() - state_change > interval '10 minutes'
ORDER BY idle_for DESC;
```

> ⚠️ **`pg_terminate_backend` sends SIGTERM** — the connection gets a clean `ERROR: terminating connection due to administrator command` which the pool *should* handle gracefully by reopening. Test with one connection first if you're cautious.

**Verify the mitigation is working (add to trend-capture.sh):**

```sql
-- ── Confirm no long-idle connections survive after mitigation ────────────────
SELECT
    now()                                                AS checked_at,
    max(now() - state_change) FILTER (WHERE state = 'idle')
                                                         AS longest_idle,
    max(now() - state_change) FILTER (WHERE state = 'idle in transaction')
                                                         AS longest_idle_in_txn,
    count(*) FILTER (WHERE now() - state_change > interval '10 minutes'
                     AND state = 'idle')                 AS leaked_count
FROM pg_stat_activity
WHERE datname = current_database()
AND   pid    <> pg_backend_pid();
-- After mitigation: longest_idle should never exceed your timeout value
-- leaked_count should be 0
```

---

**Summary of what this mitigation achieves without a redeploy:**

```
Before mitigation:  leaked connections accumulate indefinitely → hit max_connections=20
After mitigation:   PostgreSQL auto-terminates idle connections at 10min → pool
                    never accumulates beyond ~2 connections above active workload
                    
Buys you:  (20 - 7.3) / 0.058 per day = ~150 days of headroom
           compressed to: active_connections_only + natural pool churn
           effectively resetting the trajectory while dev fixes the leak
```

## @karthik-zippy

```
DB connections grew monotonically from 2.1 to 7.3 average over 90 days on a
PostgreSQL 14 instance with max_connections=20.

1. Write the exact SQL query to identify connections that have been open the
   LONGEST without any query activity — the best indicator of leaked connections.
2. What does pg_stat_activity show for backend_start vs query_start that would
   distinguish 'leaked idle connection from 3 days ago' vs 'normal idle connection
   from 30 seconds ago waiting for the next request'?
3. If you confirmed a connection pool leak in the application, what is the
   PostgreSQL-side mitigation that buys time while the application bug is fixed
   WITHOUT requiring an application redeploy?
4. Write the exact SQL or configuration to implement that mitigation.
```

## Copilot

The answer is identical to what I just gave — same data, same questions. Here is the clean canonical version for your runbook:

---

## PostgreSQL Connection Leak — Identification & Mitigation Runbook

---

### 1. Exact SQL — Longest Idle Connections (Leak Candidates)

```sql
-- ── All idle connections, longest-held first ────────────────────────────────
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    backend_start,
    query_start,
    state_change,
    now() - backend_start                              AS backend_age,
    now() - state_change                               AS idle_duration,
    now() - query_start                                AS since_last_query,
    left(query, 120)                                   AS last_query_snippet
FROM pg_stat_activity
WHERE
    datname  = current_database()
    AND state IN ('idle', 'idle in transaction')
    AND pid  <> pg_backend_pid()
ORDER BY
    idle_duration DESC NULLS LAST;
```

```sql
-- ── High-confidence leak filter: idle > 10 minutes ──────────────────────────
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    now() - backend_start   AS backend_age,
    now() - state_change    AS idle_duration,
    left(query, 120)        AS last_query
FROM pg_stat_activity
WHERE
    datname  = current_database()
    AND state IN ('idle', 'idle in transaction')
    AND pid  <> pg_backend_pid()
    AND now() - state_change > interval '10 minutes'
ORDER BY
    idle_duration DESC;
```

```sql
-- ── Weekly trend snapshot — append output to CSV in trend-capture.sh ────────
SELECT
    now()                                                       AS captured_at,
    count(*)                                                    AS total_connections,
    count(*) FILTER (WHERE state = 'idle')                     AS idle_count,
    count(*) FILTER (
        WHERE state = 'idle'
        AND   now() - state_change > interval '5 minutes'
    )                                                           AS idle_over_5min,
    count(*) FILTER (WHERE state = 'idle in transaction')      AS idle_in_txn
FROM pg_stat_activity
WHERE datname = current_database()
AND   pid    <> pg_backend_pid();
```

---

### 2. `backend_start` vs `query_start` — Reading the Leak Signature

| Column | What it records | Resets on |
|---|---|---|
| `backend_start` | When the OS process was created | Never |
| `query_start` | When the current/last query began | Each new query |
| `state_change` | When `state` last transitioned | Each state change |

**Leaked connection — 3 days old:**

```
pid           │ 18432
state         │ idle
backend_start │ 2024-03-22 09:14:02   ← process born 3 days ago
query_start   │ 2024-03-22 09:14:09   ← only ever ran pool handshake
state_change  │ 2024-03-22 09:14:09   ← idle ever since
backend_age   │ 3 days 04:17:33
idle_duration │ 3 days 04:17:26       ← idle_duration ≈ backend_age = LEAK
last_query    │ SET application_name = 'HikariPool-1'
```

> **Rule:** `idle_duration ≈ backend_age` + last query is a pool handshake (`SET`, `SELECT 1`) = connection was opened by the pool and **never used or returned**.

**Normal idle connection — 30 seconds old:**

```
pid           │ 18901
state         │ idle
backend_start │ 2024-03-25 11:02:17   ← part of active pool, opened hours ago
query_start   │ 2024-03-25 13:17:44   ← ran a real query 30s ago
state_change  │ 2024-03-25 13:17:44   ← went idle 30s ago
backend_age   │ 2 hours 15 minutes
idle_duration │ 00:00:31              ← tiny idle gap vs long backend_age = HEALTHY
last_query    │ UPDATE payments SET status = $1 WHERE id = $2
```

> **Rule:** `backend_age` >> `idle_duration` + last query is real application work = healthy pool connection waiting for next request.

**`idle in transaction` — the dangerous third case:**

```
state         │ idle in transaction
state_change  │ 2024-03-25 08:00:04
idle_duration │ 5 hours 17 minutes    ← open transaction holding row locks
                                         blocking VACUUM, blocking other writers
```

> Worse than a plain idle leak — holds locks. Any `idle in transaction` beyond 5 minutes on a payment service is an incident.

---

### 3. PostgreSQL-Side Mitigation — No Redeploy Required

Three parameters, all settable live via `ALTER SYSTEM` + `pg_reload_conf()`:

| Parameter | Kills | PostgreSQL version |
|---|---|---|
| `idle_session_timeout` | Plain `idle` connections beyond N ms | **PG14+ — you have it** |
| `idle_in_transaction_session_timeout` | `idle in transaction` beyond N ms | PG9.6+ |
| `tcp_keepalives_idle` | TCP-dead connections the app never closed | All versions |

`idle_session_timeout` is your primary weapon here — it directly terminates the leaked idle connections automatically, continuously, without touching the application.

---

### 4. Exact SQL / Configuration

**Option A — System-wide, live, no restart:**

```sql
-- ── Apply immediately, no restart ───────────────────────────────────────────

-- Terminate plain idle connections held > 10 minutes
-- Set slightly above your HikariCP/DBCP idleTimeout so the pool cleans up first
ALTER SYSTEM SET idle_session_timeout                = '10min';

-- Terminate idle-in-transaction connections held > 5 minutes
-- No payment transaction should ever take 5 minutes
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';

-- TCP keepalive: detect dead peers at OS/network level
ALTER SYSTEM SET tcp_keepalives_idle                 = 60;
ALTER SYSTEM SET tcp_keepalives_interval             = 10;
ALTER SYSTEM SET tcp_keepalives_count                = 3;

-- Reload — no restart, takes effect for new and existing sessions
SELECT pg_reload_conf();

-- Verify
SELECT name, setting, unit, context
FROM   pg_settings
WHERE  name IN (
    'idle_session_timeout',
    'idle_in_transaction_session_timeout',
    'tcp_keepalives_idle',
    'tcp_keepalives_interval',
    'tcp_keepalives_count'
);
```

**Option B — Scoped to payment service role only (surgical, preferred):**

```sql
-- ── Affects only the payment_svc role, not DBA/monitoring sessions ───────────
ALTER ROLE payment_svc
    SET idle_session_timeout                = '10min'
    SET idle_in_transaction_session_timeout = '5min';

-- No reload needed — applies to new connections from this role immediately
-- Does NOT kill existing leaked connections — use Option C for that
```

**Option C — Terminate existing leaks right now (one-shot cleanup):**

```sql
-- ── Immediate cleanup of current backlog ────────────────────────────────────
SELECT
    pg_terminate_backend(pid),
    pid,
    usename,
    now() - state_change   AS idle_for,
    left(query, 80)        AS last_query
FROM pg_stat_activity
WHERE
    datname  = current_database()
    AND state = 'idle'
    AND pid  <> pg_backend_pid()
    AND now() - state_change > interval '10 minutes'
ORDER BY
    idle_for DESC;
```

> ⚠️ `pg_terminate_backend` sends SIGTERM — the client gets `ERROR: terminating connection due to administrator command`. A correctly configured pool (HikariCP, c3p0, pgBouncer) will catch this and reopen. Test on one connection first.

**Option D — Verify mitigation is holding (add to `trend-capture.sh`):**

```sql
-- ── Weekly confirmation that no long-idle connections survive ────────────────
SELECT
    now()                                                           AS checked_at,
    max(now() - state_change)
        FILTER (WHERE state = 'idle')                              AS longest_idle,
    max(now() - state_change)
        FILTER (WHERE state = 'idle in transaction')               AS longest_idle_in_txn,
    count(*)
        FILTER (WHERE state = 'idle'
                AND   now() - state_change > interval '10 minutes') AS leaked_count
FROM pg_stat_activity
WHERE datname = current_database()
AND   pid    <> pg_backend_pid();

-- Target state after mitigation:
--   longest_idle     < '00:10:00'
--   longest_idle_in_txn < '00:05:00'
--   leaked_count     = 0
```

---

**Net effect of this mitigation on your trajectory:**

```
Before:  connections accumulate at 0.058/day → hit max_connections=20 by ~Aug 22
After:   PostgreSQL auto-culls idle connections at 10min → leaked connections
         never persist across the weekly snapshot window → trend line flattens
         while dev team hunts and fixes the pool misconfiguration
```

The timeout values to tune against your pool config:

```
HikariCP:  idleTimeout (default 10min) → set idle_session_timeout to idleTimeout + 2min
           (let the pool try to close it first, PG is the safety net)
pgBouncer: server_idle_timeout          → same logic applies
```

## @karthik-zippy

```
You are a senior infrastructure on-call engineer and capacity planning specialist.

Our predictive monitoring script just produced the forecast below for a
PostgreSQL database supporting a payment service. Analyse the actual data —
do not rely on my summary alone.

Static alert threshold: max_connections=16/20 (CRITICAL alert fires at this level)
Current connections: 13/20 (static alert has NOT fired yet)

Provide:
1. An immediate investigation checklist (next 30 minutes) to find the leak source
2. A short-term mitigation that buys time without requiring a deployment
3. A medium-term fix assuming the leak is confirmed in application code
4. The exact monitoring change needed so this trend triggers an alert
   automatically next time, rather than requiring a manual predictive-check run
5. Based on the raw data below, do you agree with the script's CRITICAL/8-day
   forecast, or would you weight the evidence differently? Explain your reasoning.

--- PREDICTIVE-CHECK.SH OUTPUT ---
=== Predictive Capacity Forecast Thu Jun 18 06:34:00 UTC 2026 ===
Data points: 13  (using last 5 for trend)

CPU %            current=3.60     slope/day=0.00714    (last 5 pts)  12096 days  OK
Memory %         current=26.30    slope/day=0.10429    (last 5 pts)  611 days  OK
Disk %           current=34.40    slope/day=0.11000    (last 5 pts)  460 days  OK
DB Connections   current=7.30     slope/day=0.05714    (last 5 pts)  152 days  OK

--- RAW TREND DATA (last 10-15 rows is enough) ---
epoch_day,timestamp,cpu_pct,mem_pct,disk_pct,db_connections
20532,2026-03-20,3.1,17.8,12.4,2.1
20539,2026-03-27,3.2,18.6,15.1,2.6
20546,2026-04-03,3.0,19.1,17.8,3.0
20553,2026-04-10,3.3,19.8,20.2,3.4
20560,2026-04-17,3.2,20.4,22.9,3.9
20567,2026-04-24,3.4,21.2,25.6,4.3
20574,2026-05-01,3.3,21.9,27.8,4.8
20581,2026-05-08,3.5,22.6,29.9,5.2
20588,2026-05-15,3.4,23.4,31.2,5.7
20595,2026-05-22,3.6,24.1,32.8,6.1
20602,2026-05-29,3.5,24.8,33.6,6.5
20609,2026-06-05,3.7,25.6,34.1,6.9
20616,2026-06-12,3.6,26.3,34.4,7.3
```

## Copilot

## On-Call Incident Response — PostgreSQL Connection Leak Forecast Analysis

---

### 5. Raw Data Analysis First — Do I Agree With the Script?

**No. The script is significantly wrong. This is the most important finding.**

Let me work through the raw data directly:

**Reconstructing the actual DB connections slope:**

| epoch_day | date | db_connections | weekly_delta |
|---|---|---|---|
| 20532 | 2026-03-20 | 2.1 | — |
| 20539 | 2026-03-27 | 2.6 | +0.5 |
| 20546 | 2026-04-03 | 3.0 | +0.4 |
| 20553 | 2026-04-10 | 3.4 | +0.4 |
| 20560 | 2026-04-17 | 3.9 | +0.5 |
| 20567 | 2026-04-24 | 4.3 | +0.4 |
| 20574 | 2026-05-01 | 4.8 | +0.5 |
| 20581 | 2026-05-08 | 5.2 | +0.4 |
| 20588 | 2026-05-15 | 5.7 | +0.5 |
| 20595 | 2026-05-22 | 6.1 | +0.4 |
| 20602 | 2026-05-29 | 6.5 | +0.4 |
| 20609 | 2026-06-05 | 6.9 | +0.4 |
| 20616 | 2026-06-12 | 7.3 | +0.4 |

```
Full 90-day slope:  (7.3 - 2.1) / 84 days = 0.0619/day
Last-5-point slope: (7.3 - 6.1) / 28 days = 0.0429/day  ← script used this

Script reported:    0.05714/day  ← doesn't match either calculation precisely
```

**The script's slope calculation appears to have a rounding or window error.** But more critically:

**The script's current value is WRONG.**

The script reports `current=7.30` and forecasts **152 days to threshold**. But the problem statement says **current connections = 13/20**. The raw data ends at 7.3 on 2026-06-12 — today is 2026-06-18, six days later. If connections have jumped from 7.3 to 13 in 6 days, that is not linear growth. That is a step-change event.

**Two scenarios:**

| Scenario | Implication |
|---|---|
| **A: 13 is real and current** | Growth has accelerated sharply — not 0.057/day but ~0.95/day recently. CRITICAL in ~3 days, not 152. |
| **B: Script ran against stale data, 7.3 is still current** | 152-day forecast is plausible but still wrong — full-history slope gives 8.7 connections to threshold at 0.062/day = **~140 days** |

**In either case, the script's 152-day / OK status is wrong:**
- If current = 13: **alert should be firing now**, breach in days
- If current = 7.3: trend is perfectly monotonic with zero variance — a pure linear fit across all 13 points, which means the last-5-point window **understates** the persistent structural rate

**The zero-variance monotonic growth is itself the critical signal the script missed entirely.** A slope calculation on 5 points of a perfectly linear series is no more reliable than the full series — and the script gave no weight to the fact that this has **never once deviated** in 90 days.

> **My assessment: CRITICAL — act now, not in 152 days.** If the 13/20 figure is accurate, you are 3 connections from a hard alert and likely hours from impact during any peak traffic window.

---

### 1. Immediate Investigation Checklist — Next 30 Minutes

**T+0 — Establish ground truth (first 5 minutes)**

```bash
# ── Confirm actual current connection count ──────────────────────────────────
psql -h vm-db -U postgres -c "
SELECT count(*), state
FROM pg_stat_activity
WHERE datname = 'payments'
GROUP BY state
ORDER BY count DESC;"

# ── Is it accelerating? Check last connection open time ─────────────────────
psql -h vm-db -U postgres -c "
SELECT pid, backend_start, state, now() - backend_start AS age
FROM pg_stat_activity
WHERE datname = 'payments'
AND   pid <> pg_backend_pid()
ORDER BY backend_start ASC
LIMIT 20;"

# ── TCP confirmation on vm-app ───────────────────────────────────────────────
ss -tn state close-wait dst <vm-db-ip>:5432 | grep -c 5432
ss -tn state established dst <vm-db-ip>:5432 | grep -c 5432
```

**T+5 — Identify the leak source**

```bash
# ── Which application_name / client_addr is holding the most connections ─────
psql -h vm-db -U postgres -c "
SELECT
    application_name,
    client_addr,
    state,
    count(*)                        AS conn_count,
    max(now() - backend_start)      AS oldest_conn,
    max(now() - state_change)       AS longest_idle
FROM pg_stat_activity
WHERE datname = 'payments'
AND   pid <> pg_backend_pid()
GROUP BY application_name, client_addr, state
ORDER BY conn_count DESC;"
```

```bash
# ── Find leaked idle connections (the smoking gun) ───────────────────────────
psql -h vm-db -U postgres -c "
SELECT
    pid,
    application_name,
    client_addr,
    state,
    now() - backend_start   AS backend_age,
    now() - state_change    AS idle_duration,
    left(query, 100)        AS last_query
FROM pg_stat_activity
WHERE datname = 'payments'
AND   state IN ('idle', 'idle in transaction')
AND   now() - state_change > interval '5 minutes'
AND   pid <> pg_backend_pid()
ORDER BY idle_duration DESC;"
```

**T+10 — Check for acceleration (did something change recently?)**

```bash
# ── Recent deployments or config changes ────────────────────────────────────
# On vm-app:
journalctl -u payment-service --since "2026-06-12" | grep -E "start|restart|config"
git -C /opt/payment-service log --oneline --since="2026-06-12"

# ── JVM pool metrics if actuator is exposed ──────────────────────────────────
curl -s http://localhost:8080/actuator/metrics/hikaricp.connections \
  | python3 -m json.tool

curl -s http://localhost:8080/actuator/metrics/hikaricp.connections.active \
  | python3 -m json.tool
```

**T+20 — Confirm leak pattern**

```bash
# ── Watch connections open in real time (10 samples, 10s apart) ─────────────
for i in $(seq 1 10); do
  echo -n "$(date -u +%H:%M:%S)  connections: "
  psql -h vm-db -U postgres -tAc \
    "SELECT count(*) FROM pg_stat_activity WHERE datname='payments';"
  sleep 10
done

# ── Are connections growing monotonically even now? ─────────────────────────
# Two rising samples 10s apart with no drop = active leak confirmed
```

---

### 2. Short-Term Mitigation — No Deployment Required

**Execute in this order — each step is independently safe:**

**Step 1 — Terminate existing leaked connections immediately**

```sql
-- Dry run first — see what would be killed
SELECT pid, usename, application_name,
       now() - state_change AS idle_for,
       left(query, 80)      AS last_query
FROM pg_stat_activity
WHERE datname  = 'payments'
AND   state    = 'idle'
AND   pid     <> pg_backend_pid()
AND   now() - state_change > interval '5 minutes'
ORDER BY idle_for DESC;

-- Execute termination
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname  = 'payments'
AND   state    = 'idle'
AND   pid     <> pg_backend_pid()
AND   now() - state_change > interval '5 minutes';
```

**Step 2 — Set automatic leak-killing timeouts (live, no restart)**

```sql
-- PostgreSQL auto-kills future leaks — safety net stays in place
ALTER SYSTEM SET idle_session_timeout                = '10min';
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
ALTER SYSTEM SET tcp_keepalives_idle                 = 60;
ALTER SYSTEM SET tcp_keepalives_interval             = 10;
ALTER SYSTEM SET tcp_keepalives_count                = 3;

SELECT pg_reload_conf();

-- Verify
SELECT name, setting, unit FROM pg_settings
WHERE name IN (
    'idle_session_timeout',
    'idle_in_transaction_session_timeout',
    'tcp_keepalives_idle'
);
```

**Step 3 — If count is still ≥ 12 after Step 1/2, cap connections at role level**

```sql
-- Hard cap: payment service cannot hold more than 10 connections
-- Forces pool to recycle rather than grow unbounded
ALTER ROLE payment_svc CONNECTION LIMIT 10;

-- Revert once leak is fixed:
-- ALTER ROLE payment_svc CONNECTION LIMIT -1;
```

**Expected outcome:** connection count drops to active workload baseline within one `idle_session_timeout` window (10 minutes), then stays flat.

---

### 3. Medium-Term Fix — Application Code

**The fix target depends on what the investigation found:**

**If HikariCP pool is misconfigured (most likely given monotonic growth):**

```yaml
# application.yml — correct pool configuration
spring:
  datasource:
    hikari:
      # Must be less than PostgreSQL's idle_session_timeout
      idle-timeout: 600000          # 10 minutes — return idle connections to pool
      max-lifetime: 1800000         # 30 minutes — recycle all connections
      connection-timeout: 30000     # 30 seconds — fail fast on new connection
      maximum-pool-size: 10         # hard ceiling below max_connections=20
      minimum-idle: 2               # don't hold more than 2 idle connections
      keepalive-time: 60000         # send keepalive before tcp_keepalives_idle fires
      # Validation — detect and discard broken connections before use
      connection-test-query: SELECT 1
```

**If connection leak in code (not returned to pool):**

```java
// WRONG — connection obtained but never guaranteed to close
Connection conn = dataSource.getConnection();
conn.prepareStatement(sql).execute();
// exception here = connection never returned

// CORRECT — try-with-resources guarantees close() on all paths
try (Connection conn = dataSource.getConnection();
     PreparedStatement ps = conn.prepareStatement(sql)) {
    ps.execute();
}   // conn.close() called here even on exception
```

**Verification after fix is deployed:**

```sql
-- Run 24h after deployment — should show flat or declining connection count
SELECT
    date_trunc('hour', backend_start)   AS hour,
    count(*)                            AS connections_opened
FROM pg_stat_activity
WHERE datname = 'payments'
GROUP BY 1
ORDER BY 1 DESC
LIMIT 48;
```

---

### 4. Monitoring Change — Trend-Based Alert

**The core problem:** your static alert fires at 16/20. But a perfectly monotonic trend reaches 13/20 **before the alert fires** — the trend is the signal, not the threshold.

**Add this to your monitoring pipeline:**

```bash
#!/usr/bin/env bash
# ── trend-alert.sh — slope-based alert for DB connections ───────────────────
# Add to cron: */30 * * * * /opt/monitoring/trend-alert.sh

DB_HOST="vm-db"
DB_NAME="payments"
ALERT_THRESHOLD=16
WARN_THRESHOLD=12
DAYS_WARN=30        # alert if threshold breached within N days
DAYS_CRITICAL=7     # critical if threshold breached within N days

CURRENT=$(psql -h "$DB_HOST" -U postgres -tAc \
  "SELECT count(*) FROM pg_stat_activity WHERE datname='${DB_NAME}' AND pid <> pg_backend_pid();")

# Capture 5 recent datapoints and compute slope
SLOPE=$(psql -h "$DB_HOST" -U postgres -tAc "
  SELECT regr_slope(conn_count, extract(epoch FROM captured_at) / 86400.0)
  FROM (
    SELECT captured_at, conn_count
    FROM connection_trend_log
    WHERE datname = '${DB_NAME}'
    ORDER BY captured_at DESC
    LIMIT 5
  ) sub;")

# Days to threshold from current value and slope
if (( $(echo "$SLOPE > 0" | bc -l) )); then
  DAYS_TO_ALERT=$(echo "scale=1; ($ALERT_THRESHOLD - $CURRENT) / $SLOPE" | bc)
else
  DAYS_TO_ALERT=9999
fi

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) current=${CURRENT} slope=${SLOPE}/day days_to_alert=${DAYS_TO_ALERT}"

# Fire alerts
if (( $(echo "$DAYS_TO_ALERT < $DAYS_CRITICAL" | bc -l) )); then
  logger -t db-capacity "CRITICAL: DB connections will breach ${ALERT_THRESHOLD} in ${DAYS_TO_ALERT} days (current=${CURRENT}, slope=${SLOPE}/day)"
  # Insert your PagerDuty / alertmanager call here
elif (( $(echo "$DAYS_TO_ALERT < $DAYS_WARN" | bc -l) )); then
  logger -t db-capacity "WARN: DB connections will breach ${ALERT_THRESHOLD} in ${DAYS_TO_ALERT} days (current=${CURRENT}, slope=${SLOPE}/day)"
fi

# Also fire on static threshold (belt and braces)
if (( CURRENT >= WARN_THRESHOLD )); then
  logger -t db-capacity "WARN: DB connections currently ${CURRENT}/${ALERT_THRESHOLD} — static threshold"
fi
```

**If using Prometheus + Alertmanager, add these rules:**

```yaml
# ── prometheus/rules/db_connections.yml ─────────────────────────────────────
groups:
  - name: db_connection_leak
    rules:

      # Static threshold — belt and braces
      - alert: DBConnectionsHigh
        expr: pg_stat_activity_count{datname="payments",state!="idle"} > 12
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "DB connections above 12 ({{ $value }}/20)"

      # Trend-based — fires well before static threshold
      - alert: DBConnectionLeakDetected
        expr: |
          predict_linear(
            pg_stat_activity_count{datname="payments"}[6h], 7 * 86400
          ) > 16
        for: 30m
        labels:
          severity: critical
        annotations:
          summary: >
            DB connections projected to breach 16 within 7 days
            (current={{ $value | humanize }}, projected breach in 7d)

      # Zero-variance monotonic growth — the pattern that matters most
      - alert: DBConnectionMonotonicGrowth
        expr: |
          deriv(pg_stat_activity_count{datname="payments"}[7d]) > 0.04
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: >
            DB connections growing at {{ $value | humanizePercentage }}/day
            with sustained positive slope — possible connection leak
```

> **The `predict_linear` rule is the key change.** It fires when the *projected* value 7 days out exceeds the threshold — giving you a week of lead time instead of zero. This is exactly what your manual predictive-check script does, but automated and continuous.

---

**Summary — what went wrong and what to fix:**

```
What the script got wrong:
  1. Reported current=7.3 when actual current=13 — stale data or wrong source
  2. Used last-5-point window on a perfectly linear series — underweights
     the 90-day structural signal
  3. Gave no weight to zero-variance monotonic growth as a leak indicator
  4. Reported OK/152 days when the situation is CRITICAL/days

What to fix:
  1. Script must read live pg_stat_activity, not cached trend data
  2. Alert on predict_linear() in Prometheus, not just static thresholds
  3. Flag zero-variance monotonic trends explicitly — they indicate
     structural leaks, not load variation, and never self-correct
```
