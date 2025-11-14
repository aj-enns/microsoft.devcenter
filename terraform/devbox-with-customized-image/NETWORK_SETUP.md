# Network Setup for Azure DevCenter

## Overview

Azure DevCenter requires outbound internet connectivity to function properly. The network connection performs health checks that verify connectivity to required Azure services.

## Network Health Check Requirements

The DevCenter network connection health check validates:

1. **Azure Active Directory Connectivity**: Required for authentication
2. **Windows 365 / DevCenter Service Endpoints**: Core service functionality
3. **Software Update Endpoints**: Windows Update and package management
4. **Telemetry and Monitoring**: Service health and diagnostics

## Solution: NAT Gateway

This Terraform configuration includes a **NAT Gateway** by default to provide secure, scalable outbound connectivity.

### What Gets Created

When `enable_nat_gateway = true` (default):

1. **Public IP Address**: Standard SKU, zone-redundant IP in Zone 1
2. **NAT Gateway**: Provides SNAT for outbound traffic
3. **Subnet Association**: Automatically associates NAT Gateway with DevCenter subnet

### Benefits

- ✅ **Automatic**: Created and configured by Terraform
- ✅ **Secure**: No inbound access, only outbound
- ✅ **Scalable**: Supports up to 64,000 concurrent connections
- ✅ **Reliable**: Zone-redundant design

## Configuration Options

### Default (Recommended)

```hcl
# In terraform.tfvars
enable_nat_gateway = true  # Default value
```

### Using Existing Outbound Solution

If you already have Azure Firewall or another outbound solution:

```hcl
# In terraform.tfvars
enable_nat_gateway = false
```

**Important**: Ensure your existing solution allows connectivity to required endpoints (see below).

## Required Azure Endpoints

Your network must allow outbound HTTPS (443) to:

- `*.windows365.microsoft.com`
- `*.devcenter.azure.com`
- `*.login.microsoftonline.com`
- `*.graph.microsoft.com`
- `*.windows.net`
- `*.azure.com`

For a complete list, see: [Azure DevCenter Network Requirements](https://learn.microsoft.com/en-us/azure/dev-box/how-to-configure-network-connections)

## Troubleshooting

### Health Check Status: Failed

If the network connection health check fails:

1. **Check NAT Gateway**: Verify it's associated with the subnet
   ```bash
   az network vnet subnet show --name <subnet-name> --vnet-name <vnet-name> --resource-group <rg-name>
   ```

2. **Check Network Connection**: View detailed health status
   ```bash
   az devcenter admin network-connection show --name <connection-name> --resource-group <rg-name>
   ```

3. **Trigger Health Check**: Manually rerun health checks
   ```bash
   az devcenter admin network-connection run-health-check --name <connection-name> --resource-group <rg-name>
   ```

### Common Issues

**Issue**: `defaultOutboundAccess: false` on subnet
- **Solution**: Terraform automatically sets `default_outbound_access_enabled = true`

**Issue**: NAT Gateway zone mismatch
- **Solution**: Both NAT Gateway and Public IP are configured for Zone 1

**Issue**: Health check shows "Pending" for extended time
- **Wait Time**: Health checks can take 5-10 minutes to complete
- **Action**: Script automatically waits and retries

## Script Improvements

The `03-create-pools.ps1` script now includes:

1. **Automatic Health Check Monitoring**: Waits up to 10 minutes for health check to pass
2. **Detailed Error Messages**: Shows specific connectivity failures
3. **Troubleshooting Guidance**: Provides Azure Portal links and CLI commands
4. **User Prompts**: Asks permission before proceeding with failed health check

## First-Time Deployment

When deploying for the first time:

1. **Terraform Apply**: Creates all infrastructure including NAT Gateway
   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```

2. **Build Images**: Create custom images with Packer (30-60 min)
   ```bash
   cd packer
   .\build-image.ps1 -ImageType visualstudio -Action all
   .\build-image.ps1 -ImageType intellij -Action all
   ```

3. **Create Definitions**: Configure DevBox definitions
   ```bash
   .\02-create-definitions.ps1
   ```

4. **Create Pools**: Attaches network and creates pools (includes health check wait)
   ```bash
   .\03-create-pools.ps1
   ```

The network will be healthy immediately after Terraform deployment since NAT Gateway provides instant outbound connectivity.

## Cost Considerations

**NAT Gateway Pricing** (as of 2025):
- Gateway: ~$32/month
- Data Processing: ~$0.045 per GB processed

**Typical DevBox Usage**: $35-40/month for small deployments

For production environments, this cost is minimal compared to the reliability and security benefits.

## References

- [Azure NAT Gateway Documentation](https://learn.microsoft.com/en-us/azure/nat-gateway/)
- [Azure DevCenter Network Requirements](https://learn.microsoft.com/en-us/azure/dev-box/how-to-configure-network-connections)
- [DevCenter Network Connection Health](https://learn.microsoft.com/en-us/azure/dev-box/how-to-manage-network-connections)
