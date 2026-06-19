# Copilot Chat Conversation Export: Azure resilience test plan for Terraform

**User:** @karthik-zippy
**Thread URL:** https://github.com/copilot/c/2e06ec30-dc49-424a-87be-5897236ec9e0

## @karthik-zippy

```
You are a senior cloud resilience engineer specialising in Azure infrastructure.

Analyse this environment created by terraform code @ and design a comprehensive resilience test plan.
Choose the scenarios YOU consider most important for this environment — do not
limit yourself to any specific number.

Environment:
  - vm-app (10.0.1.10): Ubuntu 22.04, payment service (Java, -Xmx4g)
  - vm-db  (10.0.2.10): Ubuntu 22.04, PostgreSQL 14, max_connections=20
  - vm-win (10.0.1.20): Windows Server 2022, IIS reporting service
  - Azure Bastion Basic SKU: only remote access path (no public IPs on VMs)
  - NSG: SSH/RDP from Bastion subnet (10.0.3.0/27) only
  - NSG: PostgreSQL port 5432 from app subnet (10.0.1.0/24) only
  - Storage: Standard LRS, soft-delete 7 days
  - Auto-shutdown: all VMs stop at 20:00 UTC daily

For EACH scenario you design, provide:

  SCENARIO [LETTER]: [Name]
  Description:     What failure condition this simulates and why it is realistic
  Failure type:    COMPUTE / NETWORK / DATABASE / STORAGE / APPLICATION
  Blast radius:    Which components are affected and how severely
  Go/No-Go check:  Command to run BEFORE triggering — confirms clean starting state
  Trigger:         Exact command(s) to create the failure condition
  Expected impact: What each VM and service experiences during the test
  Recovery:        Exact command(s) to restore normal state
  Validation:      Exact command to confirm full recovery
  RTO target:      How long recovery should take

Constraints on ALL scenarios:
  - Every test MUST be reversible within 5 minutes
  - No permanent data loss
  - No commands that require a VM rebuild to recover
  - All trigger and recovery commands must be specific and executable
    (not descriptions — actual runnable bash or PowerShell commands)
  - Bastion is the only access path — all commands must work via SSH/RDP
    through Bastion or via az vm run-command from Cloud Shell

After all scenarios, provide:
  PRIORITY ORDER: Rank the scenarios by risk to the payment service
  DEPENDENCY MAP: Which scenarios should be run BEFORE others
  KNOWN GAPS:     What resilience risks exist in this environment that
                  CANNOT be safely tested in a lab (and why)
```

## Copilot

Below is a comprehensive **Azure resilience test plan** for the described Terraform-built environment, focused on **payment service availability, recoverability, and operational realism**.

I selected scenarios that matter most for this topology:

- **Single app VM**
- **Single DB VM with low `max_connections`**
- **Single Windows reporting VM**
- **Bastion-only admin path**
- **Tight NSGs**
- **No public IPs**
- **Standard LRS storage**
- **Daily auto-shutdown**

Because this environment has many **single points of failure**, the most important tests are those that validate:
1. **app ↔ DB dependency failure behavior**
2. **resource exhaustion on app and DB**
3. **planned/unplanned compute interruption**
4. **operator recovery via Bastion / Run Command**
5. **storage and service-process failure handling**
6. **risk introduced by scheduled shutdown**

---

# RESILIENCE TEST PLAN

## SCENARIO A: Payment service process crash on vm-app
**Description:**  
Simulates an unplanned crash of the Java payment service process on the application VM. This is realistic because Java services can terminate due to JVM faults, bad deploys, OOM killers, or operator mistakes.

**Failure type:** APPLICATION

**Blast radius:**  
- **vm-app:** payment service unavailable
- **vm-db:** unaffected but may see dropped client sessions
- **vm-win:** unaffected
- **Payment path:** severe impact, likely full outage

**Go/No-Go check:**  
Run on **vm-app**:
```bash
sudo systemctl is-active payment && pgrep -af 'java.*payment'
```

