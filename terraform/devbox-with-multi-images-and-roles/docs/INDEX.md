# Documentation Index

Welcome to the DevBox Multi-Images and Roles documentation! This index will help you find the right documentation for your needs.

## 📖 Documentation Overview

| Document | Purpose | Audience | Reading Time |
|----------|---------|----------|--------------|
| [README.md](../README.md) | **Complete reference** - Setup, usage, troubleshooting | Everyone | 45 min |
| [QUICKSTART.md](QUICKSTART.md) | **Fast setup guide** - Get running quickly | Operations & Dev Teams | 10 min |
| [ARCHITECTURE.md](ARCHITECTURE.md) | **Design decisions** - Why it's built this way | Technical Leads, Architects | 20 min |
| [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) | **What was built** - Overview of deliverables | Project Managers, Stakeholders | 15 min |
| [WORKFLOWS.md](WORKFLOWS.md) | **Visual diagrams** - How it all works together | Everyone | 15 min |
| [GOLDEN-BASELINE-IMPLEMENTATION.md](GOLDEN-BASELINE-IMPLEMENTATION.md) | **Security enforcement** - Golden image approach | Operations & Security Teams | 30 min |
| [SECURITY-ENFORCEMENT-SUMMARY.md](SECURITY-ENFORCEMENT-SUMMARY.md) | **How bypass is prevented** - 5-layer defense | Security Teams, Auditors | 15 min |

## 🚀 Getting Started

