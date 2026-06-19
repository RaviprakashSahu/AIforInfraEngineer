# Copilot Chat Conversation Export: Reusable prompt for validating network architecture

**User:** @karthik-zippy
**Thread URL:** https://github.com/copilot/c/fa9536ac-2b2b-4dfd-ab44-8a263fcdf5ba

## @karthik-zippy

i want you to create a prompt which will generate a promot for validating network architecture . To generate the prompt as me genric questions around the architecute and i want this prompt is reusable

## Copilot

Yes — I can help with that.

To build a **reusable prompt generator** for **validating network architecture**, I should first ask you a set of **generic architecture questions**. Your answers will let me produce a prompt template you can reuse across projects.

Reply in any format you want, but this structure is easiest:

## Generic questions about the architecture

1. **What is the scope of the architecture to validate?**  
   - Enterprise network, cloud network, hybrid, datacenter, branch, SaaS, Kubernetes, etc.

2. **What is the primary goal of validation?**  
   - Security, resilience, scalability, performance, compliance, cost optimization, operational simplicity, disaster recovery, etc.

3. **What environments are in scope?**  
   - Production, staging, development, DR, multi-region, multi-cloud, on-prem.

4. **What are the major network zones or segments?**  
   - Internet edge, DMZ, internal apps, databases, management, partner network, user/VPN, cloud VPC/VNet segments, etc.

5. **What connectivity patterns exist?**  
   - North-south, east-west, site-to-site VPN, ExpressRoute/Direct Connect, transit gateway, peering, SD-WAN, MPLS, internet breakout.

6. **What critical applications or services depend on this architecture?**  
   - Customer-facing apps, APIs, ERP, databases, identity systems, monitoring, backup, etc.

7. **What are the expected traffic characteristics?**  
   - Bandwidth, latency sensitivity, burstiness, throughput, real-time traffic, backup traffic, replication, etc.

8. **What availability and resilience requirements exist?**  
   - HA, redundancy, failover time, RTO, RPO, active-active vs active-passive.

9. **What security controls are expected?**  
   - Firewalls, IDS/IPS, segmentation, zero trust, NAC, WAF, DDoS protection, TLS inspection, bastion access, PAM, etc.

10. **What identity and access assumptions apply?**  
    - AD/Entra/Okta integration, RBAC, least privilege, admin access paths, service-to-service auth.

11. **What compliance or regulatory requirements apply?**  
    - ISO 27001, SOC 2, PCI-DSS, HIPAA, GDPR, NIST, internal standards.

12. **What cloud providers, platforms, or technologies are involved?**  
    - AWS, Azure, GCP, VMware, Cisco, Palo Alto, Fortinet, Juniper, Arista, Kubernetes, service mesh, etc.

13. **What routing and traffic management mechanisms are used?**  
    - BGP, OSPF, static routing, load balancers, DNS-based routing, Anycast, NAT, proxies.

14. **What observability and operations capabilities exist?**  
    - Logs, metrics, flow logs, packet capture, SIEM, NMS, alerting, tracing, config backup, automation.

15. **What failure scenarios should the validation cover?**  
    - Link failure, AZ/region outage, firewall failure, routing misconfiguration, DNS failure, DDoS, compromised host, etc.

16. **What are the biggest current concerns or known weak points?**  
    - Single points of failure, manual processes, poor segmentation, inconsistent routing, insufficient visibility, cost, etc.

17. **Who is the audience for the validation output?**  
    - Network architects, security team, leadership, auditors, operations, customer.

18. **What form should the validation result take?**  
    - Checklist, design review, risk register, scorecard, gap analysis, recommendations, executive summary.

19. **Should the prompt validate against best practices, internal standards, or both?**  
   - Best practices only, internal standards only, or compare both.

20. **How reusable do you want the prompt to be?**  
   - Fully generic across all networks, cloud-focused, enterprise-focused, security-focused, etc.

---

## If you want, answer with this short template

```text
Scope:
Validation goal:
Environments:
Network zones:
Connectivity patterns:
Critical services:
Traffic characteristics:
Availability requirements:
Security controls:
Identity/access:
Compliance:
Platforms/technologies:
Routing/load balancing:
Observability:
Failure scenarios:
Known concerns:
Audience:
Output format:
Validation baseline:
Reuse preference:
```

## After you answer
I will generate one of these for you:
1. a **reusable master prompt template**, or  
2. a **prompt generator prompt** that asks these questions automatically and then produces a validation prompt.

If you want, I can also skip the questions and give you a **ready-to-use reusable prompt template now**.