**Trigger:**  
Run on **vm-app**:
```bash
sudo systemctl stop payment
```

**Expected impact:**  
- **vm-app:** payment API stops accepting requests
- **vm-db:** existing app DB sessions disconnect
- **vm-win:** no direct impact unless reports query payment outputs
- Users of payment service receive failures/timeouts

**Recovery:**  
Run on **vm-app**:
```bash
sudo systemctl start payment
```

**Validation:**  
Run on **vm-app**:
```bash
sudo systemctl is-active payment && ss -ltnp | grep -E ':80|:443|:8080|:8443'
```

**RTO target:**  
**2 minutes**

---

## SCENARIO B: PostgreSQL service stop on vm-db
**Description:**  
Simulates a database engine outage caused by crash, service stop, package issue, or host-level maintenance. This is one of the highest-risk failures because the payment service depends on PostgreSQL.

**Failure type:** DATABASE

**Blast radius:**  
- **vm-db:** database unavailable
- **vm-app:** payment service loses DB connectivity; likely severe transaction failures
- **vm-win:** reporting may fail if DB-backed
- **Payment path:** critical impact

**Go/No-Go check:**  
Run on **vm-db**:
```bash
sudo systemctl is-active postgresql && sudo -u postgres psql -tAc "select now();"
```

**Trigger:**  
Run on **vm-db**:
```bash
sudo systemctl stop postgresql
```

**Expected impact:**  
- **vm-db:** port 5432 closed
- **vm-app:** connection attempts fail; app may return 5xx, queue, or degrade depending on retry logic
- **vm-win:** reporting may error if dependent on DB
- Potential connection pool instability on app

**Recovery:**  
Run on **vm-db**:
```bash
sudo systemctl start postgresql
```

**Validation:**  
Run on **vm-db**:
```bash
sudo systemctl is-active postgresql && sudo -u postgres psql -tAc "select count(*) from pg_stat_activity;"
```

**RTO target:**  
**3 minutes**

---

## SCENARIO C: App-to-DB network isolation using NSG rule
**Description:**  
Simulates a network policy regression or accidental NSG change that blocks app connectivity to PostgreSQL while both VMs remain healthy. This is realistic in Azure where NSG drift or IaC misconfiguration can silently break tier communication.

**Failure type:** NETWORK

**Blast radius:**  
- **vm-app → vm-db:** DB access blocked
- **vm-db:** healthy but unreachable from app
- **vm-win:** unaffected unless DB access required
- **Payment path:** critical impact

**Go/No-Go check:**  
Run on **vm-app**:
```bash
nc -zv 10.0.2.10 5432
```

**Trigger:**  
Run from **Azure Cloud Shell**:
```bash
az network nsg rule create \
  --resource-group <RG_NAME> \
  --nsg-name <DB_NSG_NAME> \
  --name block-app-to-db-5432-test \
  --priority 100 \
  --direction Inbound \
  --access Deny \
  --protocol Tcp \
  --source-address-prefixes 10.0.1.0/24 \
  --source-port-ranges '*' \
  --destination-address-prefixes '*' \
  --destination-port-ranges 5432
```

**Expected impact:**  
- **vm-db:** PostgreSQL remains up
- **vm-app:** new DB connections fail or time out
- Existing pooled sessions may continue briefly, then errors emerge
- Payment transactions likely fail hard

**Recovery:**  
Run from **Azure Cloud Shell**:
```bash
az network nsg rule delete \
  --resource-group <RG_NAME> \
  --nsg-name <DB_NSG_NAME> \
  --name block-app-to-db-5432-test
```

**Validation:**  
Run on **vm-app**:
```bash
nc -zv 10.0.2.10 5432
```

**RTO target:**  
**4 minutes**

---

## SCENARIO D: Payment JVM memory pressure without VM crash
**Description:**  
Simulates high heap pressure in the Java payment service host, validating whether the service degrades, survives, or becomes unstable when available memory is constrained. Realistic due to traffic spikes, memory leaks, or mis-sized workloads. Since `-Xmx4g` is set, this host may be vulnerable if total VM memory is not much higher.

