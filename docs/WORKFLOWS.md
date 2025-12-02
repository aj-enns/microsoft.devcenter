# Workflow Diagrams

This document provides visual workflow diagrams for the DevBox multi-images and roles architecture.

## Overall Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Azure Subscription                       │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Resource Group                           │ │
│  │                                                              │ │
│  │  ┌──────────────┐      ┌─────────────┐    ┌─────────────┐ │ │
│  │  │  DevCenter   │◄─────┤   Gallery   │◄───┤   Images    │ │ │
│  │  │              │      │             │    │             │ │ │
│  │  │  - Project   │      │  VSCode     │    │ (Built by   │ │ │
│  │  │  - Network   │      │  Java       │    │  Packer)    │ │ │
│  │  │  - Pools     │      │  .NET       │    │             │ │ │
│  │  └──────┬───────┘      └─────────────┘    └─────────────┘ │ │
│  │         │                                                   │ │
│  │         │                                                   │ │
│  │  ┌──────▼────────────────────────────┐                    │ │
│  │  │   Virtual Network (10.4.0.0/16)   │                    │ │
│  │  │  ┌──────────────────────────────┐ │                    │ │
│  │  │  │ Subnet (10.4.0.0/24)         │ │                    │ │
│  │  │  │  - Dev Boxes run here        │ │                    │ │
│  │  │  │  - Azure AD joined           │ │                    │ │
│  │  │  │  - Intune enrolled           │ │                    │ │
│  │  │  └──────────────────────────────┘ │                    │ │
│  │  │  ┌──────────────────────────────┐ │                    │ │
│  │  │  │ NAT Gateway                  │ │                    │ │
│  │  │  │  - Outbound connectivity     │ │                    │ │
│  │  │  └──────────────────────────────┘ │                    │ │
│  │  └───────────────────────────────────┘                    │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

         ▲                              ▲
         │                              │
    ┌────┴─────┐                  ┌────┴─────┐
    │Operations│                  │Dev Teams │
    │   Team   │                  │          │
    └──────────┘                  └──────────┘
```

## Repository Structure and Ownership

```
┌──────────────────────────────────────────────────────────────────┐
│                    Git Repository Structure                       │
└──────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────┐  ┌─────────────────────────────┐
│ infrastructure/                 │  │ images/                     │
│ (Operations Team)               │  │ (Development Teams)         │
│                                 │  │                             │
│ ├── main.tf ─────────────────┐ │  │ ├── packer/                │
│ ├── variables.tf             │ │  │ │   ├── base/               │
│ ├── outputs.tf               │ │  │ │   │   ├── required-       │
│ ├── terraform.tfvars.example │ │  │ │   │   │   provisioners    │
│ │                             │ │  │ │   │   │   (Ops Only)      │
│ ├── modules/                 │ │  │ │   │   └── windows-base    │
│ │   ├── vnet/                │ │  │ │   │                       │
│ │   └── devcenter/           │ │  │ │   └── teams/              │
│ │                             │ │  │ │       ├── vscode/         │
│ ├── scripts/                 │ │  │ │       │   (VSCode Team)   │
│ │   ├── 01-deploy-infra ────┼─┼──┼─┤       ├── java/            │
│ │   ├── 02-attach-networks  │ │  │ │       │   (Java Team)      │
│ │   ├── 03-configure-intune │ │  │ │       └── dotnet/          │
│ │   └── 04-sync-pools ──────┼─┼──┼─┤           (DotNet Team)    │
│ │                             │ │  │ │                           │
│ ├── policies/                │ │  │ ├── definitions/            │
│ │   └── compliance-settings  │ │  │ │   └── devbox-             │
│ │                             │ │  │ │       definitions.json    │
│ └── CODEOWNERS               │ │  │ │       (Read by script)    │
│     * @operations-team       │ │  │ │                           │
│                               │ │  │ └── CODEOWNERS             │
│                               │ │  │     /base/ @ops            │
│                               │ │  │     /teams/vscode @vscodeteam
│                               │ │  │     /teams/java @javateam  │
└───────────────────────────────┘  └─────────────────────────────┘
         │                                     │
         └──────────── Syncs Pools ───────────┘
                   (04-sync-pools.ps1)
```

## Development Team Workflow

```
Developer Updates Image
         │
         ▼
