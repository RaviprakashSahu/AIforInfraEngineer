# Copilot Chat Conversation Export: Cloud capacity planning analysis and recommendations

**User:** @karthik-zippy
**Thread URL:** https://github.com/copilot/c/4568e5df-1550-4558-b9a5-bfa491ceb24c

## @karthik-zippy

```
You are a senior cloud infrastructure capacity planner.
Analyse the following utilisation data and provide:
  1. Current utilisation summary per resource
  2. Trend projection: when will capacity be exhausted at current growth rate?
  3. Right-sizing or tier optimisation recommendations (with cost impact if known)
  4. Recommended alert thresholds to prevent surprise exhaustion

Constraints:
  - State your confidence level for each projection (High / Medium / Low)
  - Flag any assumption you are making about the growth rate
  - Do not recommend premium tiers unless the workload justifies it

--- UTILISATION DATA ---
=== Storage Volume Fill Rate (90-day extract, sampled weekly) ===
Volume: /data/prod on vm-app sda (Standard_LRS, 30GB)

Date         Used (GB)  Free (GB)  Use%   I/O Await (avg)
2024-01-01   6.1        23.9       20%    4ms
2024-01-08   6.8        23.2       23%    4ms
2024-01-15   7.6        22.4       25%    5ms
2024-01-22   8.3        21.7       28%    5ms
2024-01-29   9.1        20.9       30%    5ms
2024-02-05   10.0       20.0       33%    6ms
2024-02-12   11.0       19.0       37%    7ms
2024-02-19   12.0       18.0       40%    7ms
2024-02-26   13.3       16.7       44%    8ms
2024-03-04   14.9       15.1       50%    9ms
2024-03-11   17.1       12.9       57%    12ms
2024-03-18   20.2       9.8        67%    18ms
2024-03-22   23.1       6.9        77%    287ms  <-- I/O spike today (backup collision)

=== Azure Storage Account Breakdown ===
container-hot (archival 2022 data):  198 blobs, 24.6 GB, last accessed: 2023-08-15
container-archive (old reports):     847 blobs,  8.3 GB, last accessed: 2022-11-30
lab-data (synthetic datasets):        12 blobs,  0.4 GB, last accessed: 2024-03-20

=== Current iostat summary ===
sda: %util=99.8%, await=287ms, r/s=24, w/s=890
Note: Backup job running — final-dc-backup, 198/340GB transferred
--- END ---
```

## Copilot

Current situation: `/data/prod` is the immediate risk. It has grown from 6.1 GB to 23.1 GB on a 30 GB disk in ~81 days, leaving only 6.9 GB free, and the current I/O spike appears workload-specific to the running backup rather than evidence that the disk tier is fundamentally too low.

## 1) Current utilisation summary per resource

### A. VM volume `/data/prod` on `vm-app` `sda` (`Standard_LRS`, 30 GB)
- **Capacity:** 30 GB
- **Used:** 23.1 GB
- **Free:** 6.9 GB
- **Utilisation:** **77%**
- **Growth over sample:** 6.1 → 23.1 GB = **+17.0 GB**
- **Average growth rate assumption:** ~**1.47 GB/week** over the full period
- **Recent growth rate:** last 4 intervals accelerated materially:
  - 14.9 → 17.1 = +2.2 GB/week
  - 17.1 → 20.2 = +3.1 GB/week
  - 20.2 → 23.1 in 4 days ≈ **+5.1 GB/week equivalent**
- **Performance note:** historical await mostly **4–18 ms**, but **287 ms today** with `%util=99.8%` and **890 w/s**, coinciding with backup activity.  
  This strongly suggests a **transient backup-write collision**, not a normal steady-state latency baseline.

### B. Azure Storage Account containers
#### `container-hot` (archival 2022 data)
- **198 blobs**
- **24.6 GB**
- **Last accessed:** 2023-08-15
- Likely mis-tiered if truly archival and not being read.