**Failure type:** APPLICATION

**Blast radius:**  
- **vm-app:** performance degradation or service instability
- **vm-db:** may see lower request volume or bursty reconnects
- **vm-win:** unaffected
- **Payment path:** medium to severe impact depending on headroom

**Go/No-Go check:**  
Run on **vm-app**:
```bash
free -m && pgrep -af 'java.*payment'
```

**Trigger:**  
Run on **vm-app**:
```bash
nohup bash -c 'tmpfile=$(mktemp /dev/shm/memhog.XXXX); python3 -c "a=bytearray(1024*1024*1024*2); import time; time.sleep(240)" >/tmp/memhog.log 2>&1 &' && echo $! | sudo tee /tmp/memhog.pid
```

**Expected impact:**  
- **vm-app:** higher memory pressure, possible JVM GC thrash, latency increase, potential OOM kill if host is small
- **vm-db:** fewer or unstable requests
- Payment transactions may slow or intermittently fail

**Recovery:**  
Run on **vm-app**:
```bash
sudo kill "$(cat /tmp/memhog.pid)" && rm -f /tmp/memhog.pid
```

**Validation:**  
Run on **vm-app**:
```bash
free -m && sudo systemctl is-active payment
```

**RTO target:**  
**5 minutes**

---

## SCENARIO E: CPU saturation on vm-app
**Description:**  
Simulates runaway CPU usage on the application host from inefficient code paths, noisy neighbors inside the VM, or stuck threads. This is realistic and often reveals timeout, retry, and health-check weaknesses.

**Failure type:** COMPUTE

**Blast radius:**  
- **vm-app:** latency spike, reduced throughput
- **vm-db:** may receive slower or burstier traffic
- **vm-win:** unaffected
- **Payment path:** medium to severe impact

**Go/No-Go check:**  
Run on **vm-app**:
```bash
uptime && nproc && mpstat 1 1 || true
```

**Trigger:**  
Run on **vm-app**:
```bash
for i in $(seq 1 "$(nproc)"); do nohup yes > /dev/null 2>&1 & echo $!; done | sudo tee /tmp/cpuhog.pids
```

**Expected impact:**  
- **vm-app:** high CPU steal/user utilization, slower app responses, health checks may flap
- **vm-db:** possibly reduced DB load due to app slowdown
- Payment service may timeout under load

**Recovery:**  
Run on **vm-app**:
```bash
xargs -r sudo kill < /tmp/cpuhog.pids && rm -f /tmp/cpuhog.pids
```

**Validation:**  
Run on **vm-app**:
```bash
uptime && top -bn1 | head -20 && sudo systemctl is-active payment
```

**RTO target:**  
**3 minutes**

---

## SCENARIO F: PostgreSQL connection exhaustion
**Description:**  
Simulates exhaustion of PostgreSQL connections with `max_connections=20`, which is a major design risk in small single-node databases. Very realistic if the payment app has a poorly tuned pool, leaked sessions, or a reconnect storm.

**Failure type:** DATABASE

**Blast radius:**  
- **vm-db:** rejects new connections
- **vm-app:** requests needing DB fail
- **vm-win:** reporting may fail to connect
- **Payment path:** severe impact

**Go/No-Go check:**  
Run on **vm-db**:
```bash
sudo -u postgres psql -tAc "show max_connections; select count(*) from pg_stat_activity;"
```

**Trigger:**  
Run on **vm-db**:
```bash
for i in $(seq 1 18); do
  nohup sudo -u postgres psql -c "select pg_sleep(240);" >/tmp/pgconn_$i.log 2>&1 &
done
```

**Expected impact:**  
- **vm-db:** nearly all usable sessions consumed
- **vm-app:** new DB requests fail with connection errors or pool timeouts
- **vm-win:** report connections may fail
- May expose whether reserved admin connections exist and whether app retries are sane

