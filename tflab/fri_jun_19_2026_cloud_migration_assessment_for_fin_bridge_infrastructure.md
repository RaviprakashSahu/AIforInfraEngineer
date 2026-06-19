# Copilot Chat Conversation Export: Cloud migration assessment for FinBridge infrastructure

**User:** @karthik-zippy
**Thread URL:** https://github.com/copilot/c/63582572-d24c-4f96-8b97-81187fa15b45

## @karthik-zippy

```
You are a senior cloud infrastructure architect.

I will provide a description of an existing infrastructure architecture.
Your task is to:
  1. Identify each component and its function
  2. Suggest the closest equivalent service on [TARGET: AWS / Azure / GCP]
  3. Flag components with no direct equivalent and suggest alternatives
  4. Highlight architectural changes required for the target platform
  5. Identify cost or performance implications of the suggested replacements
  6. Provide cost comparison in all 3 clouds 

Constraints:
  - Do not suggest services in preview or deprecated
  - Flag compliance or data residency considerations

Output as a table: 
Component | Current | Equivalent on aws | Equivalent on azure| Equivalent on GCP| Notes
cost comparison table:
Component | cost on aws | cost on azure| cost on GCP| Notes with saving percentage

=== FinBridge On-Premises Infrastructure ===
Organisation: FinBridge Financial Services
Current environment: Private data centre, 


════════════════════════════════════════════════════════
COMPUTE TOWER
════════════════════════════════════════════════════════

Component 1: Application Servers
  Hardware:   4 × Dell PowerEdge R740 (2× Intel Xeon Silver 4214, 64GB RAM each)
  OS:         Red Hat Enterprise Linux 8.6
  Function:   Hosts payment-service (Java 11, -Xmx4g), order-service,
              and customer-api (all Spring Boot microservices)
  HA:         Active-active pair behind F5 BIG-IP load balancer
  Auto-scale: None — manual capacity planning, quarterly review
  Monitoring: Datadog agent, custom JVM metrics via JMX

Component 2: Windows Application Server
  Hardware:   2 × Dell PowerEdge R640 (1× Intel Xeon Bronze 3204, 32GB RAM)
  OS:         Windows Server 2019 Standard
  Function:   Hosts legacy FinBridge Reporting Service (.NET Framework 4.8)
              and internal IIS-based admin portal
  Auth:       Active Directory domain join (finbridge.internal)
  Scheduled tasks: 6 nightly batch jobs (02:00–04:00 UTC)

Component 3: Load Balancer
  Product:    F5 BIG-IP LTM (hardware appliance)
  Function:   Layer 7 load balancing, SSL termination, health checks
  Algorithms: Round-robin with session persistence (cookie-based)
  SSL certs:  Managed on-appliance, renewed annually

════════════════════════════════════════════════════════
NETWORK TOWER
════════════════════════════════════════════════════════

Component 4: Core Network
  Product:    Cisco Catalyst 9300 series switches (core + access layer)
  Topology:   Three-tier: core / distribution / access
  Segmentation: VLANs — VLAN 221 (payment processing), VLAN 304 (internal
               services), VLAN 410 (management), VLAN 500 (DMZ)
  Routing:    OSPF within data centre, BGP to internet via two ISPs

Component 5: Firewall
  Product:    Palo Alto PA-3220 (active-passive HA pair)
  Function:   Perimeter firewall, IDS/IPS, URL filtering
  Rules:      Inbound: HTTPS (443) to DMZ only. All management access
              via jump server on VLAN 410. No direct SSH from internet.
  Zones:      untrust / dmz / trust / management

Component 6: Remote Access / Management
  Product:    Cisco AnyConnect VPN + dedicated jump server
              (Windows Server 2019, VLAN 410)
  Function:   All engineer remote access via VPN + RDP/SSH to jump server
              No direct internet access to production servers

Component 7: DNS
  Product:    Windows DNS (Active Directory integrated)
  Internal zones: finbridge.internal, corp.finbridge.com
  External DNS: Cloudflare (authoritative for finbridge.com)

════════════════════════════════════════════════════════
DB TOWER
════════════════════════════════════════════════════════

Component 8: Primary Database
  Product:    PostgreSQL 14 on RHEL 8.6
  Hardware:   Dell PowerEdge R740xd (2× Xeon Gold 5218, 128GB RAM)
  Databases:  payments_prod (48GB), customers_prod (12GB), orders_prod (31GB)
  Config:     max_connections=200, shared_buffers=32GB, wal_level=replica
  HA:         Streaming replication to one synchronous standby
  Backup:     pg_basebackup nightly (full), WAL archiving continuous
  Monitoring: pg_stat_activity dashboard in Grafana, PgBouncer connection pooler

Component 9: Connection Pooler
  Product:    PgBouncer 1.17
  Function:   Connection pooling between application tier and PostgreSQL
  Mode:       Transaction pooling
  Pool size:  max_client_conn=500, default_pool_size=20

Component 10: Reporting Database
  Product:    MySQL 8.0 on RHEL 8.6 (separate server)
  Function:   Read replica fed from PostgreSQL via custom ETL job (nightly)
  Purpose:    Business intelligence queries, regulatory reporting
  Access:     Read-only by reporting team and Power BI dashboards

════════════════════════════════════════════════════════
STORAGE TOWER
════════════════════════════════════════════════════════

Component 11: Primary NAS
  Product:    NetApp ONTAP FAS2750
  Function:   Primary file storage — /data/prod (340GB application data),
              /data/backups (180GB database backups), /data/shared (60GB)
  Protocols:  NFS v3 (Linux mounts), CIFS/SMB (Windows access)
  HA:         Active-passive controller pair, automatic failover <30 seconds
  Replication: SnapMirror async replication to DR site every 4 hours

Component 12: Block Storage (Database)
  Product:    Pure Storage FlashArray//C (all-NVMe)
  Function:   PostgreSQL data and WAL volumes
  Capacity:   4TB provisioned, 2.1TB used
  Performance: 48,000 IOPS sustained, <1ms latency (SLA requirement)
  Snapshots:  Hourly local snapshots, 24-hour retention, weekly to NAS

Component 13: Object Storage (Internal)
  Product:    MinIO self-hosted (4-node cluster, 12TB usable)
  Function:   Build artefacts, log archives, application static assets
  API:        S3-compatible — all applications use AWS SDK v2
              with custom endpoint override

Component 14: Backup and Archive
  Product:    Veeam Backup & Replication + Quantum LTO-8 tape library
  Function:   Full backup weekly (Sunday 01:00 UTC), incremental nightly
  Retention:  On-site: 30 days (disk). Tape: 7 years (regulatory requirement
              — financial data under FCA rules)
  Off-site:   Physical tape rotation to Iron Mountain every Monday

Component 15: Monitoring
  Product:    NetApp ActiveIQ + custom Grafana dashboards
  Alerts:     Volume >80% WARN, >90% CRITICAL
              Replication lag >15min PAGE, >30min ESCALATE
              IOPS >40,000 sustained >5min WARN

════════════════════════════════════════════════════════
SHARED SERVICES
════════════════════════════════════════════════════════

Component 16: Identity and Access
  Product:    Windows Active Directory (Windows Server 2019)
  Domains:    finbridge.internal (primary), corp.finbridge.com
  Scope:      All Windows servers domain-joined. Linux servers use
              SSSD for AD authentication. Service accounts managed via AD.

Component 17: Monitoring Platform
  Product:    Datadog (SaaS) + on-premises Grafana
  Scope:      Datadog agent on all servers — APM, infrastructure metrics,
              log management. Grafana for custom dashboards (PostgreSQL
              internals, NAS capacity, batch job status).

Component 18: Certificate Management
  Product:    Internal Microsoft CA (Active Directory Certificate Services)
  Scope:      All internal TLS certificates. External certificates via DigiCert.
  Renewal:    Annual — manual process, tracked in spreadsheet. 
--- END ---
```