┌─────────────────────────┐
│ 1. Edit Packer Template │
│    teams/vscode-*.hcl   │
│    - Add new tools      │
│    - Update configs     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ 2. Build & Test Locally │
│    ./build-image.ps1    │
│    -ImageType vscode    │
│    -ValidateOnly        │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ 3. Create Pull Request  │
│    Branch: feat/add-xyz │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 4. Automated CI/CD Checks       │
│    ✓ Packer validate            │
│    ✓ Base provisioners present  │
│    ✓ Security scan              │
│    ✓ Syntax checks              │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────┐
│ 5. Team Lead Reviews    │
│    @vscode-team-leads   │
│    Approves PR          │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ 6. Merge to Main        │
│    PR Merged            │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 7. CI/CD Triggers Image Build   │
│    - Packer build runs          │
│    - Image created in Gallery   │
│    - Takes 30-60 minutes        │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 8. Update Definitions           │
│    Edit devbox-definitions.json │
│    - Update version             │
│    - Create PR                  │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 9. Definitions PR Reviewed      │
│    @dev-leads approve           │
│    @operations-team notified    │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 10. Merge Triggers Pool Sync   │
│     Webhook/Schedule runs       │
│     04-sync-pools.ps1           │
│     - Reads definitions         │
│     - Creates/updates pools     │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────┐
│ 11. Dev Box Available   │
│     Users can provision │
│     from Dev Portal     │
└─────────────────────────┘
```

## Operations Team Workflow

```
Infrastructure Change Needed
         │
         ▼
┌─────────────────────────────────┐
│ 1. Update Terraform             │
│    - main.tf                    │
│    - variables.tf               │
│    - modules/                   │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 2. Test Locally                 │
│    terraform plan               │
│    - Review changes             │
│    - Verify no data loss        │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 3. Create Pull Request          │
│    Branch: infra/update-xyz     │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 4. Automated CI/CD Checks       │
│    ✓ terraform fmt              │
│    ✓ terraform validate         │
│    ✓ terraform plan             │
│    ✓ Security scan              │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 5. Required Reviews             │
│    @operations-team (required)  │
│    @network-team (if network)   │
│    @security-team (if policies) │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 6. Merge to Main                │
│    All approvals received       │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 7. CI/CD Applies Changes        │
│    terraform apply              │
│    - Updates infrastructure     │
│    - Takes 5-30 minutes         │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 8. Verify Deployment            │
│    - Check Azure Portal         │
│    - Run health checks          │
│    - Test connectivity          │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 9. Notify Dev Teams             │
│    - Infrastructure updated     │
│    - New capabilities available │
└─────────────────────────────────┘
```

## Image Build Process (Packer)

```
Build Started
     │
     ▼
┌─────────────────────────────────┐
│ 1. Create Temporary Build VM    │
│    - Size: Standard_D2s_v3      │
│    - OS: Windows 11 + M365      │
│    - Network: Isolated          │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 2. Wait for System Ready (30 sec)      │
└───────────┬─────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 3. Install Chocolatey Package Manager  │
└───────────┬─────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────┐
│ 4. Operations Base Provisioners (Order 1-4)        │
│    ┌─────────────────────────────────────────────┐ │
│    │ Order 1: Azure AD Readiness                 │ │
│    │  - Enable UAC                               │ │
│    │  - Configure WinRM                          │ │
│    └─────────────────────────────────────────────┘ │
│    ┌─────────────────────────────────────────────┐ │
│    │ Order 2: Security Baseline                  │ │
│    │  - Enable Windows Defender                  │ │
│    │  - Enable Windows Firewall                  │ │
│    └─────────────────────────────────────────────┘ │
│    ┌─────────────────────────────────────────────┐ │
│    │ Order 3: Compliance Tools                   │ │
│    │  - Install Azure CLI                        │ │
│    └─────────────────────────────────────────────┘ │
│    ┌─────────────────────────────────────────────┐ │
│    │ Order 4: Audit & Logging                    │ │
│    │  - Enable PowerShell logging                │ │
│    │  - Configure Event Logs                     │ │
│    └─────────────────────────────────────────────┘ │
└───────────┬─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────┐
│ 5. Team Customizations (Order 10-99)               │
│    ┌─────────────────────────────────────────────┐ │
│    │ Install Development Tools                   │ │
│    │  - Git, VS Code, Node.js, Python           │ │
│    │  - Docker Desktop, Terraform               │ │
│    └─────────────────────────────────────────────┘ │
│    ┌─────────────────────────────────────────────┐ │
│    │ Configure VS Code Extensions                │ │
│    │  - GitHub Copilot, Azure Tools             │ │
│    └─────────────────────────────────────────────┘ │
│    ┌─────────────────────────────────────────────┐ │
│    │ Configure Git                               │ │
│    │  - System settings, credential helper      │ │
│    └─────────────────────────────────────────────┘ │
└───────────┬─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────┐
│ 6. Final Compliance Check (Order 100)              │
│    ✓ Verify UAC enabled                            │
│    ✓ Verify Windows Defender enabled               │
│    ✓ Verify Windows Firewall enabled               │
│    Report any issues (build continues)             │
└───────────┬─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────┐
│ 7. Cleanup & Optimization                          │
│    - Remove temp files                             │
│    - Clear event logs                              │
│    - Create dev directories                        │
└───────────┬─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────┐
│ 8. Restart Windows (Complete Installations)        │
└───────────┬─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────┐
│ 9. Generalize Image (Sysprep)                      │
│    - Removes machine-specific info                 │
│    - Prepares for cloning                          │
│    - VM automatically shuts down                   │
└───────────┬─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────┐
│ 10. Upload to Azure Compute Gallery                │
│     - Creates managed image                        │
│     - Adds to shared gallery                       │
│     - Replicates to regions                        │
│     - Cleanup temporary resources                  │
└───────────┬─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────┐
│ Build Complete! Image Available in Gallery         │
└─────────────────────────────────────────────────────┘
```

## User Provisioning Workflow

```
User Opens Dev Portal
         │
         ▼