**Recovery:**  
Run on **vm-db**:
```bash
sudo pkill -f "select pg_sleep\(240\)" || true
```

**Validation:**  
Run on **vm-db**:
```bash
sudo -u postgres psql -tAc "select count(*) from pg_stat_activity;"
```

**RTO target:**  
**3 minutes**

---

## SCENARIO G: Disk-full condition on vm-db data volume or root filesystem
**Description:**  
Simulates database host disk exhaustion, a common operational failure caused by WAL growth, logs, temp files, or backups. Must be carefully constrained to remain reversible and avoid corruption.

**Failure type:** STORAGE

**Blast radius:**  
- **vm-db:** PostgreSQL writes may fail; DB may become read-only-like or erroring
- **vm-app:** transactions fail
- **vm-win:** possibly unaffected
- **Payment path:** severe impact

**Go/No-Go check:**  
Run on **vm-db**:
```bash
df -h / /var/lib/postgresql && sudo systemctl is-active postgresql
```

**Trigger:**  
Run on **vm-db**  
(creates a bounded temporary filler file; adjust size if free space is limited):
```bash
sudo fallocate -l 2G /var/tmp/resilience-fillfile.test
```

If `fallocate` is not supported:
```bash
sudo dd if=/dev/zero of=/var/tmp/resilience-fillfile.test bs=1M count=2048 status=progress
```

**Expected impact:**  
- **vm-db:** writes may slow/fail if filesystem headroom was low
- PostgreSQL may log checkpoint/temp/write failures
- **vm-app:** payment writes may fail while reads may partially work

**Recovery:**  
Run on **vm-db**:
```bash
sudo rm -f /var/tmp/resilience-fillfile.test && sync
```

**Validation:**  
Run on **vm-db**:
```bash
df -h / /var/lib/postgresql && sudo -u postgres psql -tAc "select now();"
```

**RTO target:**  
**4 minutes**

---

## SCENARIO H: vm-app guest OS reboot
**Description:**  
Simulates planned or unplanned reboot of the application VM due to patching, kernel panic recovery, or Azure maintenance. Validates service autostart and recovery sequencing.

**Failure type:** COMPUTE

**Blast radius:**  
- **vm-app:** full outage during reboot
- **vm-db:** unaffected
- **vm-win:** unaffected
- **Payment path:** severe but time-bounded outage

**Go/No-Go check:**  
Run on **vm-app**:
```bash
sudo systemctl is-active payment && who -b
```

**Trigger:**  
Run on **vm-app**:
```bash
sudo reboot
```

**Expected impact:**  
- **vm-app:** disconnects immediately; payment unavailable
- **vm-db:** idle/connection drops only
- On boot, app should auto-start if properly configured

**Recovery:**  
No manual recovery if service is configured correctly. If needed after reconnect:
```bash
sudo systemctl start payment
```

**Validation:**  
Run on **vm-app** after reconnect:
```bash
who -b && sudo systemctl is-active payment && pgrep -af 'java.*payment'
```

**RTO target:**  
**5 minutes**

---

## SCENARIO I: vm-db guest OS reboot
**Description:**  
Simulates OS-level reboot of the database VM from patching or host maintenance. This validates PostgreSQL autostart, crash recovery time, and app reconnection behavior.

**Failure type:** COMPUTE

**Blast radius:**  
- **vm-db:** unavailable during reboot
- **vm-app:** payment fails during outage, may need reconnect recovery
- **vm-win:** reporting may fail
- **Payment path:** critical but time-bounded

**Go/No-Go check:**  
Run on **vm-db**:
```bash
sudo systemctl is-active postgresql && who -b
```

**Trigger:**  
Run on **vm-db**:
```bash
sudo reboot
```

**Expected impact:**  
- **vm-db:** DB unavailable during reboot
- **vm-app:** transactions fail; app may show pool exhaustion/retry issues on return
- Recovery quality depends on app reconnect logic