## Copilot

Here’s a cloud-mapping assessment for the FinBridge on-prem estate, with equivalents across **AWS, Azure, and GCP**, plus key architecture, compliance, and cost/performance notes.

## Architecture equivalence table

| Component | Current | Equivalent on AWS | Equivalent on Azure | Equivalent on GCP | Notes |
|---|---|---|---|---|---|
| 1. Application Servers | 4× RHEL 8.6 Dell app servers running Spring Boot microservices | **Amazon ECS on EC2** or **EKS**; closest VM equivalent: **EC2 + Auto Scaling + ALB** | **Azure Kubernetes Service (AKS)** or **VM Scale Sets + Application Gateway** | **GKE** or **Managed Instance Groups + External/Internal HTTP(S) LB** | Best modernization target is containers, not lift-and-shift VMs. For strict “closest equivalent”, VMs map best; for ops/cost elasticity, container platform is superior. Need redesign for autoscaling, immutable deploys, and centralized secrets/config. |
| 2. Windows Application Server | Windows Server 2019 running .NET Framework 4.8 + IIS + batch jobs | **EC2 Windows Server** + **AWS Systems Manager/Task Scheduler** | **Azure Virtual Machines (Windows)** + **Azure Automation / Task Scheduler** | **Compute Engine Windows** + **Cloud Scheduler/Windows Task Scheduler** | .NET Framework 4.8 has no clean serverless/container-first target unless app is refactored. Azure is usually the most natural target for Windows/IIS/AD-integrated workloads. Batch jobs may move to scheduler + worker pattern later. |
| 3. Load Balancer | F5 BIG-IP LTM | **Application Load Balancer** (+ **AWS WAF**, **ACM**) | **Application Gateway** (+ **WAF**, **Key Vault certs**) | **External Application Load Balancer** (+ **Cloud Armor**, **Certificate Manager**) | No direct full F5 feature parity in native cloud L7 LB. Advanced iRules/LTM-specific logic may require redesign or 3rd-party virtual appliance. SSL termination and cookie persistence supported natively. |
| 4. Core Network | Cisco Catalyst + VLANs + OSPF/BGP | **VPC**, subnets, route tables, **Transit Gateway**, **Direct Connect** | **VNet**, subnets, route tables, **Virtual WAN**, **ExpressRoute** | **VPC**, subnets, **Cloud Router**, **Cloud Interconnect** | No direct equivalent to physical switching fabric. Must translate VLAN/security zones into subnet tiers + NSGs/security groups/firewall policies. Routing becomes software-defined. |
| 5. Firewall | Palo Alto PA-3220 HA pair | **AWS Network Firewall** / **Gateway Load Balancer + Palo Alto VM-Series** | **Azure Firewall Premium** / **Palo Alto VM-Series** | **Cloud Firewall Rules + Cloud NGFW / Palo Alto VM-Series** | IDS/IPS and URL filtering may need premium native tiers or Palo Alto VM-Series for closest parity. If compliance requires existing rule semantics, 3rd-party appliance may be preferred. |
| 6. Remote Access / Management | Cisco AnyConnect VPN + jump server | **AWS Client VPN** + **SSM Session Manager** + optional bastion | **Azure VPN Gateway / P2S VPN** + **Azure Bastion** | **Cloud VPN** + **IAP** + bastion | Strong opportunity to remove always-on jump hosts. AWS SSM and GCP IAP reduce exposed management plane. Azure Bastion is closest managed replacement for RDP/SSH broker model. |
| 7. DNS | Windows DNS (internal), Cloudflare external | **Route 53 Private Hosted Zones** + keep **Cloudflare** external or Route 53 public | **Azure DNS Private Resolver / Private DNS** + keep Cloudflare external or Azure DNS | **Cloud DNS private zones** + keep Cloudflare external or Cloud DNS public | AD-integrated DNS behavior does not map 1:1 unless AD DS remains. If Active Directory stays, DNS may remain tied to managed/self-managed AD. |
| 8. Primary Database | PostgreSQL 14 on RHEL with sync standby, WAL archive | **Amazon RDS for PostgreSQL** or **Aurora PostgreSQL** | **Azure Database for PostgreSQL Flexible Server** | **Cloud SQL for PostgreSQL** or **AlloyDB for PostgreSQL** | Closest managed equivalent is managed PostgreSQL. For high throughput/low latency, AWS Aurora or GCP AlloyDB may outperform standard managed Postgres, but behavior differs. Need review of PgBouncer compatibility, extensions, replication model, backup/RPO, and parameter tuning. |
| 9. Connection Pooler | PgBouncer | **RDS Proxy** (limited for PostgreSQL use cases) or self-managed **PgBouncer on EC2/ECS** | Built-in pooling options are limited; likely **self-managed PgBouncer on VM/container** | **PgBouncer self-managed**; some pooling options via platform features depending on target DB | No universal native direct equivalent with full PgBouncer transaction-pooling semantics. Likely retain PgBouncer as a managed container/VM sidecar service. |
| 10. Reporting Database | MySQL 8.0 fed nightly from PostgreSQL ETL | **Amazon RDS for MySQL** or better analytics target: **Redshift Serverless** | **Azure Database for MySQL** or **Synapse Serverless/Dedicated SQL pool** | **Cloud SQL for MySQL** or **BigQuery** | If this is mostly BI/regulatory reporting, a warehouse is often a better target than MySQL replica-by-ETL. Architectural change likely: ETL/ELT into analytics platform. |
| 11. Primary NAS | NetApp ONTAP NAS via NFS/SMB | **Amazon FSx for NetApp ONTAP** | **Azure NetApp Files** | **Google Cloud NetApp Volumes** / **Filestore Enterprise** | FSx for ONTAP is the closest feature match on AWS. Azure NetApp Files is mature for enterprise NFS/SMB. Replication and snapshot semantics differ slightly by provider. |
| 12. Block Storage (Database) | Pure FlashArray NVMe, 48k IOPS, <1ms | **EBS io2 Block Express** | **Premium SSD v2 / Ultra Disk** | **Hyperdisk Extreme** | This is a performance-sensitive area. Meeting sustained <1ms may be challenging depending on instance type, zone, and DB engine overhead. Managed DB may abstract storage but not guarantee same latency profile. Benchmark required. |
| 13. Object Storage | MinIO 4-node S3-compatible | **Amazon S3** | **Azure Blob Storage** | **Cloud Storage** | AWS S3 is easiest because apps already use AWS SDK v2 and S3 API semantics. Azure/GCP will require SDK/client config changes unless using S3 compatibility gateways. Good migration candidate. |
| 14. Backup and Archive | Veeam + LTO-8 tape, 7-year retention | **AWS Backup** + **S3 Glacier Deep Archive** (+ optional Veeam on AWS) | **Azure Backup** + **Archive Storage** | **Backup and DR Service** + **Cloud Storage Archive** | No direct “physical tape” equivalent. Cloud archive tiers replace tape operationally. Must validate FCA/WORM/immutability/legal hold requirements. May still keep external backup product if audit controls require it. |
| 15. Monitoring (storage) | ActiveIQ + Grafana | **CloudWatch** + Grafana + native storage metrics | **Azure Monitor** + Managed Grafana | **Cloud Monitoring** + Managed Service for Grafana | Native storage telemetry exists, but vendor-specific ONTAP/Pure analytics won’t directly transfer unless those products remain in hybrid mode. |
| 16. Identity and Access | Windows AD for all servers, Linux via SSSD | **AWS Managed Microsoft AD** / self-managed AD + IAM Identity Center | **Microsoft Entra ID + Azure AD DS / self-managed AD** | **Managed Microsoft AD** + Cloud Identity | No single cloud-native service fully replaces classic AD domain services for Windows + LDAP/Kerberos + GPO. Azure is strongest if moving toward Entra, but legacy domain-join workloads may still need managed AD DS. |
| 17. Monitoring Platform | Datadog + Grafana | **Keep Datadog**, optional CloudWatch integration | **Keep Datadog**, optional Azure Monitor integration | **Keep Datadog**, optional Cloud Monitoring integration | Best choice is usually retain Datadog to avoid replatforming observability. Could reduce Grafana footprint with managed Grafana. |
| 18. Certificate Management | Internal Microsoft CA + DigiCert external | **ACM Private CA** + **ACM** | **Key Vault Certificates** + optional **AD CS / partner CA** | **Certificate Authority Service** + **Certificate Manager** | Internal PKI can move to managed private CA, but AD auto-enrollment workflows may need redesign. Manual spreadsheet renewal should be eliminated in all clouds. |

