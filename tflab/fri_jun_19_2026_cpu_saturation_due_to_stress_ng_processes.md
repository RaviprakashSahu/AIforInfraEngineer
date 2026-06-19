# Copilot Chat Conversation Export: CPU saturation due to stress-ng processes

**User:** @karthik-zippy
**Thread URL:** https://github.com/copilot/c/b7eb7c3a-0bd7-4e78-b096-3c8d047772fe

## @karthik-zippy

```
You are a senior infrastructure operations engineer

Analyse the following alert and provide:
  1. Plain English explanation of what is happening
  2. Likely root cause (most probable first)
  3. Immediate investigation steps (in order)
  4. Safe remediation options (flag any requiring a maintenance window)

Constraints:
  - Only recommend changes appropriate for azure ubuntu 22.04
  - Flag anything that require a production change window
  - Do not suggest reboots unless all other options are exhausted

-- Data --
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  1      0 3430064  20336 304308    0    0    68     8   38   53  0  0 99  0  0
 2  0      0 3419132  20460 311000    0    0  4488     0 2092  195 97  1  1  1  0
 2  0      0 3419132  20460 311000    0    0     0     0 2010   57 100  0  0  0  0
 2  0      0 3419132  20460 311000    0    0     0     0 2009   59 100  0  0  0  0
 2  0      0 3419132  20460 311000    0    0     0     4 2049   92 100  0  0  0  0
top - 05:04:28 up 30 min,  2 users,  load average: 0.00, 0.00, 0.00
Tasks: 120 total,   3 running, 117 sleeping,   0 stopped,   0 zombie
%Cpu(s):100.0 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   3913.7 total,   3339.0 free,    250.9 used,    323.8 buff/cache
MiB Swap:      0.0 total,      0.0 free,      0.0 used.   3430.3 avail Mem 

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
   1151 root      20   0   76268   7120   3204 R  93.8   0.2   0:04.14 stress-ng
   1152 root      20   0   76268   7120   3204 R  93.8   0.2   0:04.13 stress-ng
      1 root      20   0  166592  11936   8404 S   0.0   0.3   0:02.15 systemd
      2 root      20   0       0      0      0 S   0.0   0.0   0:00.00 kthreadd
      3 root      20   0       0      0      0 S   0.0   0.0   0:00.00 pool_workqueue_release
      4 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-rcu_g
      5 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-rcu_p
      6 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-slub_
      7 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-netns
      9 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/0:0H-events_highpri
     11 root      20   0       0      0      0 I   0.0   0.0   0:00.19 kworker/u4:0-events_power_efficient
     12 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-mm_pe
     13 root      20   0       0      0      0 I   0.0   0.0   0:00.00 rcu_tasks_rude_kthread
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root        1151  102  0.1  76268  7120 ?        R    05:04   0:07 stress-ng-cpu [run]
root        1152  102  0.1  76268  7120 ?        R    05:04   0:07 stress-ng-cpu [run]
root           1  0.1  0.2 166592 11936 ?        Ss   04:33   0:02 /sbin/init
root         658  0.1  0.8 408812 34060 ?        Sl   04:33   0:02 python3 -u bin/WALinuxAgent-2.15.2.1-py3.12.egg -run-exthandlers
root           2  0.0  0.0      0     0 ?        S    04:33   0:00 [kthreadd]
root           3  0.0  0.0      0     0 ?        S    04:33   0:00 [pool_workqueue_release]
root           4  0.0  0.0      0     0 ?        I<   04:33   0:00 [kworker/R-rcu_g]
root           5  0.0  0.0      0     0 ?        I<   04:33   0:00 [kworker/R-rcu_p]
root           6  0.0  0.0      0     0 ?        I<   04:33   0:00 [kworker/R-slub_]
```

## Copilot

This alert is a **CPU saturation event caused by an intentional userspace load generator (`stress-ng`)**, not a memory, swap, or disk problem.

## 1. Plain English explanation

The VM is almost entirely busy because **two `stress-ng` processes are consuming all available CPU**.

What the data shows:
- `top` shows **100% user CPU** and **0% idle**
- The top CPU consumers are:
  - `stress-ng` PID `1151`
  - `stress-ng` PID `1152`
- Each is using about **94–102% CPU**, which is consistent with **two CPU workers on a 2 vCPU system**
- Memory is healthy:
  - ~3.3 GiB free out of ~3.9 GiB
  - no swap in use
- Disk wait is not the issue:
  - `wa` is ~0–1%
- Kernel/system CPU is not the issue:
  - `sy` is ~0–1%

So in plain English: **something started `stress-ng`, and it is deliberately pegging the CPUs.** The machine is not short on RAM and does not appear to be blocked on storage.

## 2. Likely root cause, most probable first

### 1. `stress-ng` was intentionally launched for testing or benchmarking
This is by far the most likely cause.

Evidence:
- The process name is explicit: `stress-ng-cpu [run]`
- Two worker processes are running, matching the observed CPU saturation
- This tool is commonly used for:
  - synthetic load tests
  - burn-in testing
  - monitoring/alert validation
  - chaos or resilience exercises

### 2. A startup script, cron job, cloud-init/custom script extension, or automation accidentally launched `stress-ng`
Because this is Azure Ubuntu 22.04, check:
- cloud-init user data
- Azure Custom Script Extension / Run Command
- cron/anacron/systemd timers
- CI/CD or config management tooling

This is especially likely if the VM was recently provisioned or changed.

### 3. A leftover operational/debug task was never terminated
Someone may have started `stress-ng` interactively or via automation and forgotten to stop it.

### 4. Unauthorized or unexpected command execution
Less likely than the above, but still worth validating if nobody recognizes the process. `stress-ng` is a legitimate tool, but if it appears unexpectedly, treat it as suspicious until explained.

