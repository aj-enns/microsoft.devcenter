# Bicep Examples for Azure Dev Box & Deployment Environments

This folder contains Azure Bicep examples for deploying Dev Box and Deployment Environments infrastructure.

## 📚 Available Examples

### 🚀 [devbox-quick-start](./devbox-quick-start/)
**Difficulty:** Beginner  
**Description:** Minimal DevBox deployment to get started quickly.

**Includes:**
- Basic Dev Center setup
- Single Dev Box definition with built-in image
- Simple network configuration
- Basic project setup

**Use this when:** You want to quickly test Azure Dev Box with minimal configuration.

---

### 🖥️ [devbox-with-builtin-image](./devbox-with-builtin-image/)
**Difficulty:** Beginner to Intermediate  
**Description:** Deploy Dev Boxes using Microsoft-provided built-in images.

**Includes:**
- Dev Center with multiple built-in images
- Network configuration with VNet
- Dev Box pools for different developer personas
- Role-based access control

**Use this when:** You want to use Microsoft-maintained images (Visual Studio, VS Code, etc.) without customization.

---

### 🎨 [devbox-with-customized-image](./devbox-with-customized-image/)
**Difficulty:** Intermediate  
**Description:** Build and deploy custom Dev Box images using Azure Image Builder.

**Includes:**
- Azure Compute Gallery setup
- Custom image definitions
- Azure Image Builder templates
- Automated image building with software installations
- Dev Box definitions using custom images

**Use this when:** You need to pre-install specific software or configurations on your Dev Boxes.

**Software customization includes:**
- Chocolatey package manager
- Development tools (Git, Azure CLI, VS Code)
- Custom VS Code extensions
- PowerShell modules

---

### 🔧 [devbox-ready-to-code-image](./devbox-ready-to-code-image/)
**Difficulty:** Advanced  
**Description:** Advanced custom image creation with complex software configurations.

**Includes:**
- Multiple custom image definitions for different developer personas
- Advanced Azure Image Builder configurations
- Complex software installation scripts
- Azure DevOps pipeline integration for automated builds
- Gallery sharing across subscriptions

**Use this when:** You need fully customized, production-ready Dev Box images with complex tooling.

**Advanced features:**
- Multi-stage image builds
- Custom build environments
- Package restoration from custom sources
- Repository cloning and setup
- Integration with private package feeds

---

### 🌍 [deployment-environments](./deployment-environments/)
**Difficulty:** Intermediate  
**Description:** Self-service deployment environments for application infrastructure.

**Includes:**
- Deployment Environment setup
- Environment definitions with Bicep templates
- Project-based access control
- Multi-environment support

**Use this when:** You want to enable developers to deploy application infrastructure (databases, storage, etc.) on-demand.

---

## 🎯 Common Scenarios

### Scenario 1: Quick Evaluation
**Start with:** [devbox-quick-start](./devbox-quick-start/)  
**Time:** 15-30 minutes  
**Goal:** Understand basic Dev Box concepts

### Scenario 2: Team Rollout with Built-in Images
**Start with:** [devbox-with-builtin-image](./devbox-with-builtin-image/)  
**Time:** 1-2 hours  
**Goal:** Deploy Dev Boxes for your team using Microsoft images

### Scenario 3: Custom Development Environment
**Start with:** [devbox-with-customized-image](./devbox-with-customized-image/)  
**Time:** 2-4 hours (includes image build time)  
**Goal:** Create Dev Boxes with your organization's tools and configurations

### Scenario 4: Full Production Deployment
**Start with:** [devbox-ready-to-code-image](./devbox-ready-to-code-image/)  
**Time:** 4-8 hours (includes image build time)  
**Goal:** Enterprise-grade Dev Box deployment with CI/CD

### Scenario 5: Application Infrastructure Environments
**Start with:** [deployment-environments](./deployment-environments/)  
**Time:** 1-2 hours  
**Goal:** Enable self-service environment deployment for applications

---

## 🔧 Prerequisites

All Bicep examples require:

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed
- Azure subscription with Contributor or Owner access
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) (included with Azure CLI)

**Authentication:**
```bash
az login
az account set --subscription "your-subscription-id"
```

---

## 📖 Common Bicep Deployment Pattern

All examples follow a similar deployment pattern:

### 1. Customize Parameters
```bash
# Copy the example parameters file
cp azuredeploy.parameters.json azuredeploy.parameters.local.json

# Edit with your values
code azuredeploy.parameters.local.json
```

### 2. Validate Deployment
```bash
az deployment group validate \
  --resource-group your-rg \
  --template-file main.bicep \
  --parameters @azuredeploy.parameters.local.json
```

### 3. Deploy
```bash
az deployment group create \
  --resource-group your-rg \
  --template-file main.bicep \
  --parameters @azuredeploy.parameters.local.json
```

### 4. Clean Up
```bash
az group delete --name your-rg --yes --no-wait
```

---

## 🎨 Image Customization

For examples with custom images ([devbox-with-customized-image](./devbox-with-customized-image/), [devbox-ready-to-code-image](./devbox-ready-to-code-image/)):

**Image build time:** 30-60 minutes per image

**Software installation methods:**
- Chocolatey packages
- PowerShell scripts
- MSI installers
- VS Code extensions

**Common customizations:**
- Development tools (Git, Docker, SDKs)
- IDE/editor configurations
- Company-specific tools
- Security agents
- VPN clients

---

## 🔐 Security Best Practices

When deploying Dev Boxes:

1. **Network Security**
   - Use Azure Firewall or NSGs to control outbound traffic
   - Enable network connection health checks
   - Use private endpoints where possible

2. **Access Control**
   - Use Azure AD groups for role assignments
   - Apply least-privilege principles
   - Enable conditional access policies

3. **Image Security**
   - Keep base images updated
   - Scan images for vulnerabilities
   - Use managed identities for Azure resource access

4. **Compliance**
   - Enable Intune for device management
   - Apply compliance policies
   - Enable audit logging

---

## 💰 Cost Optimization

Dev Box costs include:

- **Compute:** Charged when Dev Box is running
- **Storage:** Always charged (disks persist when stopped)
- **Network:** Egress charges for data transfer
- **Images:** Storage in Azure Compute Gallery

**Cost-saving tips:**
- Use hibernation to reduce compute costs
- Right-size VM SKUs (don't over-provision)
- Delete unused Dev Boxes
- Use scheduled shutdown/startup
- Monitor usage with Azure Cost Management

---

## 🐛 Common Issues

### Issue: Image build fails
**Solution:** Check Azure Image Builder logs, verify permissions, ensure software installation commands are idempotent

### Issue: Network connection unhealthy
**Solution:** Verify NAT Gateway or outbound connectivity, check NSG rules, validate DNS resolution

### Issue: Users can't create Dev Boxes
**Solution:** Verify role assignments, check Dev Box pool limits, ensure image versions exist

### Issue: Dev Box slow to provision
**Solution:** Normal for first provision (15-30 min), check image size, verify network throughput

---

## 📚 Additional Resources

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Dev Box Documentation](https://learn.microsoft.com/azure/dev-box/)
- [Azure Image Builder](https://learn.microsoft.com/azure/virtual-machines/image-builder-overview)
- [Azure Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries)

---

## 🤝 Contributing

Found an issue or have an improvement? Please open an issue or pull request!