---

## Key architectural changes required

| Area | Required change | Impact |
|---|---|---|
| Compute model | Move from fixed servers to autoscaling instances or containers | Better elasticity, lower idle cost, requires CI/CD and observability maturity |
| Networking | Translate VLAN/zone model into VPC/VNet subnet segmentation, route tables, SG/NSG/firewall policies | Network design becomes policy-driven rather than switch-driven |
| Perimeter security | Replace appliance-centric security with managed firewall/WAF + cloud-native controls | Simpler ops, but possible loss of exact Palo Alto/F5 behavior unless using virtual appliances |
| Remote admin | Replace jump server dependence with brokered admin access (SSM/Bastion/IAP) | Better auditability, reduced attack surface |
| Database HA/backup | Shift from self-managed replication/WAL archiving to managed HA/backup | Less admin overhead, but less OS-level control |
| Storage | Replace NAS/SAN/object silos with managed file/block/object services | Better durability and ops, possible app path/mount and performance changes |
| Reporting | Likely replace nightly PostgreSQL→MySQL ETL with warehouse-based reporting pipeline | Better BI scale and query isolation |
| Identity | Keep AD-compatible services initially, then gradually modernize to cloud IAM/identity | Hybrid identity will likely remain during transition |
| PKI | Replace manual cert lifecycle with managed issuance/rotation | Reduced operational risk |
| Compliance | Explicit region selection, backup immutability, encryption key strategy, audit logging | Mandatory for FCA/regulated workload posture |

