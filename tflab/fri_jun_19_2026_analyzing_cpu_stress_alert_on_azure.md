# Copilot Chat Conversation Export: Analyzing CPU stress alert on Azure

**User:** @karthik-zippy
**Thread URL:** https://github.com/copilot/c/8189fd64-cc89-46bd-8f74-67b49417645d

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
cat /opt/lab-scripts/diagnostic-data/top.txt | head -20
cat /opt/lab-scripts/diagnostic-data/ps-cpu.txt | head -10
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  1      0 3440864  20876 303848    0    0    57    51   36   49  0  0 99  0  0
 2  0      0 3436768  21000 310536    0    0  4560     8 1972  259 86  1  6  8  0
 2  0      0 3436768  21000 310536    0    0     0     0 2008   51 100  0  0  0  0
 2  0      0 3436768  21000 310536    0    0     0     0 2009   60 100  0  0  0  0
 2  0      0 3436768  21000 310536    0    0     0     0 2010   50 100  0  0  0  0
top - 05:11:57 up 37 min,  2 users,  load average: 0.16, 0.03, 0.01
Tasks: 120 total,   3 running, 117 sleeping,   0 stopped,   0 zombie
%Cpu(s):100.0 us,  0.0 sy,  0.0 ni,  0.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   3913.7 total,   3356.2 free,    233.6 used,    323.9 buff/cache
MiB Swap:      0.0 total,      0.0 free,      0.0 used.   3447.8 avail Mem 

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
   1332 root      20   0   76268   6192   3236 R 100.0   0.2   0:04.03 stress-ng
   1333 root      20   0   76268   6192   3236 R 100.0   0.2   0:04.02 stress-ng
      1 root      20   0  167568  12992   8408 S   0.0   0.3   0:02.38 systemd
      2 root      20   0       0      0      0 S   0.0   0.0   0:00.00 kthreadd
      3 root      20   0       0      0      0 S   0.0   0.0   0:00.00 pool_workqueue_release
      4 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-rcu_g
      5 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-rcu_p
      6 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-slub_
      7 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-netns
      8 root      20   0       0      0      0 I   0.0   0.0   0:00.79 kworker/0:0-events
      9 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/0:0H-events_highpri
     11 root      20   0       0      0      0 I   0.0   0.0   0:00.90 kworker/u4:0-events_power_efficient
     12 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-mm_pe
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root        1332 88.2  0.1  76268  6192 ?        R    05:11   0:07 stress-ng-cpu [run]
root        1333 88.0  0.1  76268  6192 ?        R    05:11   0:07 stress-ng-cpu [run]
root           1  0.1  0.3 167568 12992 ?        Ss   04:34   0:02 /sbin/init
root         727  0.1  0.8 408836 33900 ?        Sl   04:34   0:02 python3 -u bin/WALinuxAgent-2.15.2.1-py3.12.egg -run-exthandlers
root           2  0.0  0.0      0     0 ?        S    04:34   0:00 [kthreadd]
root           3  0.0  0.0      0     0 ?        S    04:34   0:00 [pool_workqueue_release]
root           4  0.0  0.0      0     0 ?        I<   04:34   0:00 [kworker/R-rcu_g]
root           5  0.0  0.0      0     0 ?        I<   04:34   0:00 [kworker/R-rcu_p]
root           6  0.0  0.0      0     0 ?        I<   04:34   0:00 [kworker/R-slub_]
END
```

## Copilot

This host is under an intentional CPU burn, not a memory or disk crisis.

## 1. Plain English explanation

Two `stress-ng` processes are consuming essentially all available CPU.

What the data shows:
- `top` shows `%Cpu(s): 100.0 us` and `0.0 id` → CPU is fully busy in **user space**
- The top consumers are:
  - PID `1332` `stress-ng`
  - PID `1333` `stress-ng`
- `ps` confirms both are specifically `stress-ng-cpu [run]`
- Memory is healthy:
  - ~3.3 GiB free out of 3.9 GiB
  - no swap activity
- Disk pressure is not the main issue:
  - `wa` is mostly `0`, briefly `8` once, but not sustained
- Load average is low because this appears to be a small system with just a couple of runnable CPU-bound tasks, not a system-wide stall

In plain English:  
Someone or something started a CPU stress test (`stress-ng`), and it is saturating the VM’s CPUs. The box is otherwise healthy.

## 2. Likely root cause, most probable first

1. **An intentional test or benchmark was started**
   - `stress-ng` is a well-known Linux stress-testing tool
   - Seeing two workers at ~100% each strongly suggests a deliberate CPU stress run

2. **A lab/diagnostic/automation script launched `stress-ng`**
   - Your data is under `/opt/lab-scripts/diagnostic-data/...`
   - That strongly suggests this may be part of a training, validation, or monitoring exercise

3. **A scheduled task, systemd service, or automation job is misconfigured**
   - For example: cron, systemd timer, Azure custom script extension, cloud-init, or a post-provisioning validation script

4. **Manual operator activity**
   - Someone may have SSHed in and run `stress-ng` interactively

5. **Less likely: unauthorized activity**
   - Possible, but much less likely than deliberate testing, because the process name is explicit and typical of diagnostics rather than stealthy abuse

## 3. Immediate investigation steps, in order

These are safe and appropriate for **Azure Ubuntu 22.04**.

### Step 1: Confirm the process command lines and parent process
This tells you exactly how `stress-ng` was started and by what.

Run:
```bash
ps -fp 1332,1333
ps -o pid,ppid,cmd -p 1332,1333
pstree -aps 1332
pstree -aps 1333
```

What you want:
- full command line arguments
- parent PID
- whether it came from `bash`, `cron`, `systemd`, `waagent`, `cloud-init`, etc.

### Step 2: Check whether this is an approved test window
Before stopping anything, confirm whether:
- this is a lab exercise
- a load test was scheduled
- an Azure extension or validation script is intentionally running

Operationally:
- check change records / deployment pipeline / runbook / team chat

### Step 3: Check recent process start time and who launched it
Run:
```bash
ps -eo pid,ppid,user,lstart,cmd | egrep 'PID|stress-ng'
sudo ls -l /proc/1332/exe /proc/1333/exe
sudo tr '\0' ' ' < /proc/1332/cmdline; echo
sudo tr '\0' ' ' < /proc/1333/cmdline; echo
```

Also review shell history if permitted:
```bash
sudo grep -R "stress-ng" /root/.bash_history /home/*/.bash_history 2>/dev/null
```

### Step 4: Check scheduled and service-based launch points
Run:
```bash
systemctl list-units --type=service --all | grep -i stress
systemctl list-timers --all
grep -R "stress-ng" /etc/systemd /etc/cron* /var/spool/cron /var/lib/cloud 2>/dev/null
```

On Azure Ubuntu, also check:
```bash
sudo journalctl -u walinuxagent --since "2 hours ago"
sudo grep -R "stress-ng" /var/log /var/lib/waagent 2>/dev/null
```

### Step 5: Assess user impact before taking action
Check whether production workloads are degraded:
```bash
uptime
mpstat -P ALL 1 5
vmstat 1 5
pidstat -u 1 5
```

If app-specific:
- response times
- failed health checks
- queue growth
- dropped connections
- Azure Monitor CPU metrics and alert timing

### Step 6: Verify whether the VM size and CPU count match expectations
Run:
```bash
nproc
lscpu
```

This helps interpret whether two `stress-ng` workers are saturating all vCPUs or just part of the machine.

## 4. Safe remediation options

### Option A: If this is not authorized, stop the stress test
**Safest immediate action.**  
Usually **does not require a maintenance window** if `stress-ng` is not part of production workload.

Try graceful termination first:
```bash
sudo kill -TERM 1332 1333
sleep 5
ps -p 1332,1333
```

If they do not exit:
```bash
sudo kill -KILL 1332 1333
```

Flag:
- **No production change window required** if these are clearly rogue/diagnostic processes and not part of a planned test
- If there is uncertainty about ownership, get confirmation first

### Option B: Stop the parent service/timer/job that launched it
If a systemd unit, cron job, or Azure extension launched it, disable the source so it does not recur.

Examples:
```bash
sudo systemctl stop <unit>
sudo systemctl disable <unit>
```

or remove/fix the cron entry.

Flag:
- **May require a production change window** if disabling the launcher changes production automation or compliance tooling

### Option C: Renice or CPU-throttle temporarily while investigating
If you need to reduce impact before fully stopping it:

```bash
sudo renice +19 -p 1332 1333
```

If `cpulimit` is already installed, you could use it, but I would not recommend adding packages during an incident unless necessary.

Flag:
- **No maintenance window usually required**
- Safer than rebooting
- Temporary mitigation only

### Option D: If this is an approved performance test, isolate or reschedule it
If intentional:
- move it to non-production
- run it during a change/test window
- constrain worker count/duration

Example safer pattern:
```bash
stress-ng --cpu 1 --timeout 60s
```

Flag:
- **Requires a production change window** if this affects live production capacity or test scheduling policy

### Option E: Review Azure automation/custom script extensions
If launched by Azure automation, fix the assignment, extension, or provisioning script.

Areas to review:
- Azure Custom Script Extension
- cloud-init user-data
- VM applications / DSC-like automation
- image bake/provisioning scripts

Flag:
- **May require a production change window** if changing provisioning/extension behavior on production VMs

## What I would do first

1. Confirm parent process of PIDs `1332` and `1333`
2. Confirm whether there is an approved test
3. If not approved, send `SIGTERM` to both `stress-ng` processes
4. Find and disable the launcher so it does not restart
5. Validate CPU returns to normal and application health recovers

## What I would not recommend yet

- **Do not reboot**
  - There is no evidence of kernel hang, memory exhaustion, or unrecoverable state
  - This is a user-space process problem and should be solved at the process/source level

- **Do not tune swap or memory**
  - Memory is healthy and unrelated

- **Do not assume Azure host/infrastructure fault**
  - The data points directly to guest OS processes consuming CPU

If you want, I can turn this into a short incident note / operator runbook entry with:
- “customer-facing summary”
- “technical summary”
- “exact commands to run”
- “decision tree: kill vs escalate”
