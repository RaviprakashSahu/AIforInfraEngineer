# Root Cause Analysis (RCA) - CPU/Memory Fault Injection Incident

## 1. Problem Summary
A controlled fault injection exercise in an Azure-hosted Windows VM caused sustained CPU saturation and attempted high-memory pressure. During fault execution, CPU remained at 100% for the full active window, and memory allocation attempts generated an out-of-memory warning. Fault resources were then stopped, and recovery was verified after remediation.

## 2. Scope / Environment
- Platform: Microsoft Azure
- Provisioning: Terraform
- In-scope resources:
  - Resource Group
  - Virtual Network / Subnet
  - Network Security Group
  - Public IP
  - Network Interface
  - Windows Virtual Machine
- Fault method: PowerShell-based CPU/resource exhaustion script
- Recovery readiness: Restore script created and tested before fault run

## 3. Timeline
- **2026-06-19T09:40:11.465Z** - CPU fault initiated (2 threads, 300s)
- **2026-06-19T09:40:12.355Z** - CPU stress thread 1 started (Job 1)
- **2026-06-19T09:40:12.480Z** - CPU stress thread 2 started (Job 3)
- **2026-06-19T09:40:12.496Z** - Memory fault initiated (target allocation: 1800 MB)
- **2026-06-19T09:40:12.970Z** - Memory allocation warning (OutOfMemoryException)
- **2026-06-19T09:40:12.985Z** - Fault active sampling started (every 15s for 300s)
- **2026-06-19T09:40:33.309Z to 2026-06-19T09:45:13.155Z** - Samples 1-13 recorded; CPU consistently 100%, free RAM ~1908 MB trending to ~1850 MB
- **2026-06-19T09:45:16.545Z** - Fault stop initiated; resources released
- **2026-06-19T09:45:17.280Z** - CPU Job 1 stopped
- **2026-06-19T09:45:17.280Z** - CPU Job 3 stopped
- **Post-stop** - Recovery verified after remediation (per provided context)

## 4. Symptoms Observed
- Sustained CPU saturation at 100% across all sampling points during active fault.
- Memory stress attempt produced allocation warning (`OutOfMemoryException`).
- Gradual decline in available free RAM during fault window (with minor fluctuation).

## 5. Evidence Supporting Diagnosis
### Direct Evidence
- Log entries explicitly show CPU fault start with 2 stress threads and both jobs running.
- Log samples (1-13) explicitly report CPU at 100% throughout.
- Log warning explicitly reports `.ctor` allocation failure with `System.OutOfMemoryException`.
- Log entries confirm controlled stop and successful termination of both CPU stress jobs.
- Additional context confirms restore script was pre-tested and recovery was validated.

### Supporting Indicators (Symptoms, not root-cause proof by themselves)
- Free RAM trend from ~1908 MB down toward ~1850 MB during fault period suggests memory pressure behavior under load.

## 6. Root Cause Analysis
**Root Cause Statement:**  
The incident impact was intentionally induced by a planned PowerShell fault injection that launched CPU stress workers for 300 seconds and attempted large memory allocation, resulting in deliberate CPU exhaustion and memory allocation failure behavior on the target VM.

Contributing technical factors (within test design):
- CPU stress workload was configured to continuously consume compute capacity.
- Memory allocation target triggered runtime out-of-memory behavior under available memory constraints.

## 7. Remediation Applied
- Executed fault stop sequence to release injected load.
- Confirmed termination of stress jobs (Job 1 and Job 3).
- Applied prepared restore/recovery process (as per pre-tested restore script).

## 8. Recovery Validation
- CPU stress jobs were explicitly reported as stopped.
- Fault lifecycle reached controlled stop state without evidence of stuck stress processes in provided logs.
- Recovery status marked as verified after remediation in provided context.

## 9. Preventive Recommendations
1. Add explicit safety guardrails in fault scripts (max CPU duration, memory cap, and automatic rollback trigger).
2. Pre-check available memory and reject memory fault requests above a defined threshold.
3. Add real-time abort criteria (for example, sustained CPU = 100% beyond planned test tolerance).
4. Standardize fault test runbooks with start/stop validation checkpoints and operator sign-off.
5. Capture post-fault health checks automatically (CPU, memory, service reachability) before closing incident/testing window.