#### `container-archive` (old reports)
- **847 blobs**
- **8.3 GB**
- **Last accessed:** 2022-11-30
- Already aligned to archive-style use case by name; likely low optimisation headroom unless retrieval expectations changed.

#### `lab-data` (synthetic datasets)
- **12 blobs**
- **0.4 GB**
- **Last accessed:** 2024-03-20
- Small footprint; no meaningful capacity or cost concern.

---

## 2) Trend projection: when will capacity be exhausted?

## Projection basis
I am assuming:
1. **Disk growth continues at approximately the recent historical trend**
2. **No cleanup, retention enforcement, or volume expansion occurs**
3. The 2024-03-22 point is representative of real retained growth, not a temporary file surge from the running backup

Because growth is clearly accelerating, a single linear forecast understates risk. I recommend treating the range below as the planning window.

### A. Linear projection using full-sample average
- Remaining free space: **6.9 GB**
- Average growth: **~1.47 GB/week**
- Time to full: **~4.7 weeks**

**Estimated exhaustion:** around **late April 2024**  
**Confidence:** **Medium**

Why not High: the growth curve is not linear; it is accelerating.

### B. Near-term projection using recent growth
Using the last ~2–3 weeks only:
- 14.9 GB on 2024-03-04 to 23.1 GB on 2024-03-22
- Growth = **8.2 GB in 18 days**
- Equivalent = **~3.2 GB/week**

At that rate:
- 6.9 GB free / 3.2 GB per week ≈ **2.2 weeks**

**Estimated exhaustion:** around **early April 2024**  
**Confidence:** **Medium**

### C. Stress case if latest increase includes persistent acceleration
If the latest interval reflects a genuine new run-rate of ~4–5 GB/week:
- Time to full: roughly **1.4–1.7 weeks**

**Estimated exhaustion:** **end of March to very early April 2024**  
**Confidence:** **Low**

This is low confidence because the last reading may be distorted by backup staging or temporary files.

## Practical planning conclusion
Plan as if the volume could exhaust in **~2–5 weeks**, with the most prudent operational assumption being **~2–3 weeks** unless you confirm that recent growth is temporary.

---

## 3) Right-sizing or tier optimisation recommendations

## A. Increase the `/data/prod` disk size soon
### Recommendation
Resize from **30 GB** to at least **64 GB**; consider **128 GB** only if:
- this growth is expected to continue,
- cleanup is not feasible,
- or backup staging/local retention will remain on this disk.

### Why
- 30 GB is already too tight for a volume growing at 1.5–3.2+ GB/week.
- Operating a production data volume above ~80–85% leaves little room for bursts, temp files, logs, or failed backup retries.
- Standard tier still seems acceptable for normal conditions based on historical await.

### Cost impact
Exact Azure cost depends on region and disk SKU, so I won’t fabricate pricing. But generally:
- **30 GB → 64 GB Standard_LRS** is usually a **modest uplift**
- **30 GB → 128 GB** is a more noticeable but still typically moderate increase versus the operational risk of outage

If cost sensitivity is high, **64 GB** is the best first step.

### Confidence
**High**

---

## B. Do not move to premium disk based on this data alone
### Recommendation
**Do not recommend Premium tier yet.**

### Why
- Historical await before the collision was **4–18 ms**, which is reasonable.
- The current **287 ms / 99.8% util** event coincides exactly with a backup job pushing **890 writes/s**.
- This looks like a **workload scheduling/contention problem**, not necessarily a tier deficiency.

### Better action first
- Reschedule `final-dc-backup` to avoid collision with production write peaks
- Check whether backup writes are landing on the same volume as application data/temp files
- Exclude ephemeral data or use streaming/snapshots where possible
- If sustained high await persists outside backup windows, then re-evaluate SKU/tier

### Confidence
**High**

---

## C. Storage account tier optimisation
### 1. `container-hot` should be reviewed for cooler/archival tiering
- **24.6 GB**
- Last accessed **2023-08-15**
- Described as **archival 2022 data**

