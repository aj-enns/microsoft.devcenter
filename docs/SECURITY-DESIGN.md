# Security Architecture Design Document

**Document Version:** 1.0  
**Last Updated:** December 2, 2025  
**Classification:** Internal  
**Intended Audience:** Security Architects, Compliance Officers, Operations Leadership

## Executive Summary

This document describes the security architecture for Microsoft DevCenter deployment using Terraform with separation of duties. The design implements defense-in-depth principles, zero-trust access controls, and least-privilege RBAC to provide a secure, compliant development environment for multiple teams.

**Key Security Principles:**
- ✅ **Zero Trust Architecture** - All access explicitly verified, no implicit trust
- ✅ **Least Privilege Access** - RBAC enforced at all layers with minimal permissions
- ✅ **Separation of Duties** - Clear boundaries between operations and development teams
- ✅ **Defense in Depth** - Multiple security layers prevent single point of failure
- ✅ **Audit & Compliance** - All actions logged and traceable
- ✅ **Security Baseline Enforcement** - Mandatory security controls across all Dev Box images

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Identity and Access Management](#identity-and-access-management)
3. [Network Security](#network-security)
4. [Data Protection](#data-protection)
5. [Compute Security](#compute-security)
6. [Secrets Management](#secrets-management)
7. [Monitoring and Logging](#monitoring-and-logging)
8. [Compliance Controls](#compliance-controls)
9. [Threat Model](#threat-model)
10. [Security Boundaries](#security-boundaries)
11. [Incident Response](#incident-response)

---

## Architecture Overview

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Microsoft Entra ID (Azure AD)               │
│  - User Authentication                                          │
│  - Service Principal Authentication                             │
│  - Conditional Access Policies                                  │
│  - MFA Enforcement                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Azure Role-Based Access Control               │
│  - Operations Team: Contributor + User Access Admin             │
│  - Dev Teams: Gallery Contributor (limited)                     │
│  - Service Principals: Scoped to specific resources             │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────────┐    ┌──────────────┐
│ DevCenter    │    │ Virtual Network  │    │ Compute      │
│ & Project    │    │ + Subnet         │    │ Gallery      │
│              │    │                  │    │              │
│ - Identity   │    │ - Azure AD Join  │    │ - Base       │
│ - Pools      │    │ - NSG Rules      │    │   Images     │
│ - Definitions│    │ - No Public IPs  │    │ - Team       │
└──────────────┘    └──────────────────┘    │   Images     │
                                             └──────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │   Dev Box VMs    │
                    │                  │
                    │ - Azure AD Join  │
                    │ - Intune Managed │
                    │ - Defender       │
                    │ - Firewall       │
                    │ - Audit Logs     │
                    └──────────────────┘
```

### Security Layers

1. **Identity Layer** - Microsoft Entra ID authentication + conditional access
2. **Authorization Layer** - Azure RBAC with least-privilege assignments
3. **Network Layer** - Virtual network isolation, no public IPs, NSG rules
4. **Compute Layer** - Azure AD joined VMs, Intune policies, security baseline
5. **Data Layer** - Encryption at rest and in transit
6. **Monitoring Layer** - Centralized logging, audit trails, alerting

---

## Identity and Access Management

### Authentication Mechanisms

#### Human Identities

**Microsoft Entra ID (Azure AD) Integration:**
- All users authenticate via Microsoft Entra ID
- Single Sign-On (SSO) enforced across all services
- Multi-Factor Authentication (MFA) required for privileged operations
- Conditional Access policies based on:
  - User location
  - Device compliance state
  - Risk level (Azure AD Identity Protection)
  - Network location (trusted IPs only)

**Access Levels:**
```
┌─────────────────────┬──────────────────────────────────────────┐
│ Role                │ Access Scope                             │
├─────────────────────┼──────────────────────────────────────────┤
│ Operations Team     │ Full: DevCenter, Network, Gallery, RBAC  │
│ Security Team       │ Read: All resources + Security configs   │
│ Network Team        │ Contributor: Virtual Networks only       │
│ Dev Team Leads      │ Contributor: Team gallery images only    │
│ Developers          │ Reader: Infrastructure (create Dev Boxes)│
│ Service Principals  │ Scoped: Specific resource actions only   │
└─────────────────────┴──────────────────────────────────────────┘
```

#### Service Identities

**Service Principal: SP-DevBox-Infrastructure**
- **Purpose:** Operations team automation (Terraform, pipelines)
- **Permissions:**
  - Contributor on resource group
  - User Access Administrator (for RBAC assignments)
  - Limited to infrastructure scope only
- **Authentication:** Client secret stored in Azure Key Vault
- **Secret Rotation:** 90-day rotation policy enforced

**Service Principal: SP-DevBox-Images**
- **Purpose:** Development teams image builds (Packer)
- **Permissions:**
  - Reader on resource group
  - Contributor on Azure Compute Gallery only
  - **Cannot** modify infrastructure, networks, or DevCenter
- **Authentication:** Client secret stored in Azure Key Vault
- **Secret Rotation:** 90-day rotation policy enforced

**Managed Identities:**
- User-assigned managed identity for DevCenter operations
- No credential management required
- RBAC permissions scoped to specific actions
- Used for:
  - Gallery image replication
  - Network connection management
  - Log Analytics integration

### Authorization Model (RBAC)

**Principle of Least Privilege Applied:**

```terraform
# Example: Operations Team Role Assignment
resource "azurerm_role_assignment" "operations" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = var.operations_team_group_id
}

# Example: Dev Team Limited Gallery Access
resource "azurerm_role_assignment" "dev_team_gallery" {
  scope                = azurerm_shared_image_gallery.main.id
  role_definition_name = "Contributor"
  principal_id         = var.dev_team_group_id
}
```

**Custom Roles (if needed):**
- DevBox Pool Manager (limited to pool creation/deletion)
- Gallery Image Publisher (limited to image versions only)
- Network Connection Viewer (read-only network status)

### Separation of Duties

**Two-Repository Model:**

1. **Infrastructure Repository** (Operations Team)
   - Owner: @operations-team
   - Approvers: Senior Operations Engineers
   - Contains: Terraform configs, network settings, security baseline
   - CODEOWNERS enforced for all changes

2. **Images Repository** (Development Teams)
   - Owner: @dev-leads
   - Approvers: Development Team Leads
   - Contains: Packer templates, team tooling, DevBox definitions
   - CODEOWNERS per team folder (`/teams/java-team/**` = @java-team-leads)

**Access Control Matrix:**

| Resource                | Operations | Security | Network | Dev Leads | Developers |
|-------------------------|-----------|----------|---------|-----------|------------|
| DevCenter Infrastructure| **Write** | Read     | Read    | Read      | Read       |
| Virtual Networks        | Write     | Read     | **Write**| Read     | Read       |
| Azure Compute Gallery   | **Write** | Read     | Read    | **Write** | Read       |
| Base Security Image     | **Write** | **Write**| Read    | Read      | Read       |
| Team Images             | Read      | Read     | Read    | **Write** | Read       |
| DevBox Definitions      | Read      | Read     | Read    | **Write** | Read       |
| Service Principal Creds | **Write** | Read     | None    | None      | None       |
| Key Vault Secrets       | **Write** | Read     | None    | None      | None       |

---

## Network Security

### Virtual Network Isolation

**Network Architecture:**
```
Azure Virtual Network: 10.0.0.0/16
├── DevBox Subnet: 10.0.1.0/24
│   ├── No Public IPs allowed
│   ├── Azure AD Domain Services join subnet
│   └── NSG: Restrictive inbound/outbound rules
│
└── Management Subnet: 10.0.2.0/24 (future)
    └── Reserved for operations tooling
```

**Network Security Group (NSG) Rules:**

**Inbound Rules:**
```
Priority | Name                  | Source         | Destination | Port  | Action
---------|----------------------|----------------|-------------|-------|-------
100      | AllowAzureAD         | AzureActiveDirectory | * | 443   | Allow
200      | AllowAzureMonitor    | AzureMonitor    | *          | 443   | Allow
300      | DenyAllInbound       | *               | *          | *     | Deny
```

**Outbound Rules:**
```
Priority | Name                  | Source | Destination         | Port  | Action
---------|----------------------|--------|---------------------|-------|-------
100      | AllowAzureServices   | *      | AzureCloud          | 443   | Allow
200      | AllowInternet        | *      | Internet            | 80,443| Allow
300      | DenyAllOutbound      | *      | *                   | *     | Deny
```

**Network Connection Security:**
- Azure AD Join enforced (no local accounts)
- Hybrid Azure AD Join for on-premises integration
- No direct internet access (via NAT Gateway if needed)
- Azure Firewall for egress filtering (optional)

**Private Endpoints (Recommended):**
- Azure Storage (for Packer builds)
- Azure Key Vault (for secret retrieval)
- Azure Container Registry (if custom containers used)

---

## Data Protection

### Encryption

**Data at Rest:**
- ✅ **OS Disks:** Azure Disk Encryption with platform-managed keys
- ✅ **Data Disks:** Customer-managed keys (CMK) optional via Key Vault
- ✅ **Gallery Images:** Encrypted by default with Microsoft-managed keys
- ✅ **Storage Accounts:** SSE (Storage Service Encryption) enabled
- ✅ **Key Vault Secrets:** Hardware Security Module (HSM) backed (Premium tier)

**Data in Transit:**
- ✅ **TLS 1.2+** enforced for all connections
- ✅ **Azure AD authentication** uses HTTPS/TLS
- ✅ **RDP access** via Azure Bastion (no public RDP allowed)
- ✅ **Service-to-service:** Private endpoints or service endpoints

### Data Classification

**Sensitivity Levels:**

| Level        | Description                          | Protection Measures                    |
|--------------|--------------------------------------|----------------------------------------|
| **Public**   | Non-sensitive project docs           | Standard encryption, no access control |
| **Internal** | Development code, test data          | RBAC, encryption at rest, audit logs   |
| **Confidential** | Customer data, credentials       | Key Vault, CMK, strict RBAC, DLP       |
| **Restricted**   | Service principal secrets, PII   | Key Vault Premium, access reviews, PIM |

**Data Loss Prevention (DLP):**
- Microsoft Purview integration (optional)
- Intune app protection policies
- Conditional Access policies prevent unapproved cloud storage

---

## Compute Security

### Dev Box Security Baseline

**Mandatory Provisioners (Enforced in Base Image):**

1. **Azure AD Join Configuration**
   ```powershell
   # Ensures all Dev Boxes join Azure AD
   Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
     -Name "DisableAutomaticRestartSignOn" -Value 0
   ```

2. **Microsoft Defender Configuration**
   ```powershell
   # Real-time protection, cloud-delivered protection
   Set-MpPreference -DisableRealtimeMonitoring $false
   Set-MpPreference -MAPSReporting Advanced
   ```

3. **Windows Firewall Enforcement**
   ```powershell
   # All profiles enabled, cannot be disabled by users
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
   ```

4. **Audit Logging**
   ```powershell
   # Process creation, logon events, privilege use
   auditpol /set /subcategory:"Process Creation" /success:enable
   ```

5. **Security Baselines**
   - CIS Benchmark compliance (optional)
   - Microsoft Security Baseline applied
   - STIG hardening (government/regulated industries)

**Intune Integration:**
- Device compliance policies enforced
- Conditional Access checks device health
- Non-compliant devices blocked from access
- Automatic patching via Windows Update for Business

### Image Security Validation

**CI/CD Pipeline Checks:**

1. **Syntax Validation** - Packer HCL syntax correct
2. **Security Baseline Verification** - Base provisioners present
3. **Dangerous Pattern Detection** - No security-disabling commands
4. **Dependency Scanning** - Outdated/vulnerable packages flagged
5. **Compliance Checks** - Required software installed

**Example Validation:**
```yaml
# .github/workflows/validate-devbox-images.yml
- name: Validate Base Provisioners
  run: |
    if ! grep -q 'source.*security-baseline.pkr.hcl' "$FILE"; then
      echo "ERROR: Missing security baseline"
      exit 1
    fi
```

---

## Secrets Management

### Azure Key Vault Integration

**Key Vault Configuration:**
```terraform
resource "azurerm_key_vault" "main" {
  name                = "kv-devbox-secrets"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"  # HSM-backed
  
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = false
  enable_rbac_authorization       = true  # RBAC, not access policies
  
  purge_protection_enabled = true
  soft_delete_retention_days = 90
}
```

**Secrets Stored:**
- Service Principal client secrets
- Terraform Enterprise API tokens
- DevOps pipeline credentials
- Third-party API keys (if needed)

**Access Control:**
```terraform
# Operations team can manage secrets
resource "azurerm_role_assignment" "ops_kv_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.operations_team_group_id
}

# Service principals can only read their own secret
resource "azurerm_role_assignment" "sp_kv_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}
```

**Secret Rotation Policy:**
- **Service Principal Secrets:** 90-day rotation (automated via Azure DevOps)
- **TFE API Tokens:** 180-day rotation (manual)
- **Third-party Credentials:** Per vendor requirements

**Azure DevOps Variable Groups:**
- Option A: Direct secrets (development/testing)
- **Option B: Key Vault linked** (production - recommended)
  - Secrets stored in Key Vault only
  - Variable groups reference Key Vault secrets
  - No secrets stored in Azure DevOps directly

---

## Monitoring and Logging

### Audit Logging

**Azure Activity Logs:**
- All control plane operations logged
- Retained for 90 days minimum
- Exported to Log Analytics workspace

**Resource Diagnostic Logs:**
```terraform
resource "azurerm_monitor_diagnostic_setting" "devcenter" {
  name               = "devcenter-diagnostics"
  target_resource_id = azurerm_dev_center.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  enabled_log {
    category = "Administrative"
  }
  enabled_log {
    category = "Security"
  }
  metric {
    category = "AllMetrics"
  }
}
```

**Logged Events:**
- ✅ DevCenter pool creation/deletion
- ✅ DevBox VM start/stop/delete
- ✅ RBAC role assignments
- ✅ Network connection changes
- ✅ Gallery image publications
- ✅ Key Vault secret access
- ✅ Service principal authentication
- ✅ Failed authentication attempts

### Security Monitoring

**Microsoft Defender for Cloud:**
- Enabled on subscription
- Security recommendations monitored
- Compliance dashboard reviewed monthly
- Automatic remediation for known issues

**Alerts Configured:**
- High-severity security recommendations
- Unusual authentication patterns
- RBAC role assignment changes
- Network security group modifications
- Dev Box VMs created outside approved pools
- Failed MFA attempts (threshold: 3)

**SIEM Integration:**
- Log Analytics workspace as central log store
- Microsoft Sentinel (optional) for threat detection
- Custom KQL queries for security events

---

## Compliance Controls

### Regulatory Frameworks Supported

- **ISO 27001** - Information Security Management
- **SOC 2 Type II** - Trust Services Criteria
- **NIST 800-53** - Federal security controls
- **CIS Benchmarks** - Center for Internet Security
- **HIPAA** - Healthcare data (if applicable)
- **GDPR** - European data protection (if applicable)

### Azure Policy Enforcement

**Built-in Policies Applied:**
```terraform
resource "azurerm_subscription_policy_assignment" "devcenter_policies" {
  name                 = "devcenter-compliance"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/..."
  
  # Example policies:
  # - Require tags on resources
  # - Disallow public IPs
  # - Require encryption at rest
  # - Require Azure AD join for VMs
  # - Require Defender enabled
}
```

**Custom Policies:**
1. **DevBox must use approved images** - Only gallery images allowed
2. **Service principals must use Key Vault** - No plain text secrets
3. **Network connections must be private** - No public endpoints
4. **Images must include base provisioners** - Security baseline enforced

### Audit Requirements

**Change Management:**
- All infrastructure changes via Terraform (auditable)
- Pull request approval required (GitHub/Azure DevOps)
- CODEOWNERS enforced for critical paths
- Merge history retained indefinitely

**Access Reviews:**
- Quarterly review of RBAC assignments
- Annual review of service principal permissions
- Privileged Identity Management (PIM) for elevated access
- Just-in-Time (JIT) access for emergency operations

---

## Threat Model

### Identified Threats and Mitigations

#### Threat 1: Unauthorized Access to Dev Boxes

**Attack Vector:** Attacker compromises user credentials

**Mitigations:**
- ✅ MFA required for all users
- ✅ Conditional Access policies (trusted locations, compliant devices)
- ✅ Azure AD Identity Protection (risk-based access)
- ✅ No local administrator accounts
- ✅ Intune device compliance checks

**Residual Risk:** Low

---

#### Threat 2: Privilege Escalation

**Attack Vector:** Developer attempts to gain operations team access

**Mitigations:**
- ✅ Strict RBAC enforcement (least privilege)
- ✅ Separation of duties (two repositories)
- ✅ Code review required for all changes
- ✅ CI/CD pipeline validation prevents unauthorized changes
- ✅ Audit logs track all role assignments

**Residual Risk:** Low

---

#### Threat 3: Malicious Image Deployment

**Attack Vector:** Developer creates image without security baseline

**Mitigations:**
- ✅ CI/CD validation enforces base provisioners
- ✅ Gallery images cryptographically signed
- ✅ Image build pipelines isolated (separate service principal)
- ✅ Operations team can quarantine/delete malicious images
- ✅ Pull request approval required before build

**Residual Risk:** Low

---

#### Threat 4: Data Exfiltration

**Attack Vector:** User copies sensitive data to unauthorized location

**Mitigations:**
- ✅ Intune app protection policies (DLP)
- ✅ Conditional Access prevents unapproved cloud storage
- ✅ Network egress filtering (Azure Firewall optional)
- ✅ Audit logs track file access
- ✅ Microsoft Purview DLP policies (optional)

**Residual Risk:** Medium (requires additional DLP tooling)

---

#### Threat 5: Service Principal Compromise

**Attack Vector:** Attacker obtains service principal credentials

**Mitigations:**
- ✅ Secrets stored in Key Vault (never plain text)
- ✅ 90-day secret rotation enforced
- ✅ RBAC limits SP permissions (least privilege)
- ✅ Audit logs track all SP authentication
- ✅ Conditional Access for service principals (if supported)
- ✅ IP restrictions on Key Vault access

**Residual Risk:** Medium (requires vigilant secret rotation)

---

#### Threat 6: Network-Based Attacks

**Attack Vector:** Lateral movement within virtual network

**Mitigations:**
- ✅ No public IPs on Dev Boxes
- ✅ NSG rules restrict traffic
- ✅ Azure Firewall for egress filtering (optional)
- ✅ Micro-segmentation via subnets
- ✅ Azure Bastion for remote access (no direct RDP)

**Residual Risk:** Low

---

## Security Boundaries

### Trust Boundaries

```
┌───────────────────────────────────────────────────────────────┐
│ Internet (Untrusted)                                          │
└───────────────────────────────────────────────────────────────┘
                           │
                           ▼ (TLS 1.2+, Azure AD Auth)
┌───────────────────────────────────────────────────────────────┐
│ Azure Control Plane (Partially Trusted)                       │
│ - Azure Portal, ARM API                                       │
│ - Authenticated users only                                    │
└───────────────────────────────────────────────────────────────┘
                           │
                           ▼ (RBAC enforced)
┌───────────────────────────────────────────────────────────────┐
│ Infrastructure Management Plane (Trusted - Operations Team)   │
│ - Terraform, Azure CLI                                        │
│ - Service Principal: SP-DevBox-Infrastructure                 │
└───────────────────────────────────────────────────────────────┘
                           │
                ┌──────────┴──────────┐
                ▼                     ▼
┌─────────────────────────┐  ┌─────────────────────────┐
│ DevCenter Resources     │  │ Image Build Plane       │
│ (Trusted)               │  │ (Semi-Trusted)          │
│ - Operations managed    │  │ - Dev teams managed     │
│ - Full control          │  │ - Limited permissions   │
└─────────────────────────┘  └─────────────────────────┘
                │                     │
                └──────────┬──────────┘
                           ▼
                ┌─────────────────────────┐
                │ Virtual Network         │
                │ (Isolated)              │
                │ - No public IPs         │
                │ - NSG rules enforced    │
                └─────────────────────────┘
                           │
                           ▼
                ┌─────────────────────────┐
                │ Dev Box VMs (User Plane)│
                │ - Azure AD joined       │
                │ - Intune managed        │
                │ - Defender enabled      │
                └─────────────────────────┘
```

### Isolation Mechanisms

1. **Repository Isolation** - Separate Git repos for infrastructure vs images
2. **RBAC Isolation** - Service principals cannot cross boundaries
3. **Network Isolation** - Virtual network, private endpoints, NSG rules
4. **Resource Isolation** - Azure Compute Gallery shared, DevCenter isolated
5. **Credential Isolation** - Key Vault RBAC prevents unauthorized secret access

---

## Incident Response

### Detection Mechanisms

**Automated Alerts:**
- Azure Monitor alert rules for anomalous activity
- Microsoft Defender for Cloud security alerts
- Key Vault access outside business hours
- Multiple failed authentication attempts
- RBAC role assignment changes

**Manual Reviews:**
- Weekly: Security recommendation review (Defender for Cloud)
- Monthly: Access reviews (RBAC assignments)
- Quarterly: Service principal permission audits

### Response Procedures

#### Incident Severity Levels

| Severity | Example                                  | Response Time |
|----------|------------------------------------------|---------------|
| **P1**   | Service principal compromise             | 15 minutes    |
| **P2**   | Unauthorized RBAC change                 | 1 hour        |
| **P3**   | Failed MFA attempts                      | 4 hours       |
| **P4**   | Non-compliant device detected            | 24 hours      |

#### Response Workflow

1. **Detection** - Alert triggered via Azure Monitor
2. **Triage** - Security team assesses severity
3. **Containment** - Disable compromised accounts/SPs immediately
4. **Investigation** - Review audit logs (Azure Activity Log, Key Vault logs)
5. **Remediation** - Rotate secrets, revoke RBAC, patch vulnerabilities
6. **Recovery** - Restore from known-good state (Terraform)
7. **Post-Incident Review** - Document lessons learned, update runbooks

### Emergency Contacts

| Role                     | Contact Method       | Escalation Path       |
|--------------------------|----------------------|-----------------------|
| Security Team Lead       | PagerDuty + Teams    | CISO                  |
| Operations Team Lead     | Email + Teams        | VP Operations         |
| Azure Support            | Azure Portal Ticket  | Microsoft TAM         |
| Incident Commander       | Emergency Hotline    | Executive Leadership  |

---

## Security Review Checklist

**For Security Architects:**

- [ ] All users authenticate via Azure AD with MFA
- [ ] Service principals use Key Vault for secrets
- [ ] RBAC follows least-privilege principle
- [ ] Network connections are private (no public IPs)
- [ ] Dev Boxes are Azure AD joined and Intune managed
- [ ] Security baseline image enforced across all teams
- [ ] Encryption at rest enabled (OS disks, gallery images)
- [ ] Audit logging enabled (Activity Log, diagnostics)
- [ ] Azure Policy enforces compliance (tags, encryption, AAD join)
- [ ] Separation of duties enforced (two repos, CODEOWNERS)
- [ ] CI/CD pipelines validate security controls
- [ ] Secret rotation policies defined and automated
- [ ] Incident response procedures documented
- [ ] Quarterly access reviews scheduled
- [ ] Microsoft Defender for Cloud enabled

---

## Appendix A: Security Best Practices References

**Microsoft Documentation:**
- [Azure Security Best Practices](https://learn.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns)
- [Azure RBAC Best Practices](https://learn.microsoft.com/en-us/azure/role-based-access-control/best-practices)
- [Managed Identity Best Practices](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations)
- [Azure Identity Management Security](https://learn.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices)
- [Zero Trust Architecture](https://learn.microsoft.com/en-us/security/zero-trust/)
- [Conditional Access Policies](https://learn.microsoft.com/en-us/azure/active-directory/conditional-access/overview)

**Industry Standards:**
- CIS Azure Foundations Benchmark
- NIST Cybersecurity Framework
- ISO 27001/27002
- OWASP Top 10

---

## Appendix B: Deployment Security Configuration

**Example Terraform Security Configuration:**

```terraform
# Enforce HTTPS/TLS 1.2+ on storage accounts
resource "azurerm_storage_account" "secure" {
  min_tls_version              = "TLS1_2"
  enable_https_traffic_only    = true
  allow_nested_items_to_be_public = false
}

# Network Security Group with restrictive rules
resource "azurerm_network_security_group" "devbox" {
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Key Vault with RBAC and purge protection
resource "azurerm_key_vault" "secure" {
  sku_name                   = "premium"
  enable_rbac_authorization  = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
}
```

---

## Document Revision History

| Version | Date           | Author          | Changes                          |
|---------|----------------|-----------------|----------------------------------|
| 1.0     | Dec 2, 2025    | Security Team   | Initial security design document |

---

**Approval Signatures:**

- **Security Architect:** ___________________________ Date: ___________
- **CISO:** ___________________________ Date: ___________
- **Operations Lead:** ___________________________ Date: ___________