**Recovery:**  
No manual recovery if PostgreSQL autostarts. If needed:
```bash
sudo systemctl start postgresql
```

**Validation:**  
Run on **vm-db** after reconnect:
```bash
who -b && sudo systemctl is-active postgresql && sudo -u postgres psql -tAc "select now();"
```

**RTO target:**  
**5 minutes**

---

## SCENARIO J: IIS reporting service stop on vm-win
**Description:**  
Simulates reporting application failure on the Windows VM. Although not directly in the payment path, reporting often shares DB resources and operational importance.

**Failure type:** APPLICATION

**Blast radius:**  
- **vm-win:** reporting unavailable
- **vm-db:** may see reduced traffic
- **vm-app:** usually unaffected
- **Payment path:** low direct impact, possible indirect benefit/reduction in contention

**Go/No-Go check:**  
Run on **vm-win** PowerShell:
```powershell
Get-Service W3SVC | Select-Object Status,Name
```

**Trigger:**  
Run on **vm-win** PowerShell:
```powershell
Stop-Service W3SVC -Force
```

**Expected impact:**  
- **vm-win:** IIS endpoints unavailable
- **vm-db:** less reporting load if it queries DB
- **vm-app:** should remain healthy
- Useful for validating service isolation

**Recovery:**  
Run on **vm-win** PowerShell:
```powershell
Start-Service W3SVC
```

**Validation:**  
Run on **vm-win** PowerShell:
```powershell
Get-Service W3SVC | Select-Object Status,Name
```

**RTO target:**  
**2 minutes**

---

## SCENARIO K: Reporting VM CPU saturation
**Description:**  
Simulates runaway reporting workload on Windows, testing whether the reporting tier can starve shared backend resources or remain isolated from payment processing.

**Failure type:** COMPUTE

**Blast radius:**  
- **vm-win:** degraded reporting performance
- **vm-db:** possible increased contention if reports are DB-heavy
- **vm-app:** indirect impact possible via DB contention
- **Payment path:** low to medium risk

**Go/No-Go check:**  
Run on **vm-win** PowerShell:
```powershell
Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3
```

**Trigger:**  
Run on **vm-win** PowerShell:
```powershell
1..4 | ForEach-Object {
  Start-Process powershell -ArgumentList '-NoProfile -WindowStyle Hidden -Command "while($true){[Math]::Sqrt((Get-Random)) | Out-Null}"'
}
```

**Expected impact:**  
- **vm-win:** CPU spikes, report latency rises
- **vm-db:** possible reduced capacity if reports are active
- **vm-app:** should remain mostly isolated unless DB gets stressed

**Recovery:**  
Run on **vm-win** PowerShell:
```powershell
Get-Process powershell | Where-Object { $_.MainWindowTitle -eq '' } | Stop-Process -Force
```

**Validation:**  
Run on **vm-win** PowerShell:
```powershell
Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3
```

**RTO target:**  
**3 minutes**

---

## SCENARIO L: App-side DB route blackhole via iptables on vm-app
**Description:**  
Simulates host-local networking failure, local firewall drift, or bad hardening on the app VM without touching Azure NSGs. This isolates whether the issue is cloud policy or guest OS networking.

**Failure type:** NETWORK

**Blast radius:**  
- **vm-app → vm-db:** DB unreachable from app host only
- **vm-db:** healthy
- **vm-win:** unaffected
- **Payment path:** critical impact

**Go/No-Go check:**  
Run on **vm-app**:
```bash
nc -zv 10.0.2.10 5432 && sudo iptables -S OUTPUT | grep 10.0.2.10 || true
```

**Trigger:**  
Run on **vm-app**:
```bash
sudo iptables -I OUTPUT 1 -p tcp -d 10.0.2.10 --dport 5432 -j REJECT
```

**Expected impact:**  
- **vm-app:** immediate DB connection failures
- **vm-db:** remains healthy and reachable from other valid sources
- Payment service errors closely resemble real network faults