---

## No-direct-equivalent / partial-equivalent flags

| Component | Gap | Suggested alternative |
|---|---|---|
| F5 BIG-IP | Native cloud LBs do not fully replicate all advanced F5 features/iRules | Use native ALB/App Gateway/GCLB where possible; otherwise Palo Alto/F5 virtual appliances or redesign app routing logic |
| Cisco switching fabric | No physical switching equivalent | Rebuild segmentation with cloud networking constructs |
| Palo Alto appliance semantics | Native firewalls may not match full IPS/URL filtering behavior | Use premium native firewall or VM-Series |
| PgBouncer transaction pooling | Native DB proxies may not fully match | Keep PgBouncer as self-managed container/VM |
| Tape archive | No physical tape analog | Archive object tier with immutability/retention lock |
| AD-integrated DNS/CA workflows | Partial mapping only | Keep managed/self-managed AD initially; phase to cloud-native DNS/PKI later |

---

## Compliance and data residency considerations

| Topic | Consideration |
|---|---|
| FCA retention | 7-year retention must be mapped to immutable archive policies; verify legal hold, retention lock, and audit evidence |
| Data residency | Must pin workloads and backups to approved regions; avoid cross-region replication outside jurisdiction unless policy allows |
| Encryption | Use customer-managed keys where required: AWS KMS, Azure Key Vault/Managed HSM, GCP Cloud KMS/HSM |
| Access control | Replace shared admin access with federated identity + MFA + just-in-time admin |
| Logging/audit | Enable immutable audit trails: CloudTrail, Azure Activity Logs, Cloud Audit Logs; centralize SIEM export |
| PII/payment data | If card/payment data involved, validate PCI DSS scope, segmentation, and managed service certifications |
| Backup sovereignty | Archive tiers and DR replication may silently cross borders if misconfigured; needs explicit region policy |