┌─────────────────────────────────┐
│ 1. Browse Available Pools       │
│    - VSCode-Development-Pool    │
│    - Java-Development-Pool      │
│    - DotNet-Development-Pool    │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 2. Select Pool & Configuration  │
│    - Choose pool                │
│    - Name the Dev Box           │
│    - Click Create               │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 3. DevCenter Provisioning (15-30 min)  │
│    - Create VM from gallery image       │
│    - Join to Azure AD                   │
│    - Enroll in Intune                   │
│    - Apply network configuration        │
│    - Apply compliance policies          │
└───────────┬─────────────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 4. Dev Box Ready                │
│    Status: Running              │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ 5. Connect via RDP              │
│    - Download RDP file          │
│    - Or use web browser         │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 6. Start Development                    │
│    ✓ All tools pre-installed            │
│    ✓ Azure AD authenticated             │
│    ✓ Intune policies applied            │
│    ✓ Compliant and secure               │
│    ✓ Ready to code!                     │
└─────────────────────────────────────────┘
```

## Security Enforcement Flow

```
┌──────────────────────────────────────────────────────────┐
│              Security Enforcement Layers                  │
└──────────────────────────────────────────────────────────┘

Layer 1: Base Provisioners (Build Time)
┌────────────────────────────────────────┐
│ • Operations team controls             │
│ • Cannot be modified by dev teams      │
│ • Enforced via CI/CD validation        │
│ • Compliance check fails build         │
└─────────────┬──────────────────────────┘
              │
              ▼
Layer 2: CODEOWNERS (PR Review)
┌────────────────────────────────────────┐
│ • Required approvals per folder        │
│ • Base/ requires @operations-team      │
│ • Teams/ requires team leads           │
│ • Prevents unauthorized changes        │
└─────────────┬──────────────────────────┘
              │
              ▼
Layer 3: CI/CD Validation (Pre-Merge)
┌────────────────────────────────────────┐
│ • Automated checks before merge        │
│ • Verifies base provisioners present   │
│ • Runs security scans                  │
│ • Validates compliance                 │
└─────────────┬──────────────────────────┘
              │
              ▼
Layer 4: Azure AD Join (Provisioning Time)
┌────────────────────────────────────────┐
│ • Automatic during Dev Box creation    │
│ • Based on network connection config   │
│ • Enables Intune enrollment            │
│ • Managed by Operations team           │
└─────────────┬──────────────────────────┘
              │
              ▼
Layer 5: Intune Policies (Runtime)
┌────────────────────────────────────────┐
│ • Compliance policies                  │
│ • Configuration profiles               │
│ • Conditional access                   │
│ • Security baselines                   │
│ • Ongoing enforcement                  │
└────────────────────────────────────────┘

          ═══════════════════════════════
          Result: Multi-Layer Security
          ═══════════════════════════════
```

---

These diagrams show the complete workflow and architecture of the separation of duties approach for DevBox management.