### I want to... deploy infrastructure
→ Start with [QUICKSTART.md](QUICKSTART.md#-15-minute-setup-operations-team)  
→ Then read [README.md - Operations Team Guide](../README.md#-operations-team-guide)  
→ Reference [infrastructure/scripts/](../infrastructure/scripts/)

### I want to... build a custom image
→ Start with [QUICKSTART.md](QUICKSTART.md#-20-minute-image-build-development-teams)  
→ Then read [README.md - Development Team Guide](../README.md#-development-team-guide)  
→ Example: [images/packer/teams/vscode-devbox.pkr.hcl](../images/packer/teams/vscode-devbox.pkr.hcl)

### I want to... understand the architecture
→ Read [ARCHITECTURE.md](ARCHITECTURE.md)  
→ Review [WORKFLOWS.md](WORKFLOWS.md) for visual diagrams  
→ See [README.md - Separation of Duties](../README.md#-separation-of-duties)

### I want to... configure security and compliance
→ **START HERE:** [SECURITY-ENFORCEMENT-SUMMARY.md](SECURITY-ENFORCEMENT-SUMMARY.md) - Understand 5-layer defense  
→ **Then read:** [GOLDEN-BASELINE-IMPLEMENTATION.md](GOLDEN-BASELINE-IMPLEMENTATION.md) - Step-by-step setup  
→ Review [infrastructure/policies/compliance-settings.md](../infrastructure/policies/compliance-settings.md)  
→ See [README.md - Security Implementation](../README.md#-security-implementation)

### I want to... set up CI/CD
→ Read [README.md - CI/CD Integration](../README.md#-cicd-integration)  
→ Adapt examples for your CI/CD platform  
→ Integrate with [infrastructure/scripts/04-sync-pools.ps1](../infrastructure/scripts/04-sync-pools.ps1)

### I want to... troubleshoot issues
→ Jump to [README.md - Troubleshooting](../README.md#-troubleshooting)  
→ Check [QUICKSTART.md - Common Issues](QUICKSTART.md#-common-issues)  
→ Review error logs and follow diagnostics

## 👥 Documentation by Role

### Operations Team
**Primary:** [README.md - Operations Team Guide](../README.md#-operations-team-guide)  
**Quick Ref:** [QUICKSTART.md](QUICKSTART.md#-15-minute-setup-operations-team)  
**Scripts:** [infrastructure/scripts/](../infrastructure/scripts/)  
**Config:** [infrastructure/terraform.tfvars.example](../infrastructure/terraform.tfvars.example)

**Key Topics:**
- Infrastructure deployment
- Network configuration
- Intune setup
- Pool synchronization
- Monitoring and maintenance

### Development Teams
**Primary:** [README.md - Development Team Guide](../README.md#-development-team-guide)  
**Quick Ref:** [QUICKSTART.md](QUICKSTART.md#-20-minute-image-build-development-teams)  
**Examples:** [images/packer/teams/](../images/packer/teams/)  
**Definitions:** [images/definitions/devbox-definitions.json](../images/definitions/devbox-definitions.json)

**Key Topics:**
- Building custom images
- Packer template customization
- DevBox definitions
- Software installation
- Testing images

### Security Team
**Primary:** [infrastructure/policies/compliance-settings.md](../infrastructure/policies/compliance-settings.md)  
**Base Config:** [images/packer/base/security-baseline.pkr.hcl](../images/packer/base/security-baseline.pkr.hcl)  
**Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md#security--compliance)

**Key Topics:**
- Security baseline enforcement
- Compliance verification
- Intune policies
- Audit requirements
- Base provisioner requirements

### Project Managers / Stakeholders
**Primary:** [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)  
**Architecture:** [ARCHITECTURE.md](ARCHITECTURE.md)  
**Benefits:** [README.md - Separation of Duties](../README.md#-separation-of-duties)

**Key Topics:**
- Project overview
- Implementation phases
- Success metrics
- Team responsibilities
- ROI and benefits

## 📂 Key Files Reference

### Infrastructure (Operations)
```
infrastructure/
├── main.tf                          # Core infrastructure
├── variables.tf                     # Configuration options
├── outputs.tf                       # Values for image team
├── terraform.tfvars.example         # Configuration template
├── CODEOWNERS                       # Approval requirements
│
├── modules/
│   ├── vnet/main.tf                # Network configuration
│   └── devcenter/main.tf           # DevCenter setup
│
├── scripts/
│   ├── 01-deploy-infrastructure.ps1  # Main deployment
│   ├── 02-attach-networks.ps1        # Network setup
│   ├── 03-configure-intune.ps1       # Intune guidance
│   └── 04-sync-pools.ps1             # Auto pool creation
│
└── policies/
    └── compliance-settings.md        # Security requirements
```

### Images (Development Teams)
```
images/
├── CODEOWNERS                       # Team ownership
│
├── packer/
│   ├── base/
│   │   ├── required-provisioners.hcl  # Ops-controlled security
│   │   └── windows-base.pkr.hcl       # Base configuration
│   │
│   ├── teams/
│   │   ├── vscode-devbox.pkr.hcl          # VS Code image
│   │   ├── vscode-variables.pkrvars.hcl   # VS Code config
│   │   └── *.example                      # Templates
│   │
│   └── build-image.ps1              # Build automation
│
└── definitions/
    └── devbox-definitions.json      # DevBox configurations
```

## 🔍 Finding Specific Information

### Commands and Scripts

**Deploy infrastructure:**  
→ [infrastructure/scripts/01-deploy-infrastructure.ps1](../infrastructure/scripts/01-deploy-infrastructure.ps1)

**Build image:**  
→ [images/packer/build-image.ps1](../images/packer/build-image.ps1)

**Sync pools:**  
→ [infrastructure/scripts/04-sync-pools.ps1](../infrastructure/scripts/04-sync-pools.ps1)

### Configuration Examples

**Terraform configuration:**  
→ [infrastructure/terraform.tfvars.example](../infrastructure/terraform.tfvars.example)

**Packer variables:**  
→ [images/packer/teams/vscode-variables.pkrvars.hcl.example](../images/packer/teams/vscode-variables.pkrvars.hcl.example)

**DevBox definitions:**  
→ [images/definitions/devbox-definitions.json](../images/definitions/devbox-definitions.json)

### Security and Compliance

**Base provisioners:**  
→ [images/packer/base/security-baseline.pkr.hcl](../images/packer/base/security-baseline.pkr.hcl)

**Compliance settings:**  
→ [infrastructure/policies/compliance-settings.md](../infrastructure/policies/compliance-settings.md)

**Security enforcement:**  
→ [WORKFLOWS.md - Security Enforcement Flow](WORKFLOWS.md#security-enforcement-flow)

### Workflows and Processes

**Development workflow:**  
→ [WORKFLOWS.md - Development Team Workflow](WORKFLOWS.md#development-team-workflow)

**Operations workflow:**  
→ [WORKFLOWS.md - Operations Team Workflow](WORKFLOWS.md#operations-team-workflow)

**Image build process:**  
→ [WORKFLOWS.md - Image Build Process](WORKFLOWS.md#image-build-process-packer)

## ❓ FAQ - Quick Answers

**Q: Where do I start?**  
A: Operations: [QUICKSTART.md](QUICKSTART.md#-15-minute-setup-operations-team) | Developers: [QUICKSTART.md](QUICKSTART.md#-20-minute-image-build-development-teams)

**Q: How do I customize an image?**  
A: See [README.md - Building Custom Images](../README.md#building-custom-images)

**Q: What can developers change and what can't they?**  
A: See [README.md - Separation of Duties](../README.md#-separation-of-duties)

**Q: How do pools get created?**  
A: See [infrastructure/scripts/04-sync-pools.ps1](../infrastructure/scripts/04-sync-pools.ps1) and [README.md - Ongoing - Sync Pools](../README.md#step-5-ongoing---sync-pools)

**Q: What security settings are enforced?**  
A: See [images/packer/base/security-baseline.pkr.hcl](../images/packer/base/security-baseline.pkr.hcl)

**Q: How do I troubleshoot build failures?**  
A: See [README.md - Image Build Issues](../README.md#image-build-issues)

**Q: Can I use this in production?**  
A: Yes! See [IMPLEMENTATION_SUMMARY.md - What's Ready for Production](IMPLEMENTATION_SUMMARY.md#-whats-ready-for-production)

**Q: How do I set up CI/CD?**  
A: See [README.md - CI/CD Integration](../README.md#-cicd-integration)

## 🎯 Common Tasks

| Task | Documentation | Files |
|------|--------------|-------|
| Deploy infrastructure | [Ops Guide](../README.md#step-1-initial-infrastructure-deployment) | [01-deploy-infrastructure.ps1](../infrastructure/scripts/01-deploy-infrastructure.ps1) |
| Build VS Code image | [Dev Guide](../README.md#step-1-create-variable-file) | [vscode-devbox.pkr.hcl](../images/packer/teams/vscode-devbox.pkr.hcl) |
| Add new definition | [Dev Guide](../README.md#step-5-update-definitions) | [devbox-definitions.json](../images/definitions/devbox-definitions.json) |
| Create new pool | [Ops Guide](../README.md#step-5-ongoing---sync-pools) | [04-sync-pools.ps1](../infrastructure/scripts/04-sync-pools.ps1) |
| Configure Intune | [Ops Guide](../README.md#step-3-optional-intune-configuration) | [03-configure-intune.ps1](../infrastructure/scripts/03-configure-intune.ps1) |
| Add new team image | [Dev Guide](../README.md#building-custom-images) | [teams/](../images/packer/teams/) |
| Update security baseline | [Security](../infrastructure/policies/compliance-settings.md) | [security-baseline.pkr.hcl](../images/packer/base/security-baseline.pkr.hcl) |
| Troubleshoot | [Troubleshooting](../README.md#-troubleshooting) | Multiple |

## 📚 Additional Resources

### External Documentation
- [Microsoft DevCenter Docs](https://learn.microsoft.com/azure/dev-box/)
- [Packer Azure Builder](https://www.packer.io/plugins/builders/azure)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Compute Galleries](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries)

### Internal Documentation
- [README.md](../README.md) - Complete reference
- [ARCHITECTURE.md](ARCHITECTURE.md) - Design decisions
- [WORKFLOWS.md](WORKFLOWS.md) - Visual diagrams
- [QUICKSTART.md](QUICKSTART.md) - Fast setup
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - What was built

## 🆘 Getting Help

**For Operations Issues:**  
Contact @operations-team or reference [README.md - Troubleshooting](../README.md#-troubleshooting)

**For Image Build Issues:**  
Contact your team lead or reference [README.md - Image Build Issues](../README.md#image-build-issues)

**For Documentation Issues:**  
Create an issue or PR to improve this documentation

---

**Pro Tip:** Use `Ctrl+F` to search within documents for specific terms or error messages.

**Happy DevBox Building! 🚀**