---

## Cost and performance implications by component

These are **directional monthly estimates**, not quotes. I’m assuming production-grade HA deployments in one region, excluding taxes, support plans, and committed-use discounts. Costs vary heavily by region and usage.

| Component | cost on AWS | cost on Azure | cost on GCP | Notes with saving percentage |
|---|---:|---:|---:|---|
| Application Servers | $900–$1,400 | $950–$1,500 | $850–$1,350 | GCP often lowest on steady VM/container compute. Savings vs current on-prem usually **10–30%** if rightsized; more if containerized/autoscaled. |
| Windows App Server | $450–$750 | $400–$700 | $500–$800 | Azure often cheapest for Windows due to licensing efficiencies/Hybrid Benefit. Savings **5–20%** if existing Windows licenses are reusable. |
| Load Balancer | $50–$150 | $70–$180 | $40–$140 | Native cloud LBs are usually cheaper than appliance ownership/support; savings **40–70%** vs hardware LB TCO. |
| Network / Core | $300–$1,000 | $350–$1,100 | $250–$900 | Depends on VPN/Interconnect/NAT/egress. Cloud networking can be cheaper operationally but egress may erase savings. |
| Firewall | $500–$2,000 | $700–$2,200 | $400–$1,800 | Native firewall cheaper than VM-Series; appliance-like parity costs more. Savings range from **-10% to +40%** depending on throughput. |
| Remote Access / Bastion | $50–$250 | $120–$300 | $30–$150 | GCP IAP and AWS SSM can be much cheaper than full-time bastion/jump hosts. Savings **30–80%**. |
| DNS | $20–$100 | $20–$120 | $20–$80 | Low cost in all clouds. Keeping Cloudflare may remain best externally. Savings negligible. |
| Primary PostgreSQL DB | $1,500–$4,500 | $1,800–$4,800 | $1,600–$5,000 | Managed HA PostgreSQL costs more than self-managed VMs but reduces ops. Aurora/AlloyDB can improve performance but may raise spend. Savings often **-20% to +15%** depending on admin cost included. |
| Connection Pooler | $50–$200 | $50–$250 | $50–$200 | Usually self-managed small footprint. Negligible overall cost. |
| Reporting DB / Analytics | $250–$1,500 | $300–$1,800 | $200–$1,400 | If moved to warehouse/query-per-use, GCP BigQuery can be cheapest for bursty BI; Azure strong if Power BI heavy. Savings **10–50%** depending on workload pattern. |
| NAS / File Storage | $600–$2,500 | $700–$3,000 | $600–$2,800 | Azure NetApp Files often premium-priced; AWS FSx for ONTAP close feature match; GCP NetApp competitive in some regions. Savings **-10% to +20%**. |
| Block Storage | $700–$2,500 | $800–$2,800 | $700–$2,700 | High-IOPS storage is expensive in cloud. Savings may be negative if current array is amortized. Need benchmarking. |
| Object Storage | $100–$350 | $120–$400 | $100–$300 | S3/GCS are usually cheaper and more durable than self-hosted MinIO ops burden. Savings **20–60%** excluding migration effort. |
| Backup + Archive | $300–$1,200 | $350–$1,300 | $250–$1,100 | Archive tiers cheaper than tape logistics over time, but retrieval costs apply. Savings **15–50%** operationally. |
| Monitoring Storage/Infra | $50–$250 | $70–$300 | $50–$250 | Mostly small if Grafana managed. |
| Identity / Directory | $300–$1,000 | $250–$900 | $300–$1,000 | Azure often best economics if already Microsoft-heavy. Savings **0–25%**. |
| Monitoring Platform | $1,000–$3,000 | $1,000–$3,000 | $1,000–$3,000 | Datadog cost likely unchanged across clouds. Biggest savings come from log/APM tuning, not provider choice. |
| Certificate Management | $50–$400 | $30–$300 | $40–$350 | Managed private CA cost can exceed self-hosted CA infra but lowers risk. Savings often operational, not direct infra. |

