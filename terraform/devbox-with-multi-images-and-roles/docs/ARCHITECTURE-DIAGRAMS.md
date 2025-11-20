# DevBox Multi-Role Architecture Diagrams

This document provides visual representations of the DevBox architecture, showing how roles, repositories, and Azure resources interact.

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [Repository Separation](#repository-separation)
- [Workflow Diagrams](#workflow-diagrams)
- [Role Responsibilities](#role-responsibilities)
- [Security & Compliance Flow](#security--compliance-flow)
- [Network Architecture](#network-architecture)

## High-Level Architecture

```mermaid
graph TB
    subgraph "Infrastructure Repository (Operations Team)"
        A[Terraform Modules]
        B[Deployment Scripts]
        C[Network Configuration]
        D[DevCenter Resources]
        A --> B
        B --> D
        C --> D
    end

    subgraph "Images Repository (Development Teams)"
        E[Packer Templates - Base]
        F[Packer Templates - Teams]
        G[DevBox Definitions JSON]
        H[Build Scripts]
        E --> F
        F --> H
    end

    subgraph "Azure Resources"
        I[Azure DevCenter]
        J[Azure Compute Gallery]
        K[Virtual Networks]
        L[DevBox Definitions]
        M[DevBox Pools]
        I --> L
        I --> M
        J --> L
        K --> M
    end

    subgraph "End Users"
        N[Developer Portal]
        O[Dev Box Instances]
        N --> O
    end

    D --> I
    D --> K
    H --> J
    G --> B
    B --> L
    B --> M
    M --> O

    style A fill:#e1f5ff
    style B fill:#e1f5ff
    style C fill:#e1f5ff
    style D fill:#e1f5ff
    style E fill:#fff4e1
    style F fill:#fff4e1
    style G fill:#fff4e1
    style H fill:#fff4e1
    style I fill:#e8f5e9
    style J fill:#e8f5e9
    style K fill:#e8f5e9
    style L fill:#e8f5e9
    style M fill:#e8f5e9
```

**Legend:**
- 🔵 Blue = Infrastructure Repository (Operations)
- 🟡 Yellow = Images Repository (Development Teams)
- 🟢 Green = Azure Resources

## Repository Separation

### Infrastructure Repository (Operations)

```mermaid
graph TB
    subgraph "Infrastructure Repo"
        direction TB
        A[terraform/]
        B[scripts/]
        C[policies/]
        D[modules/]
        
        A --> A1[main.tf]
        A --> A2[devcenter.tf]
        A --> A3[networks.tf]
        A --> A4[gallery.tf]
        
        B --> B1[01-deploy-infrastructure.ps1]
        B --> B2[02-attach-networks.ps1]
        B --> B3[03-create-definitions.ps1]
        B --> B4[04-sync-pools.ps1]
        
        C --> C1[security-policies.json]
        C --> C2[compliance-rules.json]
        
        D --> D1[devcenter-module/]
        D --> D2[network-module/]
        D --> D3[gallery-module/]
    end
    
    style A fill:#e1f5ff
    style B fill:#e1f5ff
    style C fill:#e1f5ff
    style D fill:#e1f5ff
```

**Owner:** @operations-team @network-team @security-team  
**Update Frequency:** Quarterly or as-needed

### Images Repository (Development Teams)

```mermaid
graph TB
    subgraph "Images Repo"
        direction TB
        A[packer/]
        B[definitions/]
        C[scripts/]
        
        A --> A1[base/]
        A --> A2[teams/]
        
        A1 --> A1a[security-baseline.pkr.hcl]
        A1 --> A1b[build-baseline-image.ps1]
        
        A2 --> A2a[java-devbox.pkr.hcl]
        A2 --> A2b[dotnet-devbox.pkr.hcl]
        A2 --> A2c[vscode-devbox.pkr.hcl]
        
        B --> B1[devbox-definitions.json]
        
        C --> C1[build-image.ps1]
        C --> C2[create-image-definition.ps1]
    end
    
    style A1 fill:#ffebee
    style A2 fill:#fff4e1
    style B fill:#e3f2fd
```

**Owner:** @dev-teams (per team subfolder)  
**Update Frequency:** Weekly or continuous

## Workflow Diagrams

### Image Creation & Deployment

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Development Team
    participant Git as Git Repository
    participant Packer as Packer Build
    participant Gallery as Azure Compute Gallery
    participant Ops as Operations Team
    participant DevCenter as Azure DevCenter
    participant User as End User

    Dev->>Dev: Create/modify Packer template
    Dev->>Dev: Update devbox-definitions.json
    Dev->>Git: Commit & create PR
    Git->>Dev: Team lead reviews
    Dev->>Git: Merge to main
    
    Git->>Packer: Trigger build (CI/CD)
    Packer->>Gallery: Pull SecurityBaselineImage
    Packer->>Packer: Apply team customizations
    Packer->>Packer: Run security validation
    Packer->>Gallery: Upload new image version
    
    Packer->>Ops: Notify: Image ready
    Ops->>DevCenter: Run 03-create-definitions.ps1 -Update
    DevCenter->>DevCenter: Update definition with new image
    Ops->>DevCenter: Run 04-sync-pools.ps1
    DevCenter->>DevCenter: Pools reference updated definition
    
    User->>DevCenter: Provision Dev Box
    DevCenter->>Gallery: Pull latest image
    DevCenter->>User: Dev Box ready with new version
```

### Infrastructure Deployment

```mermaid
sequenceDiagram
    autonumber
    participant Ops as Operations Team
    participant TF as Terraform
    participant Azure as Azure Resources
    participant Gallery as Compute Gallery
    participant Script as PowerShell Scripts
    participant Dev as Development Teams

    Ops->>TF: terraform plan
    TF->>Azure: Validate resources
    Ops->>TF: terraform apply
    
    TF->>Azure: Create Resource Group
    TF->>Azure: Deploy DevCenter
    TF->>Azure: Configure Virtual Networks
    TF->>Azure: Create Network Connections
    TF->>Azure: Create Compute Gallery
    TF->>Azure: Create DevCenter Project
    
    Ops->>Script: Run build-baseline-image.ps1
    Script->>Gallery: Build SecurityBaselineImage v1.0.0
    
    Ops->>Dev: Share outputs: subscription_id, gallery_name, etc.
    
    Dev->>Dev: Configure packer variables
    Dev->>Gallery: Build team images (use baseline as source)
```

### Definition Update Flow

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Development Team
    participant JSON as devbox-definitions.json
    participant Git as Git Repository
    participant Ops as Operations Team
    participant Script as 03-create-definitions.ps1
    participant DevCenter as Azure DevCenter
    participant Pool as DevBox Pool

    Dev->>JSON: Update imageVersion: "1.0.2"
    Dev->>Git: Commit & push
    Dev->>Git: Create Pull Request
    Git->>Dev: Team lead approves
    Dev->>Git: Merge to main
    
    Git->>Ops: Webhook/Notification
    Ops->>Script: Execute with -Update flag
    
    Script->>DevCenter: Get current definition
    DevCenter->>Script: Returns imageVersion: "1.0.1"
    Script->>Script: Compare: 1.0.1 != 1.0.2
    Script->>Script: Version change detected!
    
    Script->>DevCenter: Update definition imageReference
    DevCenter->>DevCenter: Definition now points to v1.0.2
    
    Pool->>DevCenter: Pool checks definition
    Pool->>Pool: New VMs use v1.0.2
```

## Role Responsibilities

### Operations Team

```mermaid
graph TB
    A[Operations Team] --> B[Infrastructure]
    A --> C[Security Baseline]
    A --> D[Networks]
    A --> E[Definitions & Pools]
    A --> F[Monitoring]
    
    B --> B1[Deploy DevCenter]
    B --> B2[Manage Gallery]
    B --> B3[Resource Groups]
    
    C --> C1[Build Baseline Image]
    C --> C2[Enforce Policies]
    C --> C3[Compliance Checks]
    
    D --> D1[VNet Configuration]
    D --> D2[Network Connections]
    D --> D3[Firewall Rules]
    
    E --> E1[Create Definitions]
    E --> E2[Sync Pools]
    E --> E3[Version Management]
    
    F --> F1[Health Monitoring]
    F --> F2[Cost Tracking]
    F --> F3[Usage Analytics]
    
    style A fill:#e1f5ff
    style B fill:#e3f2fd
    style C fill:#ffebee
    style D fill:#e8f5e9
    style E fill:#fff9c4
    style F fill:#f3e5f5
```

**Key Activities:**
- Deploy core Azure infrastructure
- Build and maintain SecurityBaselineImage
- Configure network connectivity
- Create/update DevBox definitions in Azure
- Sync pools when definitions change
- Monitor compliance and costs

### Development Teams

```mermaid
graph TB
    A[Development Teams] --> B[Custom Images]
    A --> C[Tool Selection]
    A --> D[Testing]
    A --> E[Configuration]
    
    B --> B1[Write Packer Templates]
    B --> B2[Build Images]
    B --> B3[Version Control]
    
    C --> C1[IDEs]
    C --> C2[SDKs & Runtimes]
    C --> C3[Dev Tools]
    
    D --> D1[Test Builds]
    D --> D2[Validate Tools]
    D --> D3[User Acceptance]
    
    E --> E1[Define DevBox Specs]
    E --> E2[Update Definitions JSON]
    E --> E3[Submit PRs]
    
    style A fill:#fff4e1
    style B fill:#fff9c4
    style C fill:#e8f5e9
    style D fill:#e3f2fd
    style E fill:#f3e5f5
```

**Key Activities:**
- Create Packer templates for team needs
- Install team-specific tools (Java, .NET, etc.)
- Configure DevBox specifications (CPU, RAM, storage)
- Test images before production
- Update definitions with new versions
- Submit PRs for approval

### End Users (Developers)

```mermaid
graph LR
    A[End User] --> B[Access Portal]
    B --> C[Select Pool]
    C --> D[Provision Dev Box]
    D --> E[Connect via RDP/Browser]
    E --> F[Start Coding]
    
    F --> G[Auto-stop Evening]
    G --> H[Resume Tomorrow]
    
    style A fill:#e8f5e9
    style F fill:#fff4e1
```

**Key Activities:**
- Browse available Dev Box pools
- Provision Dev Boxes on-demand
- Connect and start development
- Dev Box auto-stops to save costs
- Resume work next day

## Security & Compliance Flow

### Security Baseline Inheritance

```mermaid
graph TD
    A[SecurityBaselineImage v1.0.0] --> B[Mandatory Components]
    
    B --> C[Windows Hardening]
    B --> D[Azure AD Join]
    B --> E[Windows Defender]
    B --> F[Firewall Enabled]
    B --> G[UAC Enabled]
    B --> H[Azure CLI]
    B --> I[Chocolatey]
    
    A --> J[Team Images Inherit]
    
    J --> K[Java DevBox v1.0.2]
    J --> L[.NET DevBox v2.1.0]
    J --> M[VSCode DevBox v1.5.3]
    
    K --> N{Security Validation}
    L --> N
    M --> N
    
    N -->|Pass| O[✓ All Security Intact]
    N -->|Fail| P[✗ Build Fails]
    
    O --> Q[Production Ready]
    P --> R[Fix & Rebuild]
    
    style A fill:#e8f5e9
    style B fill:#ffebee
    style C fill:#ffcdd2
    style D fill:#ffcdd2
    style E fill:#ffcdd2
    style F fill:#ffcdd2
    style G fill:#ffcdd2
    style H fill:#ffcdd2
    style I fill:#ffcdd2
    style J fill:#fff4e1
    style N fill:#fff9c4
    style O fill:#c8e6c9
    style P fill:#ffcdd2
```

### Compliance Validation Process

```mermaid
sequenceDiagram
    autonumber
    participant Build as Packer Build
    participant Image as Custom Image
    participant Check as Security Validation
    participant Ops as Operations Team
    participant Fail as Build Failure

    Build->>Image: Apply team customizations
    Image->>Image: Install Java/IDEs/WSL
    
    Build->>Check: Run compliance provisioner
    
    Check->>Check: ✓ Verify UAC enabled
    Check->>Check: ✓ Verify Defender enabled
    Check->>Check: ✓ Verify Firewall enabled  
    Check->>Check: ✓ Verify Azure CLI present
    Check->>Check: ✓ Verify no disabled security
    
    alt All Checks Pass
        Check->>Build: ✅ Validation passed
        Build->>Image: Proceed to sysprep
        Image->>Image: Generalize & upload
    else Any Check Fails
        Check->>Fail: ❌ Validation failed
        Fail->>Build: Stop build process
        Fail->>Ops: Alert: Security violation detected
        Ops->>Build: Review logs & remediate
    end
```

## Network Architecture

```mermaid
graph TB
    subgraph "Azure Region: Canada Central"
        subgraph "Hub VNet (10.0.0.0/16)"
            FW[Azure Firewall<br/>10.0.1.0/24]
            GW[VPN Gateway<br/>10.0.2.0/24]
            BASTION[Azure Bastion<br/>10.0.3.0/24]
        end
        
        subgraph "DevBox VNet (10.1.0.0/16)"
            SN1[Java Dev Subnet<br/>10.1.1.0/24]
            SN2[.NET Dev Subnet<br/>10.1.2.0/24]
            SN3[Web Dev Subnet<br/>10.1.3.0/24]
            NSG[Network Security Group<br/>Inbound: RDP/HTTPS<br/>Outbound: Controlled]
        end
        
        subgraph "DevCenter Management"
            DC[Azure DevCenter<br/>dc-devbox-multi-roles]
            NC1[Network Connection 1<br/>→ Java Subnet]
            NC2[Network Connection 2<br/>→ .NET Subnet]
            NC3[Network Connection 3<br/>→ Web Subnet]
        end
        
        subgraph "Dev Box Instances"
            DB1[Java Dev Boxes<br/>8-16 vCPU]
            DB2[.NET Dev Boxes<br/>16-32 vCPU]
            DB3[Web Dev Boxes<br/>8 vCPU]
        end
        
        subgraph "Supporting Services"
            GALLERY[Azure Compute Gallery<br/>galxvqypooxvqja4]
            INTUNE[Microsoft Intune<br/>Device Management]
        end
    end
    
    subgraph "On-Premises Network"
        CORP[Corporate Network<br/>192.168.0.0/16]
        USERS[Corporate Users]
    end
    
    subgraph "Internet Services"
        AAD[Azure AD]
        PORTAL[Developer Portal<br/>devportal.microsoft.com]
    end
    
    GW -.Site-to-Site VPN.- CORP
    USERS --> PORTAL
    PORTAL --> AAD
    AAD --> DC
    
    FW --> SN1
    FW --> SN2
    FW --> SN3
    NSG --> SN1
    NSG --> SN2
    NSG --> SN3
    
    DC --> NC1
    DC --> NC2
    DC --> NC3
    
    NC1 --> SN1
    NC2 --> SN2
    NC3 --> SN3
    
    SN1 --> DB1
    SN2 --> DB2
    SN3 --> DB3
    
    GALLERY -.Provides Images.- DB1
    GALLERY -.Provides Images.- DB2
    GALLERY -.Provides Images.- DB3
    
    INTUNE -.Manages.- DB1
    INTUNE -.Manages.- DB2
    INTUNE -.Manages.- DB3
    
    style DC fill:#e1f5ff
    style GALLERY fill:#e8f5e9
    style DB1 fill:#fff4e1
    style DB2 fill:#fff4e1
    style DB3 fill:#fff4e1
    style FW fill:#ffebee
    style NSG fill:#ffebee
```

### Network Traffic Flow

```mermaid
sequenceDiagram
    autonumber
    participant User as Developer
    participant Portal as Dev Portal
    participant AAD as Azure AD
    participant DC as DevCenter
    participant VNet as Virtual Network
    participant DevBox as Dev Box
    participant Internet as Internet

    User->>Portal: Access devportal.microsoft.com
    Portal->>AAD: Authenticate user
    AAD->>Portal: Return token
    Portal->>DC: Request Dev Box provisioning
    DC->>VNet: Allocate IP in subnet
    DC->>DevBox: Deploy VM from gallery image
    DevBox->>DevBox: Join Azure AD
    DevBox->>AAD: Register device
    DevBox->>VNet: Configure network
    VNet->>User: Return RDP/connection details
    
    User->>DevBox: Connect via RDP/Browser
    DevBox->>Internet: Outbound traffic (filtered)
    Internet->>DevBox: Approved responses only
```

## Data Flow

### Image Build Process

```mermaid
flowchart TD
    START[Start: Dev modifies template] --> VAL{Packer Validate}
    VAL -->|Fail| FIX[Fix template syntax]
    FIX --> START
    VAL -->|Pass| BUILD[Packer Build Begins]
    
    BUILD --> VM[Create temp Azure VM]
    VM --> PULL[Pull SecurityBaselineImage]
    PULL --> CUSTOM[Apply team customizations]
    
    CUSTOM --> TOOLS[Install: JDK, Maven, IDEs]
    TOOLS --> WSL[Install WSL & Ubuntu]
    WSL --> CONFIG[Configure environment vars]
    CONFIG --> SECURITY{Security Validation}
    
    SECURITY -->|Fail| ALERT[Alert Operations]
    ALERT --> FIX
    SECURITY -->|Pass| SYSPREP[Sysprep/Generalize]
    
    SYSPREP --> UPLOAD[Upload to Gallery]
    UPLOAD --> TAG[Tag with version]
    TAG --> CLEANUP[Cleanup temp resources]
    CLEANUP --> NOTIFY[Notify Operations]
    NOTIFY --> END[Image Ready]
    
    style PULL fill:#e8f5e9
    style CUSTOM fill:#fff4e1
    style SECURITY fill:#ffebee
    style UPLOAD fill:#e8f5e9
    style END fill:#c8e6c9
```

### DevBox Provisioning Flow

```mermaid
flowchart TD
    USER[User: Create Dev Box] --> PORTAL[Developer Portal]
    PORTAL --> AUTH{Authenticated?}
    
    AUTH -->|No| LOGIN[Login with Azure AD]
    LOGIN --> AUTH
    AUTH -->|Yes| SELECT[Select Pool]
    
    SELECT --> POOL{Pool Type}
    POOL -->|Java| JAVA[Java Development Pool]
    POOL -->|.NET| DOTNET[.NET Development Pool]
    POOL -->|Web| WEB[Web Development Pool]
    
    JAVA --> DEF1[Java-DevBox Definition]
    DOTNET --> DEF2[DotNet-DevBox Definition]
    WEB --> DEF3[VSCode-DevBox Definition]
    
    DEF1 --> IMG1[JavaDevImage v1.0.2]
    DEF2 --> IMG2[DotNetDevImage v2.1.0]
    DEF3 --> IMG3[VSCodeDevImage v1.5.3]
    
    IMG1 --> PROVISION[Provision VM]
    IMG2 --> PROVISION
    IMG3 --> PROVISION
    
    PROVISION --> NET[Apply Network Config]
    NET --> INTUNE[Enroll in Intune]
    INTUNE --> POLICY[Apply Policies]
    POLICY --> READY[Dev Box Ready]
    
    READY --> CONNECT[User Connects]
    CONNECT --> CODE[Start Coding]
    
    style IMG1 fill:#e8f5e9
    style IMG2 fill:#e8f5e9
    style IMG3 fill:#e8f5e9
    style READY fill:#c8e6c9
```

## CI/CD Integration

```mermaid
graph LR
    subgraph "Images Repository CI/CD"
        A[Git Push] --> B{Branch?}
        B -->|feature| C[Packer Validate]
        B -->|main| D[Packer Build]
        
        C --> E{Valid?}
        E -->|No| F[Fail PR Check]
        E -->|Yes| G[✓ PR Ready]
        
        D --> H[Build Image]
        H --> I[Upload to Gallery]
        I --> J[Trigger Webhook]
    end
    
    subgraph "Infrastructure Repository CI/CD"
        K[Git Push] --> L{Branch?}
        L -->|feature| M[Terraform Plan]
        L -->|main| N[Terraform Apply]
        
        M --> O{Plan Valid?}
        O -->|No| P[Fail PR Check]
        O -->|Yes| Q[✓ PR Ready]
        
        N --> R[Deploy Infrastructure]
        R --> S[Update Resources]
    end
    
    subgraph "Automated Sync"
        J --> T[Webhook Received]
        T --> U[Run 03-create-definitions.ps1]
        U --> V[Run 04-sync-pools.ps1]
        V --> W[Pools Updated]
    end
    
    style C fill:#fff4e1
    style D fill:#fff4e1
    style M fill:#e1f5ff
    style N fill:#e1f5ff
    style W fill:#c8e6c9
```

## Summary

This architecture provides:

- ✅ **Clear Separation** - Infrastructure vs. Development concerns
- ✅ **Independent Operations** - Teams work without blocking each other
- ✅ **Security Enforcement** - Baseline image ensures compliance
- ✅ **Scalability** - Easy to add teams and image types
- ✅ **Auditability** - Git tracks all changes with approvals
- ✅ **Automation** - CI/CD handles builds and deployments
- ✅ **Flexibility** - Teams customize without infrastructure access
- ✅ **Governance** - Operations maintains control of core resources

## Related Documentation

- [Architecture Decision Record (ADR)](./architecture.md) - Rationale and alternatives
- [Main README](../README.md) - Overview and quick start
- [Infrastructure README](../infrastructure/README.md) - Operations team guide
- [Images README](../images/README.md) - Development team guide