**Recovery:**  
Run on **vm-app**:
```bash
sudo iptables -D OUTPUT -p tcp -d 10.0.2.10 --dport 5432 -j REJECT
```

**Validation:**  
Run on **vm-app**:
```bash
nc -zv 10.0.2.10 5432
```

**RTO target:**  
**2 minutes**

---

## SCENARIO M: PostgreSQL slow response using session lock contention
**Description:**  
Simulates DB slowdown due to lock contention instead of full outage. This is realistic for payment workloads where one long transaction can stall writes and create cascading latency.

**Failure type:** DATABASE

**Blast radius:**  
- **vm-db:** partial degradation, not full outage
- **vm-app:** selected transactions may hang/time out
- **vm-win:** reports may also wait
- **Payment path:** medium to severe depending on table hit

**Go/No-Go check:**  
Run on **vm-db**:
```bash
sudo -u postgres psql -tAc "select now();"
```

**Trigger:**  
This requires a known noncritical test table. Example on **vm-db**:
```bash
sudo -u postgres psql <<'SQL'
BEGIN;
LOCK TABLE public.payment_test IN ACCESS EXCLUSIVE MODE;
SELECT pg_sleep(240);
SQL
```

**Expected impact:**  
- Writes/reads against `public.payment_test` block
- Broader DB remains up
- Good for validating query timeout, lock timeout, and app retry behavior

**Recovery:**  
Terminate the blocking backend from another session on **vm-db**:
```bash
sudo -u postgres psql -tAc "select pg_terminate_backend(pid) from pg_stat_activity where query like '%LOCK TABLE public.payment_test%' and pid <> pg_backend_pid();"
```

**Validation:**  
Run on **vm-db**:
```bash
sudo -u postgres psql -tAc "select count(*) from pg_stat_activity where wait_event_type='Lock';"
```

**RTO target:**  
**3 minutes**

---

## SCENARIO N: Azure VM stop/start on vm-app using control plane
**Description:**  
Simulates Azure control-plane initiated stop/start, closer to operator action or automation behavior than guest reboot. Important because daily auto-shutdown already exists, and restart behavior needs validation.

**Failure type:** COMPUTE

**Blast radius:**  
- **vm-app:** full service interruption
- **vm-db:** unaffected
- **vm-win:** unaffected
- **Payment path:** severe outage

**Go/No-Go check:**  
Run from **Azure Cloud Shell**:
```bash
az vm get-instance-view -g <RG_NAME> -n vm-app --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus" -o tsv
```

**Trigger:**  
Run from **Azure Cloud Shell**:
```bash
az vm stop -g <RG_NAME> -n vm-app --skip-shutdown
```

**Expected impact:**  
- **vm-app:** powered off from Azure perspective
- Payment service fully unavailable
- Tests dependence on Azure control plane and VM boot/startup automation

**Recovery:**  
Run from **Azure Cloud Shell**:
```bash
az vm start -g <RG_NAME> -n vm-app
```

**Validation:**  
Run from **Azure Cloud Shell**:
```bash
az vm run-command invoke -g <RG_NAME> -n vm-app --command-id RunShellScript --scripts "systemctl is-active payment && pgrep -af 'java.*payment'"
```

**RTO target:**  
**5 minutes**

---

## SCENARIO O: Azure VM stop/start on vm-db using control plane
**Description:**  
Simulates Azure-level power interruption or operator stop/start of the DB VM. This is highly relevant because single-node PostgreSQL is the most sensitive component.

**Failure type:** COMPUTE

**Blast radius:**  
- **vm-db:** unavailable
- **vm-app:** payment transactions fail
- **vm-win:** reports fail if DB-backed
- **Payment path:** critical outage

**Go/No-Go check:**  
Run from **Azure Cloud Shell**:
```bash
az vm get-instance-view -g <RG_NAME> -n vm-db --query "instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus" -o tsv
```

**Trigger:**  
Run from **Azure Cloud Shell**:
```bash
az vm stop -g <RG_NAME> -n vm-db --skip-shutdown
```

