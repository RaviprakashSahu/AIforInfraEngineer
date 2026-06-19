# Prompt Library — FinBridge AI-Assisted Infrastructure Workflow

This file records the actual AI prompts used during diagnosis, remediation planning, and documentation, along with short review notes describing what was kept, changed, or rejected from the AI output.

---
You are an expert Infrastructure Operations Incident Manager and technical RCA writer.

Based on the incident details below, generate a professional RCA document in markdown format.

Incident Details:
[2026-06-19T09:40:11.465Z] [INFO] Starting CPU fault: 2 threads for 300s
[2026-06-19T09:40:12.355Z] [INFO]   CPU stress thread 1/2 started (Job 1)
[2026-06-19T09:40:12.480Z] [INFO]   CPU stress thread 2/2 started (Job 3)
[2026-06-19T09:40:12.496Z] [INFO] Starting Memory fault: allocating 1800 MB
[2026-06-19T09:40:12.970Z] [WARN] Memory allocation warning: Exception calling ".ctor" with "1" argument(s): "Exception of type 'System.OutOfMemoryException' was thrown."
[2026-06-19T09:40:12.985Z] [INFO] === FAULT ACTIVE — sampling every 15s for 300s ===
[2026-06-19T09:40:33.309Z] [INFO]   [Sample 1] CPU: 100% | Free RAM: 1908 MB
[2026-06-19T09:40:57.294Z] [INFO]   [Sample 2] CPU: 100% | Free RAM: 1905.9 MB
[2026-06-19T09:41:19.919Z] [INFO]   [Sample 3] CPU: 100% | Free RAM: 1891.1 MB
[2026-06-19T09:41:42.857Z] [INFO]   [Sample 4] CPU: 100% | Free RAM: 1891.4 MB
[2026-06-19T09:42:07.139Z] [INFO]   [Sample 5] CPU: 100% | Free RAM: 1881.9 MB
[2026-06-19T09:42:30.702Z] [INFO]   [Sample 6] CPU: 100% | Free RAM: 1884.2 MB
[2026-06-19T09:42:54.593Z] [INFO]   [Sample 7] CPU: 100% | Free RAM: 1875.9 MB
[2026-06-19T09:43:18.625Z] [INFO]   [Sample 8] CPU: 100% | Free RAM: 1864.8 MB
[2026-06-19T09:43:40.532Z] [INFO]   [Sample 9] CPU: 100% | Free RAM: 1867.2 MB
[2026-06-19T09:44:02.376Z] [INFO]   [Sample 10] CPU: 100% | Free RAM: 1850.5 MB
[2026-06-19T09:44:25.892Z] [INFO]   [Sample 11] CPU: 100% | Free RAM: 1851.2 MB
[2026-06-19T09:44:49.343Z] [INFO]   [Sample 12] CPU: 100% | Free RAM: 1861.3 MB
[2026-06-19T09:45:13.155Z] [INFO]   [Sample 13] CPU: 100% | Free RAM: 1850 MB
[2026-06-19T09:45:16.545Z] [INFO] === STOPPING FAULT — releasing resources ===
[2026-06-19T09:45:17.280Z] [INFO]   CPU job 1 stopped.
[2026-06-19T09:45:17.280Z] [INFO]   CPU job 3 stopped.


Additional Context:
- Azure environment deployed using Terraform
- Compute tower resources: RG, VNet/Subnet, NSG, Public IP, NIC, Windows VM
- Fault injection used a PowerShell script to create CPU/resource exhaustion
- Restore script was written and tested successfully before the fault was run
- Recovery was verified after remediation

Please produce an RCA with these sections:
1. Problem Summary
2. Scope / Environment
3. Timeline
4. Symptoms Observed
5. Evidence Supporting Diagnosis
6. Root Cause Analysis
7. Remediation Applied
8. Recovery Validation
9. Preventive Recommendations
10. AI Assistance Used

Rules:
- Base the RCA only on the evidence provided
- Distinguish direct evidence from symptoms
- Keep the writing professional and suitable for an operations handover
- Include a clear root cause statement
- Include a short preventive action list
- Output in markdown