## 3. Immediate investigation steps, in order

These are safe, low-risk investigation steps for **Azure Ubuntu 22.04**.

### Step 1: Confirm the scope and whether service health is impacted
Check whether the box is just busy or actually affecting production workload:
- application latency/errors
- failed health checks
- queue backlogs
- CPU alert duration and recurrence

If customer-facing impact exists, prioritize stopping the load generator after confirming it is not expected.

### Step 2: Inspect the full command line and parent process
Find exactly how `stress-ng` was launched and by what:

```bash
ps -fp 1151,1152
ps -o pid,ppid,cmd -p 1151,1152
pstree -aps 1151
pstree -aps 1152
tr '\0' ' ' < /proc/1151/cmdline; echo
tr '\0' ' ' < /proc/1152/cmdline; echo
```

What you want to know:
- exact arguments (`--cpu`, `--timeout`, etc.)
- parent PID
- whether it came from a shell, script, systemd service, cron, or Azure agent workflow

### Step 3: Identify who started it
Check process ownership details and session history:

```bash
ps -eo pid,ppid,user,lstart,cmd | grep stress-ng | grep -v grep
last -ai | head -20
who
journalctl --since "1 hour ago" | grep -i stress-ng
```

Also inspect shell history if permitted:
- `/root/.bash_history`
- relevant operator account histories

Be cautious: shell history may be incomplete or delayed until logout.

### Step 4: Check for systemd-managed or scheduled launch
Look for persistence or recurring triggers:

```bash
systemctl list-units --type=service --all | grep -i stress
systemctl list-timers --all
grep -R "stress-ng" /etc/systemd /usr/lib/systemd 2>/dev/null
grep -R "stress-ng" /etc/cron* /var/spool/cron /var/spool/cron/crontabs 2>/dev/null
```

### Step 5: Check Azure-specific execution paths
Because this is Azure and the Azure Linux Agent is present (`WALinuxAgent`), inspect cloud-init and Azure extension activity:

```bash
journalctl -u walinuxagent --since "2 hours ago"
ls -R /var/lib/waagent 2>/dev/null
grep -R "stress-ng" /var/lib/waagent 2>/dev/null
journalctl -u cloud-init --since "2 hours ago"
journalctl -u cloud-config --since "2 hours ago"
grep -R "stress-ng" /var/log /var/lib/cloud 2>/dev/null
```

Common sources:
- Custom Script Extension
- Run Command
- cloud-init custom data
- post-provisioning automation

### Step 6: Verify package provenance
Confirm `stress-ng` is the expected Ubuntu package and not a renamed binary:

```bash
which stress-ng
dpkg -S "$(which stress-ng)"
dpkg -l | grep stress-ng
sha256sum "$(which stress-ng)"
```

### Step 7: Capture evidence before making changes
If this may become a security or ops follow-up, collect:
- process command line
- parent/child tree
- timestamps
- recent Azure agent/cloud-init logs
- `journalctl` excerpts
- alert timestamps

## 4. Safe remediation options

### Option A: Stop the `stress-ng` processes if they are not expected
This is the safest immediate fix **if production impact exists and the load test was not approved**.

Try graceful termination first:

```bash
kill -TERM 1151 1152
sleep 5
ps -p 1151,1152 -o pid,cmd
```

If still running:

```bash
kill -KILL 1151 1152
```

**Production change window:**  
- **Usually no maintenance window required** if this is clearly an unauthorized or accidental test process.
- If this was part of an approved validation exercise, coordinate with the owner before stopping it.

### Option B: Disable the trigger so it does not restart
If launched by automation, remove or disable the source:
- systemd unit/timer
- cron entry
- cloud-init/custom script
- Azure extension/runbook/config management job

**Production change window:**  
- **May require a production change window** if you are modifying:
  - systemd services/timers tied to production workflows
  - deployment automation
  - Azure VM extensions or provisioning scripts
  - scheduled jobs used by operations

### Option C: Temporarily deprioritize the process
If you need a lower-risk interim action before stopping it:

```bash
renice +19 -p 1151 1152
```

You can also restrict future launches if managed by systemd, but that is a config change.

**Production change window:**  
- `renice` on the running test process: **No maintenance window typically required**
- Changing service CPU controls/systemd unit definitions: **Requires change window**

### Option D: Add guardrails to prevent recurrence
Examples appropriate for Ubuntu 22.04:
- enforce approval for load tools in production
- require systemd CPU quotas for non-production test services
- remove `stress-ng` from production images if not needed
- tighten sudo/automation controls
- review Azure Custom Script Extension / Run Command usage

**Production change window:**  
- Removing packages or changing baseline image/configuration on production VMs: **Requires change window**
- Policy/process-only changes: **No maintenance window**

### Option E: Reboot only as last resort
A reboot is **not recommended here** because:
- the issue is isolated to identifiable user processes
- there is no evidence of kernel hang, memory exhaustion, or uninterruptible system lockup

**Production change window:**  
- **Requires maintenance/change window**
- Use only if the processes cannot be terminated and the host is materially impacted

## Recommended operator conclusion

Most probable conclusion: **`stress-ng` was started intentionally or accidentally and is saturating both vCPUs.**  
This is **not** a memory pressure incident, swap issue, or storage bottleneck.

## Suggested immediate action plan

1. Confirm whether a load test was scheduled.
2. Inspect parent process and launch source.
3. If unapproved or impacting production, **gracefully terminate PIDs 1151 and 1152**.
4. Check Azure/cloud-init/waagent/cron/systemd to prevent relaunch.
5. Capture evidence and document owner/source.

If you want, I can turn this into a **short incident note / ops runbook entry** with:
- customer-safe summary
- commands to run
- decision tree for “stop now vs observe vs escalate.”