**Expected impact:**  
- DB fully unavailable
- Payment service likely fails immediately or after pool depletion
- Reveals how app behaves across hard backend interruption

**Recovery:**  
Run from **Azure Cloud Shell**:
```bash
az vm start -g <RG_NAME> -n vm-db
```

**Validation:**  
Run from **Azure Cloud Shell**:
```bash
az vm run-command invoke -g <RG_NAME> -n vm-db --command-id RunShellScript --scripts "systemctl is-active postgresql && sudo -u postgres psql -tAc 'select now();'"
```

**RTO target:**  
**5 minutes**

---

## SCENARIO P: Auto-shutdown policy operational readiness test
**Description:**  
Simulates the operational effect of the existing **20:00 UTC daily shutdown** by manually stopping one non-production equivalent VM before the schedule window and validating startup/runbook readiness. This is realistic because the configured shutdown is itself a resilience risk if critical services are expected after hours.

**Failure type:** COMPUTE

**Blast radius:**  
- Depends on VM chosen
- If run against **vm-app** or **vm-db**, payment outage is guaranteed
- Best first executed on **vm-win**, then on app/db in a controlled window

**Go/No-Go check:**  
Run from **Azure Cloud Shell**:
```bash
date -u && az vm list -g <RG_NAME> -d -o table
```

**Trigger:**  
Example for **vm-win** from **Azure Cloud Shell**:
```bash
az vm stop -g <RG_NAME> -n vm-win
```

**Expected impact:**  
- Demonstrates actual operations needed after scheduled shutdown
- Confirms whether startup sequencing, runbooks, and service autostart are documented and effective
- If applied to payment components, shows true business impact of current shutdown policy

**Recovery:**  
Run from **Azure Cloud Shell**:
```bash
az vm start -g <RG_NAME> -n vm-win
```

**Validation:**  
Run from **Azure Cloud Shell**:
```bash
az vm run-command invoke -g <RG_NAME> -n vm-win --command-id RunPowerShellScript --scripts "Get-Service W3SVC | Select-Object Status,Name"
```

**RTO target:**  
**5 minutes**

---

# PRIORITY ORDER
Ranked by **risk to the payment service**:

1. **B** – PostgreSQL service stop on vm-db  
2. **C** – App-to-DB network isolation using NSG  
3. **F** – PostgreSQL connection exhaustion  
4. **O** – Azure VM stop/start on vm-db  
5. **I** – vm-db guest OS reboot  
6. **L** – App-side DB route blackhole via iptables  
7. **A** – Payment service process crash on vm-app  
8. **N** – Azure VM stop/start on vm-app  
9. **H** – vm-app guest OS reboot  
10. **M** – PostgreSQL lock contention / slow response  
11. **G** – Disk-full condition on vm-db  
12. **D** – Payment JVM memory pressure  
13. **E** – CPU saturation on vm-app  
14. **P** – Auto-shutdown policy operational readiness  
15. **J** – IIS reporting service stop on vm-win  
16. **K** – Reporting VM CPU saturation

---

# DEPENDENCY MAP
Recommended execution order to reduce risk and improve signal quality:

## Run first: safest / most diagnostic
- **J** Reporting service stop
- **K** Reporting CPU saturation
- **A** Payment service process stop
- **E** App CPU saturation
- **D** App memory pressure

These validate **basic operator recovery** and service supervision with minimal infrastructure change.

## Run next: app-to-db dependency faults
- **L** App-side DB blackhole
- **C** NSG block app→DB
- **B** PostgreSQL service stop
- **M** DB lock contention
- **F** DB connection exhaustion

These should be run before compute power-cycle tests because they isolate **application dependency behavior** cleanly.

## Run after that: storage and reboot class tests
- **G** DB disk-full
- **H** vm-app reboot
- **I** vm-db reboot

These validate **host resilience** and startup behavior.

## Run last: highest-disruption control-plane tests
- **N** Azure stop/start vm-app
- **O** Azure stop/start vm-db
- **P** Auto-shutdown readiness

