# Cost Management and Access Control Guide

This document defines how to control who can deploy Dev Boxes, restrict access to expensive VM SKUs, and manage budgets for the DevBox environment.

## Table of Contents

- [Access Control Model](#access-control-model)
- [Pool-Based Access Control](#pool-based-access-control)
- [SKU Governance](#sku-governance)
- [Azure Budget Configuration](#azure-budget-configuration)
- [Cost Monitoring](#cost-monitoring)
- [Implementation Guide](#implementation-guide)

---

## Access Control Model

### How Access Works in DevCenter

Access is controlled at **three levels**:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Azure AD Security Groups                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Level 1: DevCenter Project Access                               │
│  Role: "DevCenter Dev Box User"                                  │
│  Scope: Project                                                  │
│  Who: All developers who need Dev Boxes                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Level 2: Pool Access (Future - requires custom roles or tags)  │
│  Control which teams can use which pools                         │
│  Expensive SKUs → Senior Developers only                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Level 3: Per-User Limits                                        │
│  max_dev_boxes_per_user = 10 (configurable in Terraform)         │
│  Prevents runaway provisioning                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Current Access Configuration

| Control | Location | Default | Description |
|---------|----------|---------|-------------|
| Project Access | `infrastructure/modules/devcenter/main.tf` | Single group/user | Who can access the DevCenter project |
| Max DevBoxes/User | `infrastructure/variables.tf` | 10 | Maximum Dev Boxes per user |
| Auto-Stop Schedule | `images/definitions/devbox-definitions.json` | 16:00 EST | Daily shutdown time |

---

## Pool-Based Access Control

### Strategy: Separate Pools by Cost Tier

Create pools with different SKU sizes and assign access to security groups:

```
┌────────────────────────────────────────────────────────────────────┐
│ Standard Pools (All Developers)                                    │
│ ├── VSCode-Standard-Pool (8 vCPU, 32GB RAM, 256GB)                │
│ ├── Java-Standard-Pool (8 vCPU, 32GB RAM, 256GB)                  │
│ └── DotNet-Standard-Pool (8 vCPU, 32GB RAM, 256GB)                │
│     Est. Cost: ~$0.34/hour per Dev Box                            │
└────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│ Power User Pools (Senior Developers / Leads)                       │
│ ├── VSCode-Power-Pool (16 vCPU, 64GB RAM, 512GB)                  │
│ └── Java-Power-Pool (16 vCPU, 64GB RAM, 512GB)                    │
│     Est. Cost: ~$0.68/hour per Dev Box                            │
│     Access: SG-DevBox-PowerUsers                                  │
└────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│ High-Performance Pools (Data Science / ML Engineers)               │
│ └── DataScience-Pool (32 vCPU, 128GB RAM, 1TB)                    │
│     Est. Cost: ~$1.36/hour per Dev Box                            │
│     Access: SG-DevBox-DataScience                                 │
└────────────────────────────────────────────────────────────────────┘
```

### Implementation: Multiple Projects Pattern

Since DevCenter doesn't support pool-level RBAC natively, use **multiple DevCenter Projects** for cost segregation:

```hcl
# infrastructure/modules/devcenter/main.tf

# Standard Project - All developers
resource "azurerm_dev_center_project" "standard" {
  name                       = "${var.project_name}-standard"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  dev_center_id              = azurerm_dev_center.main.id
  maximum_dev_boxes_per_user = 5
}

# Power Users Project - Senior developers
resource "azurerm_dev_center_project" "power" {
  name                       = "${var.project_name}-power"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  dev_center_id              = azurerm_dev_center.main.id
  maximum_dev_boxes_per_user = 3
}

# Data Science Project - ML/DS engineers
resource "azurerm_dev_center_project" "datascience" {
  name                       = "${var.project_name}-datascience"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  dev_center_id              = azurerm_dev_center.main.id
  maximum_dev_boxes_per_user = 2
}
```

### Role Assignments by Security Group

```hcl
# Grant DevCenter Dev Box User role to appropriate groups

# All developers → Standard project
resource "azurerm_role_assignment" "standard_devbox_user" {
  scope                = azurerm_dev_center_project.standard.id
  role_definition_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/45d50f46-0b78-4001-a660-4198cbe8cd05"
  principal_id         = var.all_developers_group_id
  principal_type       = "Group"
}

# Power users → Power project
resource "azurerm_role_assignment" "power_devbox_user" {
  scope                = azurerm_dev_center_project.power.id
  role_definition_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/45d50f46-0b78-4001-a660-4198cbe8cd05"
  principal_id         = var.power_users_group_id
  principal_type       = "Group"
}

# Data science team → Data Science project
resource "azurerm_role_assignment" "datascience_devbox_user" {
  scope                = azurerm_dev_center_project.datascience.id
  role_definition_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/45d50f46-0b78-4001-a660-4198cbe8cd05"
  principal_id         = var.datascience_group_id
  principal_type       = "Group"
}
```

---

## SKU Governance

### Available DevBox SKUs and Costs

| SKU Name | vCPUs | RAM | Storage | Est. Hourly Cost | Monthly (8hr/day) |
|----------|-------|-----|---------|------------------|-------------------|
| `general_i_8c32gb256ssd_v2` | 8 | 32 GB | 256 GB | ~$0.34 | ~$55 |
| `general_i_8c32gb512ssd_v2` | 8 | 32 GB | 512 GB | ~$0.38 | ~$61 |
| `general_i_8c32gb1024ssd_v2` | 8 | 32 GB | 1 TB | ~$0.45 | ~$72 |
| `general_i_16c64gb256ssd_v2` | 16 | 64 GB | 256 GB | ~$0.68 | ~$109 |
| `general_i_16c64gb512ssd_v2` | 16 | 64 GB | 512 GB | ~$0.72 | ~$115 |
| `general_i_16c64gb1024ssd_v2` | 16 | 64 GB | 1 TB | ~$0.82 | ~$131 |
| `general_i_32c128gb512ssd_v2` | 32 | 128 GB | 512 GB | ~$1.36 | ~$218 |
| `general_i_32c128gb1024ssd_v2` | 32 | 128 GB | 1 TB | ~$1.46 | ~$234 |
| `general_i_32c128gb2048ssd_v2` | 32 | 128 GB | 2 TB | ~$1.66 | ~$266 |

*Costs are estimates and vary by region. Check Azure pricing calculator for current rates.*

### SKU Assignment by Role

Update `images/definitions/devbox-definitions.json` to define tiers:

```json
{
  "definitions": [
    {
      "name": "VSCode-DevBox-Standard",
      "imageName": "VSCodeDevImage",
      "imageVersion": "1.0.0",
      "computeSku": "general_i_8c32gb256ssd_v2",
      "storageType": "ssd_256gb",
      "hibernationSupport": "Disabled",
      "team": "all-developers",
      "tier": "standard",
      "description": "Standard VS Code environment"
    },
    {
      "name": "VSCode-DevBox-Power",
      "imageName": "VSCodeDevImage",
      "imageVersion": "1.0.0",
      "computeSku": "general_i_16c64gb512ssd_v2",
      "storageType": "ssd_512gb",
      "hibernationSupport": "Disabled",
      "team": "senior-developers",
      "tier": "power",
      "description": "Power user VS Code environment"
    },
    {
      "name": "DataScience-DevBox",
      "imageName": "DataScienceDevImage",
      "imageVersion": "1.0.0",
      "computeSku": "general_i_32c128gb1024ssd_v2",
      "storageType": "ssd_1024gb",
      "hibernationSupport": "Disabled",
      "team": "datascience-team",
      "tier": "high-performance",
      "description": "ML/Data Science workloads"
    }
  ],
  "pools": [
    {
      "name": "VSCode-Standard-Pool",
      "definitionName": "VSCode-DevBox-Standard",
      "project": "standard",
      "administrator": "Enabled",
      "schedule": { "time": "18:00", "timeZone": "Eastern Standard Time" }
    },
    {
      "name": "VSCode-Power-Pool",
      "definitionName": "VSCode-DevBox-Power",
      "project": "power",
      "administrator": "Enabled",
      "schedule": { "time": "18:00", "timeZone": "Eastern Standard Time" }
    },
    {
      "name": "DataScience-Pool",
      "definitionName": "DataScience-DevBox",
      "project": "datascience",
      "administrator": "Enabled",
      "schedule": { "time": "18:00", "timeZone": "Eastern Standard Time" }
    }
  ]
}
```

---

## Azure Budget Configuration

### Setting Up Budget Alerts

Add to `infrastructure/main.tf`:

```hcl
# Budget for DevBox resources
resource "azurerm_consumption_budget_resource_group" "devbox" {
  name              = "budget-devbox-monthly"
  resource_group_id = azurerm_resource_group.main.id

  amount     = 5000  # $5,000 monthly budget
  time_grain = "Monthly"

  time_period {
    start_date = "2026-01-01T00:00:00Z"
    end_date   = "2027-12-31T23:59:59Z"
  }

  notification {
    enabled        = true
    threshold      = 50.0
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = [
      "devops-team@company.com",
      "finance@company.com"
    ]
  }

  notification {
    enabled        = true
    threshold      = 80.0
    operator       = "GreaterThan"
    threshold_type = "Actual"

    contact_emails = [
      "devops-team@company.com",
      "finance@company.com",
      "it-management@company.com"
    ]
  }

  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    threshold_type = "Forecasted"

    contact_emails = [
      "devops-team@company.com",
      "finance@company.com",
      "it-management@company.com"
    ]
  }
}
```

### Budget Variables

Add to `infrastructure/variables.tf`:

```hcl
variable "monthly_budget_amount" {
  description = "Monthly budget for DevBox resources in USD"
  type        = number
  default     = 5000
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
  default     = []
}
```

---

## Cost Monitoring

### Azure Cost Management Queries

```powershell
# Get current month's DevBox costs
$startDate = (Get-Date).ToString("yyyy-MM-01")
$endDate = (Get-Date).ToString("yyyy-MM-dd")

az consumption usage list `
  --start-date $startDate `
  --end-date $endDate `
  --query "[?contains(instanceName, 'devbox') || contains(meterCategory, 'Virtual Machines')]" `
  -o table

# Get cost by user (requires Azure Cost Management API)
az costmanagement query `
  --type "Usage" `
  --timeframe "MonthToDate" `
  --dataset-aggregation '{"totalCost": {"name": "Cost", "function": "Sum"}}' `
  --dataset-grouping '{"type": "TagKey", "name": "CreatedBy"}'
```

### Cost Dashboard Setup

Create an Azure Dashboard with:

1. **Total DevBox Spend (MTD)**
2. **Spend by Pool/Definition**
3. **Active Dev Boxes Count**
4. **Average Cost per User**
5. **Trend over Time**

### Tagging Strategy for Cost Allocation

Add tags to track costs by team:

```hcl
# infrastructure/main.tf
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "DevCenter"
    Project     = "DevBox"
    CostCenter  = var.cost_center
    ManagedBy   = "Operations-Team"
  }
}
```

---

## Implementation Guide

### Step 1: Create Security Groups in Azure AD

```powershell
# Create security groups for access tiers
az ad group create --display-name "SG-DevBox-AllDevelopers" --mail-nickname "sg-devbox-all"
az ad group create --display-name "SG-DevBox-PowerUsers" --mail-nickname "sg-devbox-power"
az ad group create --display-name "SG-DevBox-DataScience" --mail-nickname "sg-devbox-ds"

# Get group IDs
$allDevsGroup = az ad group show --group "SG-DevBox-AllDevelopers" --query id -o tsv
$powerGroup = az ad group show --group "SG-DevBox-PowerUsers" --query id -o tsv
$dsGroup = az ad group show --group "SG-DevBox-DataScience" --query id -o tsv
```

### Step 2: Update Terraform Variables

```hcl
# terraform.tfvars
all_developers_group_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
power_users_group_id    = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
datascience_group_id    = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

monthly_budget_amount   = 5000
budget_alert_emails     = ["devops@company.com", "finance@company.com"]
```

### Step 3: Deploy Infrastructure

```powershell
cd infrastructure
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 4: Configure Definitions and Pools

```powershell
# Update definitions JSON with tiered pools
# Then run:
.\scripts\03-create-definitions.ps1
.\scripts\04-sync-pools.ps1
```

### Step 5: Add Users to Groups

```powershell
# Add users to appropriate groups based on role
az ad group member add --group "SG-DevBox-AllDevelopers" --member-id <user-object-id>
az ad group member add --group "SG-DevBox-PowerUsers" --member-id <senior-dev-object-id>
az ad group member add --group "SG-DevBox-DataScience" --member-id <ds-engineer-object-id>
```

---

## Summary of Cost Controls

| Control | Type | Configuration Location |
|---------|------|------------------------|
| Max Dev Boxes per User | Hard Limit | `infrastructure/modules/devcenter/main.tf` |
| Auto-Stop Schedule | Cost Saving | `images/definitions/devbox-definitions.json` |
| Pool Access by Group | Access Control | Azure AD + Role Assignments |
| SKU Restrictions | Governance | Definitions + Separate Projects |
| Budget Alerts | Monitoring | `infrastructure/main.tf` (Budget resource) |
| Cost Tags | Tracking | Resource tags across all resources |

---

## Related Documentation

- [SECURITY-DESIGN.md](SECURITY-DESIGN.md) - Identity and access management
- [ARCHITECTURE.md](ARCHITECTURE.md) - Overall system design
- [infrastructure/README.md](../infrastructure/README.md) - Operations guide
- [Azure DevBox Pricing](https://azure.microsoft.com/pricing/details/dev-box/)
