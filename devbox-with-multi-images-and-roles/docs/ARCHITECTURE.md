# Architecture Decision Record (ADR)

## Title: Separation of Infrastructure and Image Management for DevBox

**Status:** Implemented  
**Date:** 2025-11-17  
**Decision Makers:** Operations Team, Security Team, Development Team Leads

## Context

We need to deploy Microsoft DevCenter with custom images where:
- Operations team controls infrastructure, networking, and compliance
- Development teams control their software tooling and customizations
- Security requirements must be enforced across all images
- Teams should be able to work independently without blocking each other
- All changes must be auditable and go through proper approvals

## Decision

We will implement a **two-repository architecture** that separates concerns:

### Repository 1: Infrastructure (Operations Owned)
**Location:** `terraform/devbox-with-multi-images-and-roles/infrastructure/`

**Responsibilities:**
- Deploy DevCenter and Project resources
- Manage network connections and virtual networks
- Create and manage Azure Compute Gallery
- Configure Intune integration
- Automatically sync DevBox pools from image definitions
- Enforce compliance policies

**Owned By:** Operations Team, Network Team, Security Team

**Approval Required:** Operations Team for all changes

### Repository 2: Images (Development Teams Owned)
**Location:** `terraform/devbox-with-multi-images-and-roles/images/`

**Responsibilities:**
- Build custom images using Packer
- Define DevBox configurations (CPU, RAM, storage)
- Manage team-specific software installations
- Maintain definitions for what gets deployed

**Owned By:** Development Teams (per team subfolder)

**Approval Required:** Team Leads for team-specific changes, Operations notified

### Separation Mechanism

**Base Packer Provisioners (Operations Controlled):**
- Located in `images/packer/base/`
- Contains mandatory provisioners that MUST be in all images:
  - Azure AD join readiness
  - Security baseline (Defender, Firewall)
  - Compliance tools (Azure CLI, logging)
  - Final compliance verification
- **Cannot be modified by development teams**
- Enforced via CI/CD checks

**Team Packer Templates (Development Team Controlled):**
- Located in `images/packer/teams/`
- Must include all base provisioners
- Can add team-specific software (order 10-99)
- Cannot remove security settings
- Subject to team lead approval

**DevBox Definitions (Development Teams with Operations Review):**
- Located in `images/definitions/devbox-definitions.json`
- Defines which images map to which hardware configs
- Dev leads approve, Operations notified
- Operations team syncs to create pools automatically

## Rationale

### Why This Approach?

**1. Security & Compliance ✅**
- Operations maintains control over mandatory security settings
- Azure AD join configuration cannot be accidentally removed
- Compliance tools always installed
- Audit logging always enabled
- Security baseline enforced across all images

**2. Development Autonomy 🚀**
- Teams control their tooling without IT bottlenecks
- Self-service image building
- Fast iteration on development environments
- Team-specific customizations without affecting others

**3. Clear Ownership Boundaries 📋**
- Infrastructure changes require Operations approval
- Image customizations require Team Lead approval
- No confusion about who owns what
- Proper separation of duties for audit compliance

**4. Automated Workflows 🤖**
- Pools automatically created when definitions updated
- Images automatically built on PR merge (CI/CD)
- Version management automated
- No manual Azure Portal clicking required

**5. Scalability 📈**
- Easy to add new teams (just new folder in teams/)
- Easy to add new image types
- Infrastructure scales independently from images
- Teams don't block each other

## Alternatives Considered

### Alternative 1: Single Repository with All Code
**Rejected because:**
- Mixed concerns make ownership unclear
- Development teams could accidentally change infrastructure
- Single approval chain creates bottlenecks
- Harder to enforce separation of duties

### Alternative 2: Complete Separation (Separate Azure Subscriptions)
**Rejected because:**
- Too much overhead for management
- Cost implications of separate subscriptions
- Complexity in networking between environments
- Overkill for the problem we're solving

### Alternative 3: Operations Team Owns Everything
**Rejected because:**
- Creates bottleneck for development teams
- Operations team overwhelmed with image requests
- Slow iteration on development environments
- Reduces developer productivity

### Alternative 4: No Base Templates (Complete Freedom)
**Rejected because:**
- Security and compliance cannot be guaranteed
- Developers could accidentally break Intune enrollment
- No way to enforce mandatory security settings
- Creates audit and compliance risks

## Consequences

### Positive

✅ **Security:** Operations team retains control over security baseline  
✅ **Productivity:** Development teams can self-service their image needs  
✅ **Auditability:** All changes tracked in Git with proper approvals  
✅ **Scalability:** Easy to onboard new teams and image types  
✅ **Compliance:** Mandatory settings enforced via base provisioners  
✅ **Automation:** CI/CD can handle both repos independently  

### Negative

⚠️ **Coordination:** Teams need to coordinate version updates  
⚠️ **Learning Curve:** Teams need to learn Packer and base provisioners  
⚠️ **Initial Setup:** More complex initial setup than single repo  
⚠️ **Base Changes:** Updating base provisioners affects all teams  