### Recommendation
Move from hot to **cool** or **archive**, depending on retrieval expectations:
- **Cool** if occasional access is still possible
- **Archive** if rare retrieval is acceptable and restore latency is acceptable

### Cost impact
- Moving long-cold data out of hot tier should reduce monthly storage cost.
- Since this is only **24.6 GB**, the absolute savings will likely be **small**, but it is still correct hygiene.
- Avoid archive if frequent or urgent reads are possible, because retrieval/re-hydration charges can outweigh savings.

### Confidence
**High**

### 2. `container-archive`
- Already appears suited to low-access retention.
- No change recommended unless policy requires deletion after a retention period.

### Confidence
**Medium**

### 3. `lab-data`
- Only **0.4 GB**
- No action needed

### Confidence
**High**

---

## D. Cleanup / retention actions may defer resizing
Before or alongside disk expansion:
- Identify log retention on `/data/prod`
- Check for local backup staging files
- Purge obsolete temp/export/report files
- Move cold application-generated files off VM disk into blob storage
- If backups stage locally, redirect staging to a separate volume or ephemeral workspace

### Cost impact
Potentially better than a tier upgrade because it can:
- delay resize,
- reduce backup duration,
- and lower I/O contention.

### Confidence
**Medium**

---

## 4) Recommended alert thresholds

## A. Capacity alerts for `/data/prod`
Use both **percentage** and **days-to-full** alerts.

### Warning
- **70% used** or **< 9 GB free**
- and/or forecasted full within **30 days**

### High
- **80% used** or **< 6 GB free**
- and/or forecasted full within **14 days**

### Critical
- **85–90% used** or **< 3 GB free**
- and/or forecasted full within **7 days**

Given the current size, I would explicitly alert on **free GB**, not just percentage, because percentage on a small disk can hide how little real space remains.

### Confidence
**High**

---

## B. I/O performance alerts for `sda`
Because today’s spike is likely backup-related, set alerts that distinguish sustained degradation from temporary batch windows.

### Suggested thresholds
- **Warning:** await > **25 ms** for 15 minutes
- **High:** await > **50 ms** for 15 minutes
- **Critical:** await > **100 ms** for 10 minutes
- `%util` warning if > **85%** sustained for 15 minutes
- `%util` critical if > **95%** sustained for 10 minutes outside backup window

If backup windows are known and accepted, either:
- suppress alerts during approved backup windows, or
- use separate thresholds for backup vs non-backup periods.

### Confidence
**Medium**
Reason: ideal thresholds vary by workload sensitivity.

---

## C. Blob tiering hygiene alerts
For storage accounts:
- Alert/report monthly on blobs in **hot tier not accessed for >90 days**
- Alert/report quarterly on archive candidates not accessed for **>180 days**
- Alert if total hot-tier footprint of cold data grows by **>20% month-over-month**

### Confidence
**High**

---

## Recommended action plan

### Immediate (this week)
1. **Validate whether the 2024-03-22 jump includes temporary backup/staging files**
2. **Resize `/data/prod` from 30 GB to 64 GB**
3. **Reschedule or isolate `final-dc-backup`** to avoid write contention
4. **Set alerts at 80%, 85%, and <3 GB free**

### Near term (next 1–2 weeks)
5. Review `/data/prod` contents for cleanup/retention opportunities
6. Move `container-hot` archival 2022 data to **cool** or **archive**
7. Confirm whether backup writes should use a separate disk/path

### Only if symptoms persist
8. Consider higher-performance storage **only if** elevated await continues outside backup windows and after contention is removed

---

## Executive summary
- **Primary risk:** `/data/prod` capacity exhaustion, likely in **2–5 weeks**, prudently plan for **~2–3 weeks**
- **Primary fix:** **resize disk + cleanup + reschedule backup**
- **Do not jump to premium storage yet**
- **Blob optimisation:** `container-hot` appears over-tiered for stale archival data

If you want, I can turn this into a compact ops table with columns for **resource / risk / forecast date / recommendation / confidence**.
