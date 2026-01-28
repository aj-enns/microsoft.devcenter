# Operations Guide - Microsoft DevCenter Solution

**Document Version:** 1.0  
**Last Updated:** January 28, 2026  
**Classification:** Internal  
**Status:** Draft

---

## Table of Contents

1. [Overview](#overview)
2. [Daily Operations](#daily-operations)
3. [Weekly Operations](#weekly-operations)
4. [Monthly Operations](#monthly-operations)
5. [Quarterly Operations](#quarterly-operations)
6. [Operational Runbooks](#operational-runbooks)
7. [Monitoring & Alerting](#monitoring--alerting)
8. [Incident Management](#incident-management)
9. [Maintenance Windows](#maintenance-windows)
10. [Operational Metrics & KPIs](#operational-metrics--kpis)

---

## Overview

This Operations Guide provides detailed procedures, schedules, and runbooks for the day-to-day management of the Microsoft DevCenter (Dev Box) solution. It complements the [RACI Matrix](RACI-MATRIX.md) by providing the "how" to the RACI's "who."

### Purpose

- Define recurring operational tasks and schedules
- Provide step-by-step runbooks for common operations
- Establish monitoring and alerting procedures
- Document incident response procedures
- Track operational metrics and KPIs

### Scope

| In Scope | Out of Scope |
|----------|--------------|
| DevCenter infrastructure operations | Project-specific development tasks |
| Image lifecycle management | Application code deployments |
| Pool provisioning and maintenance | End-user Dev Box usage |
| Security baseline enforcement | Business application testing |
| Cost monitoring and optimization | Individual developer workflows |

---

## Daily Operations

### Infrastructure Team

| Task | Time | Description | Runbook |
|------|------|-------------|---------|
| **Health Check** | 08:00 | Verify DevCenter service health | [RB-001](#rb-001-daily-health-check) |
| **Alert Review** | 08:30 | Review overnight alerts and incidents | [RB-002](#rb-002-alert-triage) |
| **Capacity Check** | 09:00 | Monitor pool capacity and utilization | [RB-003](#rb-003-capacity-monitoring) |
| **Backup Verification** | 10:00 | Verify Terraform state backup success | [RB-004](#rb-004-backup-verification) |
| **Standup Participation** | 10:30 | Daily ops standup with Endpoint Team | - |

```mermaid
flowchart LR
    subgraph Morning["Morning Routine (08:00-11:00)"]
        A["08:00 Health Check"] --> B["08:30 Alert Review"]
        B --> C["09:00 Capacity Check"]
        C --> D["10:00 Backup Verify"]
        D --> E["10:30 Standup"]
    end
```

### Endpoint Team

| Task | Time | Description | Runbook |
|------|------|-------------|---------|
| **Image Build Status** | 08:00 | Check overnight image build results | [RB-010](#rb-010-image-build-review) |
| **Intune Sync Status** | 08:30 | Verify Intune policy sync health | [RB-011](#rb-011-intune-sync-check) |
| **Definition Validation** | 09:00 | Validate devbox-definitions.json | [RB-012](#rb-012-definition-validation) |
| **Standup Participation** | 10:30 | Daily ops standup with Infrastructure Team | - |

### Security Team

| Task | Time | Description | Runbook |
|------|------|-------------|---------|
| **Security Alert Review** | 08:00 | Review Defender/Sentinel alerts | [RB-020](#rb-020-security-alert-review) |
| **Access Request Queue** | 09:00 | Process pending access requests | [RB-021](#rb-021-access-request-processing) |
| **Compliance Dashboard** | 14:00 | Review compliance posture | [RB-022](#rb-022-compliance-review) |

---

## Weekly Operations

### Monday

| Team | Task | Description | Runbook |
|------|------|-------------|---------|
| Infrastructure | **Terraform Plan Review** | Review any pending infrastructure changes | [RB-100](#rb-100-terraform-plan-review) |
| Endpoint | **Image Pipeline Review** | Review queued image builds for the week | [RB-101](#rb-101-image-pipeline-review) |
| Security | **Weekly Security Review** | Conduct weekly security posture meeting | - |

### Tuesday

| Team | Task | Description | Runbook |
|------|------|-------------|---------|
| Infrastructure | **Network Review** | Review NSG logs and network health | [RB-102](#rb-102-network-review) |
| Endpoint | **Patch Assessment** | Assess pending OS/software patches | [RB-103](#rb-103-patch-assessment) |

### Wednesday

| Team | Task | Description | Runbook |
|------|------|-------------|---------|
| All Teams | **CAB Meeting** | Change Advisory Board (bi-weekly) | - |
| Infrastructure | **Cost Trend Analysis** | Review daily cost trends | [RB-104](#rb-104-cost-analysis) |

### Thursday

| Team | Task | Description | Runbook |
|------|------|-------------|---------|
| Endpoint | **Image Deprecation Review** | Identify images approaching end-of-life | [RB-105](#rb-105-image-deprecation) |
| Security | **Vulnerability Scan Review** | Review weekly vulnerability scan results | [RB-106](#rb-106-vulnerability-review) |

### Friday

| Team | Task | Description | Runbook |
|------|------|-------------|---------|
| Infrastructure | **Capacity Planning** | Update capacity forecasts | [RB-107](#rb-107-capacity-planning) |
| All Teams | **Weekly Summary Report** | Prepare operational summary | [RB-108](#rb-108-weekly-report) |

```mermaid
flowchart TD
    subgraph Week["Weekly Schedule"]
        MON["Monday\n• TF Plan Review\n• Image Pipeline\n• Security Review"]
        TUE["Tuesday\n• Network Review\n• Patch Assessment"]
        WED["Wednesday\n• CAB Meeting\n• Cost Analysis"]
        THU["Thursday\n• Image Deprecation\n• Vuln Scan Review"]
        FRI["Friday\n• Capacity Planning\n• Weekly Report"]
    end
    
    MON --> TUE --> WED --> THU --> FRI
```

---

## Monthly Operations

### First Week of Month

| Day | Team | Task | Description |
|-----|------|------|-------------|
| 1st | Finance/IT | **Cost Review Meeting** | Review previous month's costs by team |
| 2nd | Infrastructure | **Reserved Instance Review** | Assess RI utilization and recommendations |
| 3rd | Endpoint | **Image Lifecycle Report** | Report on image versions and usage |
| 4th | Security | **Access Recertification Kickoff** | Initiate monthly access reviews |
| 5th | All Teams | **Service Level Review** | Review SLA/SLO performance |

### Second Week of Month

| Day | Team | Task | Description |
|-----|------|------|-------------|
| 8th | Endpoint | **Maintenance Window** | Scheduled image updates (if needed) |
| 9th | Infrastructure | **DR Test (if scheduled)** | Monthly DR validation |
| 10th | Security | **Policy Compliance Audit** | Review Intune/CA policy compliance |

### Third Week of Month

| Day | Team | Task | Description |
|-----|------|------|-------------|
| 15th | Info Governance | **Data Classification Review** | Review new data classification requests |
| 16th | Infrastructure | **Performance Baseline Update** | Update performance baselines |
| 17th | Security | **Security Baseline Review** | Assess security baseline effectiveness |

### Fourth Week of Month

| Day | Team | Task | Description |
|-----|------|------|-------------|
| 22nd | All Teams | **Change Freeze Review** | Plan around upcoming holidays/freezes |
| 25th | Infrastructure | **Capacity Forecast Update** | Update 90-day capacity forecast |
| Last Day | All Teams | **Monthly Operations Report** | Publish monthly ops report |

---

## Quarterly Operations

### Q1 (January-March)

| Task | Owner | Timing | Description |
|------|-------|--------|-------------|
| Annual Planning Support | All Teams | January | Support annual IT planning cycle |
| Disaster Recovery Full Test | Infrastructure | February | Full DR failover test |
| Access Recertification (Full) | Security | March | Comprehensive access review |
| Budget Reforecast | Eng/Platform Teams | March | Q1 actuals and reforecast |

### Q2 (April-June)

| Task | Owner | Timing | Description |
|------|-------|--------|-------------|
| Security Assessment | Security | April | External penetration test support |
| Image Strategy Review | Endpoint | May | Review image catalogue strategy |
| Mid-Year Budget Review | All Teams | June | Cost optimization review |

### Q3 (July-September)

| Task | Owner | Timing | Description |
|------|-------|--------|-------------|
| Business Continuity Review | Infrastructure | July | BCP documentation update |
| Compliance Audit Support | All Teams | August | Support annual compliance audits |
| Technology Refresh Planning | Endpoint | September | Plan hardware/software updates |

### Q4 (October-December)

| Task | Owner | Timing | Description |
|------|-------|--------|-------------|
| Year-End Change Freeze | All Teams | December | Reduced changes during holidays |
| Annual Policy Review | Security/IG | November | Update all operational policies |
| Capacity Planning (Annual) | Infrastructure | October | Annual capacity forecast |
| Budget Planning | All Teams | October-November | Next year budget preparation |

---

## Operational Runbooks

### Infrastructure Runbooks

#### RB-001: Daily Health Check

**Purpose:** Verify DevCenter service health each morning  
**Owner:** Infrastructure Team  
**Frequency:** Daily @ 08:00  
**Duration:** 15 minutes

**Prerequisites:**
- Azure Portal access
- DevCenter Reader permissions
- Access to monitoring dashboards

**Procedure:**

```powershell
# Step 1: Check Azure Service Health
# Navigate to: Azure Portal > Service Health > DevCenter

# Step 2: Verify DevCenter Status via CLI
az devcenter admin devcenter list \
    --query "[].{Name:name, State:provisioningState}" \
    --output table

# Step 3: Check all Projects
az devcenter admin project list \
    --query "[].{Name:name, State:provisioningState}" \
    --output table

# Step 4: Verify Network Connections
az devcenter admin network-connection list \
    --query "[].{Name:name, HealthStatus:healthCheckStatus}" \
    --output table
```

**Expected Results:**
| Check | Expected Status |
|-------|----------------|
| DevCenter | Succeeded |
| Projects | Succeeded |
| Network Connections | Passed |

**Escalation:** If any checks fail → [RB-002](#rb-002-alert-triage)

---

#### RB-002: Alert Triage

**Purpose:** Review and triage overnight alerts  
**Owner:** Infrastructure Team  
**Frequency:** Daily @ 08:30  
**Duration:** 30 minutes

**Alert Priority Matrix:**

| Severity | Response Time | Examples |
|----------|--------------|----------|
| Critical (P1) | 15 minutes | Service outage, security breach |
| High (P2) | 1 hour | Pool provisioning failures, network issues |
| Medium (P3) | 4 hours | Capacity warnings, cost anomalies |
| Low (P4) | 24 hours | Informational, optimization suggestions |

**Procedure:**

1. **Review Azure Monitor Alerts**
   ```
   Azure Portal > Monitor > Alerts > Filter: Last 24 hours
   ```

2. **Check Log Analytics Workspace**
   ```kusto
   // DevCenter errors in last 24 hours
   AzureDiagnostics
   | where TimeGenerated > ago(24h)
   | where Category == "DevCenter"
   | where Level == "Error"
   | summarize count() by Resource, OperationName
   ```

3. **Document and Assign**
   - Create tickets for unresolved alerts
   - Assign based on [RACI Matrix](RACI-MATRIX.md)
   - Update status dashboard

---

#### RB-003: Capacity Monitoring

**Purpose:** Monitor pool capacity and utilization  
**Owner:** Infrastructure Team  
**Frequency:** Daily @ 09:00  
**Duration:** 20 minutes

**Capacity Thresholds:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Pool Utilization | > 70% | > 85% |
| Available Quota | < 30% | < 15% |
| Pending Requests | > 10 | > 25 |

**Procedure:**

```powershell
# List all pools with their current usage
$pools = az devcenter admin pool list --project-name "<project>" --output json | ConvertFrom-Json

foreach ($pool in $pools) {
    Write-Host "Pool: $($pool.name)"
    Write-Host "  Status: $($pool.provisioningState)"
    Write-Host "  Dev Box Count: $($pool.devBoxCount)"
    Write-Host "---"
}
```

**Actions:**
- If utilization > 70%: Review with Business Platform Teams
- If utilization > 85%: Initiate capacity expansion request
- If pending requests > 25: Escalate to management

---

#### RB-004: Backup Verification

**Purpose:** Verify Terraform state and configuration backups  
**Owner:** Infrastructure Team  
**Frequency:** Daily @ 10:00  
**Duration:** 10 minutes

**Procedure:**

1. **Verify Terraform State Backend**
   ```powershell
   # Check blob storage for state file
   az storage blob show \
       --account-name "<storage-account>" \
       --container-name "tfstate" \
       --name "terraform.tfstate" \
       --query "{LastModified:properties.lastModified, Size:properties.contentLength}"
   ```

2. **Verify State Lock**
   ```powershell
   # Ensure no stale locks
   az storage blob lease show \
       --account-name "<storage-account>" \
       --container-name "tfstate" \
       --blob-name "terraform.tfstate"
   ```

3. **Document in Daily Log**
   - Record last backup time
   - Note any anomalies

---

### Endpoint Team Runbooks

#### RB-010: Image Build Review

**Purpose:** Review overnight image build results  
**Owner:** Endpoint Team  
**Frequency:** Daily @ 08:00  
**Duration:** 20 minutes

**Procedure:**

1. **Check CI/CD Pipeline**
   - Review Azure DevOps / GitHub Actions for image builds
   - Note any failed builds

2. **Verify Gallery Images**
   ```powershell
   # List recent image versions
   az sig image-version list \
       --gallery-name "<gallery>" \
       --gallery-image-definition "<image-def>" \
       --resource-group "<rg>" \
       --query "[?publishingProfile.publishedDate > '$(Get-Date).AddDays(-1).ToString('yyyy-MM-dd'))']"
   ```

3. **Validate Build Artifacts**
   - Check Packer logs for warnings
   - Verify security baseline inclusion
   - Confirm provisioner success

**Build Failure Actions:**

| Failure Type | Action |
|--------------|--------|
| Packer validation | Review template syntax |
| Provisioner failure | Check script logs |
| Gallery publish | Verify permissions and quota |
| Security scan | Escalate to Security Team |

---

#### RB-011: Intune Sync Check

**Purpose:** Verify Intune policy synchronization  
**Owner:** Endpoint Team  
**Frequency:** Daily @ 08:30  
**Duration:** 15 minutes

**Procedure:**

1. **Microsoft Endpoint Manager Admin Center**
   ```
   endpoint.microsoft.com > Devices > Monitor > Device compliance
   ```

2. **Check Policy Deployment Status**
   - Review compliance percentage
   - Identify non-compliant devices
   - Check policy sync timestamps

3. **Common Issues:**

| Issue | Resolution |
|-------|------------|
| Sync pending > 24h | Force device sync |
| Policy conflict | Review policy assignments |
| Certificate error | Renew/reissue certificates |

---

#### RB-012: Definition Validation

**Purpose:** Validate devbox-definitions.json integrity  
**Owner:** Endpoint Team  
**Frequency:** Daily @ 09:00  
**Duration:** 10 minutes

**Procedure:**

```powershell
# Run validation script
.\infrastructure\scripts\00-validate-definitions.ps1

# Expected output: All definitions valid
```

**Validation Checks:**
- JSON syntax valid
- All referenced images exist in gallery
- SKU names are valid
- Storage profiles are correct

---

### Security Team Runbooks

#### RB-020: Security Alert Review

**Purpose:** Review and triage security alerts  
**Owner:** Security Team  
**Frequency:** Daily @ 08:00  
**Duration:** 45 minutes

**Alert Sources:**
- Microsoft Defender for Cloud
- Microsoft Sentinel
- Azure AD Identity Protection
- Conditional Access reports

**Severity Classification:**

| Severity | Response SLA | Examples |
|----------|-------------|----------|
| Critical | 15 min | Active breach, malware detected |
| High | 1 hour | Suspicious sign-in, privilege escalation |
| Medium | 4 hours | Policy violation, unusual activity |
| Low | 24 hours | Informational, best practice deviation |

---

#### RB-021: Access Request Processing

**Purpose:** Process pending access requests  
**Owner:** Security Team  
**Frequency:** Daily @ 09:00  
**Duration:** 30-60 minutes

**Request Types:**

| Type | SLA | Approval Required |
|------|-----|-------------------|
| Standard Pool Access | 4 hours | Auto-approved (if eligible) |
| Premium Pool Access | 1 business day | Manager + Security |
| Admin Access | 2 business days | Director + Security |
| Emergency Access | 1 hour | Security Manager |

**Procedure:**

1. Review pending requests in ticketing system
2. Verify requestor identity and manager approval
3. Check business justification
4. Apply principle of least privilege
5. Set access expiration (time-bound access)
6. Document decision and notify requestor

---

#### RB-022: Compliance Review

**Purpose:** Review daily compliance posture  
**Owner:** Security Team  
**Frequency:** Daily @ 14:00  
**Duration:** 20 minutes

**Compliance Checks:**

```kusto
// Non-compliant resources
SecurityRecommendation
| where TimeGenerated > ago(24h)
| where State == "Unhealthy"
| summarize count() by RecommendationDisplayName
| order by count_ desc
```

**Dashboard Review:**
- Secure Score trend
- Non-compliant resource count
- Policy compliance percentage
- Conditional Access failures

---

## Monitoring & Alerting

### Alert Configuration

| Alert Name | Condition | Severity | Team |
|------------|-----------|----------|------|
| DevCenter Unhealthy | Health != Healthy | Critical | Infrastructure |
| Pool Capacity Warning | Utilization > 70% | Warning | Infrastructure |
| Pool Capacity Critical | Utilization > 85% | Critical | Infrastructure |
| Image Build Failure | Build Status = Failed | High | Endpoint |
| Network Connection Unhealthy | Health Check Failed | Critical | Infrastructure |
| Cost Anomaly | Spend > 120% forecast | Medium | Infrastructure + BU |
| Security Baseline Drift | Compliance < 95% | High | Security |
| Failed Sign-ins Spike | > 50 in 1 hour | High | Security |
| Defender Alert | Any High/Critical | High | Security |

### Monitoring Dashboards

| Dashboard | Owner | Refresh Rate | Purpose |
|-----------|-------|--------------|---------|
| DevCenter Operations | Infrastructure | 5 min | Overall service health |
| Image Pipeline | Endpoint | 15 min | Build status and gallery |
| Security Posture | Security | 15 min | Compliance and threats |
| Cost Analytics | Infrastructure | Daily | Spend tracking |
| User Adoption | Business | Weekly | Usage metrics |

### Log Analytics Queries

**DevCenter Error Summary:**
```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DEVCENTER"
| where Level == "Error"
| summarize ErrorCount=count() by bin(TimeGenerated, 1h), OperationName
| render timechart
```

**Pool Utilization Trend:**
```kusto
AzureMetrics
| where ResourceProvider == "Microsoft.DevCenter"
| where MetricName == "DevBoxCount"
| summarize AvgCount=avg(Total) by bin(TimeGenerated, 1h), Resource
| render timechart
```

---

## Incident Management

### Incident Classification

| Priority | Impact | Response | Resolution Target |
|----------|--------|----------|-------------------|
| P1 - Critical | Service outage, all users affected | 15 min | 2 hours |
| P2 - High | Major feature unavailable, many users | 30 min | 4 hours |
| P3 - Medium | Partial degradation, some users | 2 hours | 8 hours |
| P4 - Low | Minor issue, workaround available | 4 hours | 24 hours |

### Incident Response Flow

```mermaid
flowchart TD
    A[🚨 Incident Detected] --> B{Auto-Remediation<br/>Available?}
    B -->|Yes| C[Execute Automation]
    B -->|No| D[Page On-Call]
    
    C --> E{Resolved?}
    E -->|Yes| F[Document & Close]
    E -->|No| D
    
    D --> G[Assess Impact]
    G --> H{Priority?}
    
    H -->|P1| I[War Room<br/>All Hands]
    H -->|P2| J[Dedicated Team]
    H -->|P3/P4| K[Queue for<br/>Next Business Day]
    
    I --> L[Continuous Updates<br/>Every 15 min]
    J --> M[Updates Every<br/>30 min]
    
    L --> N[Resolution]
    M --> N
    K --> N
    
    N --> O[Post-Incident Review]
    O --> P[Update Runbooks]
    
    style A fill:#ffcdd2
    style N fill:#c8e6c9
```

### Communication Templates

**P1 Incident - Initial Notification:**
```
SUBJECT: [P1 INCIDENT] DevCenter - <Brief Description>

Impact: <Description of user impact>
Status: Investigating
Started: <Time>
Next Update: <Time + 15 min>

Teams Engaged: Infrastructure, <others>
Bridge: <Teams/Zoom link>
```

**P1 Incident - Resolution:**
```
SUBJECT: [RESOLVED] DevCenter - <Brief Description>

Resolution: <What fixed it>
Duration: <Start time> to <End time>
Root Cause: <Brief RCA>
Post-Incident Review: <Scheduled date/time>
```

---

## Maintenance Windows

### Standard Maintenance Windows

| Window | Day | Time (UTC) | Duration | Type |
|--------|-----|------------|----------|------|
| Image Updates | Tuesday | 02:00-06:00 | 4 hours | Planned |
| Infrastructure | Wednesday | 02:00-04:00 | 2 hours | Planned |
| Security Patches | Thursday | 02:00-06:00 | 4 hours | Planned |
| Emergency | Any | ASAP | Variable | Unplanned |

### Maintenance Notification Requirements

| Change Type | Notice Required | Approval |
|-------------|----------------|----------|
| Standard (pre-approved) | 24 hours | Auto |
| Normal | 5 business days | CAB |
| Major | 2 weeks | CAB + Director |
| Emergency | ASAP (post-approval OK) | Security Manager |

### Change Freeze Periods

| Period | Dates | Exceptions |
|--------|-------|------------|
| Year-End | Dec 15 - Jan 5 | Security-critical only |
| Quarter-End | Last 3 days | Security-critical only |
| Major Events | As announced | None |

---

## Operational Metrics & KPIs

### Service Level Objectives (SLOs)

| Metric | Target | Measurement |
|--------|--------|-------------|
| DevCenter Availability | 99.9% | Azure Monitor |
| Pool Provisioning Success | 99% | Build logs |
| Image Build Success Rate | 95% | CI/CD pipeline |
| Mean Time to Provision | < 30 min | End-to-end timing |
| Security Compliance Rate | > 98% | Defender for Cloud |
| Incident Response (P1) | < 15 min | Ticketing system |
| Incident Resolution (P1) | < 2 hours | Ticketing system |

### Monthly KPI Dashboard

| KPI | Formula | Target | Owner |
|-----|---------|--------|-------|
| **Availability** | Uptime / Total Time | 99.9% | Infrastructure |
| **MTTR** | Total downtime / Incidents | < 30 min | Infrastructure |
| **Change Success Rate** | Successful / Total Changes | > 95% | All Teams |
| **Image Freshness** | Images < 30 days / Total | > 90% | Endpoint |
| **Cost Variance** | Actual / Budget | ± 10% | All Teams |
| **User Satisfaction** | Survey Score | > 4.0/5.0 | All Teams |

### Reporting Schedule

| Report | Frequency | Audience | Owner |
|--------|-----------|----------|-------|
| Daily Operations Summary | Daily | Ops Teams | Infrastructure |
| Weekly Status Report | Weekly | IT Leadership | Infrastructure |
| Monthly Operations Review | Monthly | IT + Business | All Teams |
| Quarterly Business Review | Quarterly | Executives | All Teams |

---

## Appendix: Quick Reference

### Key Contacts

| Role | Team | Escalation Path |
|------|------|-----------------|
| Infrastructure On-Call | Infrastructure | PagerDuty → Slack #devbox-ops |
| Security On-Call | Security | PagerDuty → Slack #security-alerts |
| Endpoint On-Call | Endpoint | PagerDuty → Slack #devbox-ops |

### Important Links

| Resource | URL |
|----------|-----|
| Azure Portal | portal.azure.com |
| DevCenter Admin | portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.DevCenter |
| Monitoring Dashboard | <internal-dashboard-url> |
| Runbook Library | <internal-wiki-url> |
| On-Call Schedule | <pagerduty-schedule-url> |

### Related Documents

- [RACI Matrix](RACI-MATRIX.md) - Who does what
- [Architecture](ARCHITECTURE.md) - System design
- [Workflows](WORKFLOWS.md) - Process diagrams
- [Security Design](SECURITY-DESIGN.md) - Security architecture
- [Cost and Access Control](COST-AND-ACCESS-CONTROL.md) - Financial governance

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | January 28, 2026 | Operations Team | Initial release |