### Mitigation Strategies

**For Coordination:**
- Regular sync meetings between Operations and Dev Leads
- Automated notifications when definitions change
- Clear communication channels (Teams/Slack)

**For Learning Curve:**
- Comprehensive documentation (README.md)
- Quick start guide (QUICKSTART.md)
- Example templates for each language/stack
- Training sessions for team leads

**For Initial Setup:**
- Automated scripts for infrastructure deployment
- Pre-configured variable file examples
- Step-by-step guides
- Helper scripts for common tasks

**For Base Changes:**
- Announce base provisioner changes 2 weeks ahead
- Test with one team before rolling to all
- Version base provisioners for gradual migration
- Provide migration guides

## Implementation Plan

### Phase 1: Infrastructure Setup (Week 1) ✅
- [x] Create infrastructure Terraform configuration
- [x] Create deployment scripts
- [x] Deploy to non-production environment
- [x] Test network connectivity
- [x] Configure Intune (optional)

### Phase 2: Base Templates (Week 2) ✅
- [x] Create base Packer provisioners
- [x] Document mandatory requirements
- [x] Create compliance verification checks
- [x] Test base template builds

### Phase 3: Team Templates (Week 3-4) ✅
- [x] Create VS Code team template
- [x] Create Java/IntelliJ team template
- [x] Create .NET/Visual Studio team template
- [x] Document customization process

### Phase 4: Automation (Week 5)
- [ ] Set up CI/CD for infrastructure repo
- [ ] Set up CI/CD for images repo
- [ ] Configure automatic pool sync
- [ ] Set up compliance checks in CI

### Phase 5: Rollout (Week 6)
- [ ] Train development team leads
- [ ] Migrate pilot team from old process
- [ ] Monitor and gather feedback
- [ ] Adjust based on feedback
- [ ] Roll out to all teams

## Success Metrics

| Metric | Target | Measured By |
|--------|--------|-------------|
| Image build time | < 60 minutes | Packer logs |
| Infrastructure deployment | < 30 minutes | Terraform logs |
| Pool sync time | < 5 minutes | Script execution time |
| Dev team self-service % | > 90% | Ticket volume reduction |
| Security compliance | 100% | Compliance scan results |
| Time to new image | < 1 day | From request to available |

## Review and Updates

This ADR should be reviewed:
- Quarterly by Operations and Security teams
- When significant Azure DevCenter features are released
- When security or compliance requirements change
- When feedback indicates process improvements needed

**Next Review Date:** 2025-02-17

## References

- [Microsoft DevCenter Documentation](https://learn.microsoft.com/azure/dev-box/)
- [Packer Azure Builder](https://www.packer.io/plugins/builders/azure)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Compute Galleries](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries)
- [Intune Integration with DevBox](https://learn.microsoft.com/azure/dev-box/how-to-configure-intune-conditional-access-policies)

## Approval

**Approved By:**
- Operations Team Lead: [Pending]
- Security Team Lead: [Pending]
- Development Team Leads: [Pending]

**Approval Date:** 2025-11-17

---

## Appendix: Repository Structure Diagram

```
DevCenter Organization
├── Infrastructure Repository (Operations)
│   ├── Terraform IaC
│   │   ├── DevCenter
│   │   ├── Project
│   │   ├── Network Connection
│   │   ├── Virtual Network
│   │   └── Compute Gallery
│   ├── PowerShell Scripts
│   │   ├── Deploy Infrastructure
│   │   ├── Attach Networks
│   │   ├── Configure Intune
│   │   └── Sync Pools (reads from Images repo)
│   └── Policies
│       └── Compliance Settings
│
└── Images Repository (Development Teams)
    ├── Base Templates (Operations - Read Only)
    │   ├── Required Provisioners (Security/Compliance)
    │   └── Windows Base Config
    ├── Team Templates (Development Teams - Read/Write)
    │   ├── VS Code Team
    │   ├── Java Team
    │   └── .NET Team
    └── Definitions (Development Teams with Ops Review)
        └── devbox-definitions.json
            ├── Defines image → hardware mapping
            └── Read by Infrastructure repo sync script
```

## Appendix: Workflow Diagram

```
Developer Workflow:
1. Developer updates team Packer template
2. Creates PR → Team Lead reviews
3. CI/CD validates (includes base provisioners?)
4. Merge → Triggers Packer build
5. Image pushed to Gallery
6. Developer updates definitions.json
7. Creates PR → Team Lead approves, Ops notified
8. Merge → Webhook triggers pool sync
9. Operations script reads definitions
10. Creates/updates pools in DevCenter
11. Users can provision from Dev Portal

Operations Workflow:
1. Ops updates infrastructure Terraform
2. Creates PR → Ops Team reviews
3. CI/CD runs terraform plan
4. Merge → Terraform apply
5. Infrastructure updated
6. Definitions automatically synced (if scheduled)
7. Pools updated to reflect infrastructure changes
```