---

## Overall cloud fit summary

| Cloud | Best fit areas | Weak areas | Likely outcome |
|---|---|---|---|
| AWS | Best S3 migration path, FSx for ONTAP, strong managed infra breadth, mature RDS/Aurora, strong admin access via SSM | Windows/.NET Framework and AD modernization less natural than Azure | Strong all-round target, especially for Linux, PostgreSQL, and S3-compatible app estate |
| Azure | Best for Windows Server, IIS, AD-integrated services, Power BI/reporting alignment | S3-compatible migration less direct; some storage/services can be premium-priced | Best target if legacy Microsoft workloads and identity dominate decisions |
| GCP | Strong price/performance in compute, BigQuery for analytics, clean ops model, strong private connectivity | Windows/AD ecosystem less natural; S3 compatibility weakest natively | Best if analytics modernization and cost-efficient Linux/container platform are priorities |

---

## Recommended target pattern

**If FinBridge wants least disruption:**  
- **Azure** for Windows/AD-heavy alignment, managed PostgreSQL, Azure NetApp Files, Blob, Azure Firewall/Bastion.

**If FinBridge wants best balance for current app patterns:**  
- **AWS** for Linux microservices, S3-compatible object migration, FSx for ONTAP, RDS/Aurora PostgreSQL, AWS Backup/Glacier.

**If FinBridge wants analytics-first modernization and lowest steady compute cost:**  
- **GCP** with GKE, AlloyDB/Cloud SQL, BigQuery, Cloud Storage, NetApp Volumes.

## Practical recommendation
For this exact estate, my ranking would be:

1. **AWS** — best overall functional fit with least friction for Linux apps + S3-compatible MinIO workloads  
2. **Azure** — best if the legacy Windows/.NET/AD/reporting stack is business-critical  
3. **GCP** — best if FinBridge is willing to modernize reporting and some identity patterns

If you want, I can next produce one of these:
1. a **more precise costed BOM** with assumed instance sizes and monthly totals for all 3 clouds, or  
2. a **migration-wave plan**: Wave 1–4 by dependency and risk.
