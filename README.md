# Microsoft Dev Box & Deployment Environments - IaC Examples

This repository contains Infrastructure as Code (IaC) examples for deploying [Azure Dev Box](https://learn.microsoft.com/azure/dev-box/) and [Azure Deployment Environments](https://learn.microsoft.com/azure/deployment-environments/) using both Bicep and Terraform.

> **Note:** The Bicep examples in this repository are based on the official Azure quickstart templates originally found at:  
> [Azure Quickstart Templates - DevCenter](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.devcenter)

## 🗂️ Repository Structure

This repository is organized by Infrastructure as Code tool:

```
📁 bicep/          - Azure Bicep examples
📁 terraform/      - HashiCorp Terraform examples
```

## 🎯 What is Azure Dev Box?

Azure Dev Box provides self-service access to high-performance, cloud-based workstations preconfigured for your project. Dev Boxes help developers be productive from day one with ready-to-code environments.

**Key features:**
- Pre-configured development environments
- Consistent developer experience
- Self-service provisioning
- Integration with Microsoft Intune for device management
- Support for custom images

## 🚀 What is Azure Deployment Environments?

Azure Deployment Environments enables platform teams to provide self-service deployment environments for developers. Teams can quickly spin up app infrastructure with project-based templates that establish consistency and best practices.

## 📚 Choose Your IaC Tool

### [Bicep Examples](./bicep/)

Azure Bicep is a domain-specific language (DSL) for deploying Azure resources declaratively. It provides a more concise syntax than ARM templates with full Azure resource support.

**Examples include:**
- **Quick Start** - Minimal DevBox deployment
- **Built-in Images** - Using Microsoft-provided images
- **Customized Images** - Building custom images with Azure Image Builder
- **Ready-to-Code Images** - Advanced image customization
- **Deployment Environments** - Self-service environment deployment

[→ Browse Bicep Examples](./bicep/)

### [Terraform Examples](./terraform/)

HashiCorp Terraform is a popular open-source IaC tool that works across multiple cloud providers using a declarative configuration language (HCL).

**Examples include:**
- **Customized Images** - Building DevBox environments with Packer for image creation

[→ Browse Terraform Examples](./terraform/)

## 🎓 Getting Started

1. **Choose your IaC tool** - Select either [Bicep](./bicep/) or [Terraform](./terraform/)
2. **Select an example** - Browse the examples in your chosen folder
3. **Follow the README** - Each example has detailed deployment instructions
4. **Deploy** - Use the provided commands to deploy the infrastructure

## 🔑 Prerequisites

### For Bicep Examples
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed
- Azure subscription with appropriate permissions
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) (included with Azure CLI)

### For Terraform Examples
- [Terraform](https://www.terraform.io/downloads) installed
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed (for authentication)
- Azure subscription with appropriate permissions
- [Packer](https://www.packer.io/downloads) (for image building examples)

## 📖 Key Concepts

### Dev Box Components

- **Dev Center** - Central management hub for dev boxes and deployment environments
- **Projects** - Logical grouping of dev boxes with specific settings
- **Dev Box Definitions** - Templates that define compute, storage, and image
- **Dev Box Pools** - Collection of dev boxes with the same definition
- **Network Connections** - Links dev boxes to your virtual network

### Image Types

- **Built-in Images** - Microsoft-provided images (Visual Studio, VS Code, etc.)
- **Custom Images** - Your own images built with Azure Image Builder or Packer
- **Azure Compute Gallery** - Storage for custom images

### Optional Features

- **Intune Integration** - Device management and compliance policies
- **Hibernation Support** - Cost savings by hibernating dev boxes when not in use
- **Custom Networking** - Connect to existing VNets and on-premises resources

## 🔄 Bicep vs Terraform

| Feature | Bicep | Terraform |
|---------|-------|-----------|
| **Azure Focus** | Azure-native, deep integration | Multi-cloud support |
| **Syntax** | Concise, ARM JSON-like | HCL (HashiCorp Configuration Language) |
| **State Management** | No state files (ARM handles it) | State files required |
| **Resource Coverage** | Full Azure resource support | Depends on provider updates |
| **Learning Curve** | Easier for Azure-focused teams | Steeper, but transferable skills |
| **Image Building** | Azure Image Builder (native) | Packer (more flexible) |

**Choose Bicep if:**
- You're Azure-focused
- You want simpler syntax and no state management
- You prefer Azure-native tooling

**Choose Terraform if:**
- You need multi-cloud support
- You prefer Packer for image building
- You want infrastructure-as-code portability

## 🤝 Contributing

Contributions are welcome! If you have improvements or new examples:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

This project is provided as sample code. Please review the license file for details.

## 🔗 Additional Resources

- [Azure Dev Box Documentation](https://learn.microsoft.com/azure/dev-box/)
- [Azure Deployment Environments Documentation](https://learn.microsoft.com/azure/deployment-environments/)
- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)

## 💬 Feedback & Support

For issues, questions, or feedback, please use the [GitHub Issues](../../issues) page.

---

**Note:** These examples are designed for learning and demonstration purposes. Review and adjust configurations for production use, especially regarding security, networking, and cost optimization.