These are most disruptive and should follow successful validation of service/process recovery.

## Explicit dependencies
- Run **A before H/N** to confirm whether failure is only service-level or host-level.
- Run **B before I/O** to distinguish **DB service recovery** from **VM recovery**.
- Run **L before C** because guest firewall isolation is easier to revert than NSG policy change.
- Run **M before F** because lock contention is lower-risk than connection exhaustion.
- Run **J/K before any DB stress test** to establish whether reporting tier materially affects payment tier.

---

# KNOWN GAPS
These are important resilience risks that **cannot be safely tested in this lab** under your constraints, or cannot be meaningfully validated with this architecture:

## 1. Azure zone/datacenter failure
**Why not safely test:**  
You cannot induce a real Azure zone or physical host failure in a controlled lab.  
**Risk exposed:**  
All three workloads appear single-instance, so a zone/host failure would likely cause total service loss.

## 2. Storage durability failure of Standard LRS
**Why not safely test:**  
LRS replicates only within a single region/datacenter scope; you cannot safely simulate real replica corruption/loss.  
**Risk exposed:**  
No protection against regional failure, and limited assurance against broader storage incidents.

## 3. Region-wide outage
**Why not safely test:**  
Cannot be induced safely without a secondary region architecture.  
**Risk exposed:**  
This environment likely has **no disaster recovery posture** for regional loss.

## 4. Real data corruption / logical corruption recovery
**Why not safely test:**  
Your constraint forbids permanent data loss. Testing actual corruption requires restore drills from backups/snapshots into isolated copies.  
**Risk exposed:**  
Soft delete on storage does **not** prove PostgreSQL point-in-time recovery or application-consistent restore.

## 5. Full backup/restore of PostgreSQL under pressure
**Why not safely test in-place:**  
A true restore drill risks breaching the 5-minute reversibility constraint.  
**Risk exposed:**  
You do not yet know actual RTO/RPO for DB restoration.

## 6. Bastion platform outage or management-plane lockout
**Why not safely test fully:**  
Since Bastion is the only remote path, intentionally breaking it could strand operators and violate the 5-minute recovery rule.  
**Risk exposed:**  
Bastion is a **critical operational single point of failure**.

## 7. NSG lockout from Bastion subnet
**Why not safely test fully:**  
Blocking 10.0.3.0/27 ingress to SSH/RDP could cut off the only interactive path.  
**Risk exposed:**  
Admin-plane access resilience is weak; recovery depends on Azure control-plane tooling permissions and availability.

## 8. Kernel/filesystem corruption
**Why not safely test:**  
Could require repair or rebuild, violating constraints.  
**Risk exposed:**  
Unknown host-level recovery behavior after low-level corruption.

## 9. JVM heap dump / OOM forensic path
**Why not fully test here:**  
A true forced OOM may cause unstable host behavior and recovery longer than 5 minutes.  
**Risk exposed:**  
Unknown whether the Java service fails fast, restarts cleanly, or causes node-wide exhaustion.

## 10. Simultaneous multi-component failure
**Why not safely test first:**  
Examples: DB reboot during app reconnect storm, or app + Bastion issue together. These compound tests can exceed 5-minute reversibility.  
**Risk exposed:**  
Real incidents often cascade; single-failure tests may understate production risk.

---

# Key resilience observations from this environment
Most importantly: **the payment service is not resilient by design**.

Primary reasons:
- **Single app VM**
- **Single DB VM**
- **Single reporting VM**
- **Single Bastion path**
- **DB max_connections=20**
- **Standard LRS only**
- **Daily shutdown of all VMs**

So this test plan is primarily validating **recoverability and failure behavior**, not true high availability.

If you want, I can next convert this into one of these formats:
1. **A runnable step-by-step test runbook**
2. **A Markdown table for direct use in GitHub/docs**
3. **An Azure-focused chaos test matrix with pass/fail criteria**
4. **A version tailored to `az vm run-command` only**
