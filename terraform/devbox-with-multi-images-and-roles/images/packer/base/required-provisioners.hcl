# Base Packer Configuration - REQUIRED for all images
# Managed by Operations Team - DO NOT MODIFY IN TEAM CONFIGS
#
# This file contains the MANDATORY provisioners that MUST be included in ALL custom images.
# These provisioners ensure compliance, security, and proper integration with Azure AD and Intune.
#
# CRITICAL: These provisioners enforce:
# - Azure AD join capabilities
# - Security baseline requirements
# - Compliance and monitoring tools
# - Windows Defender and Firewall settings

# PROVISIONER 1: Azure AD Readiness (Order: 1)
# Ensures the system is configured to support Azure AD join
# This does NOT perform the join (that happens at provisioning) but ensures readiness
provisioner_azuread_readiness = {
  type  = "powershell"
  order = 1
  inline = [
    "Write-Output '==============================================='",
    "Write-Output 'OPERATIONS TEAM PROVISIONER: Azure AD Readiness'",
    "Write-Output '==============================================='",
    "Write-Output 'Configuring Azure AD settings...'",
    "",
    "# Ensure User Account Control is enabled (required for Azure AD join)",
    "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'EnableLUA' -Value 1",
    "",
    "# Set UAC to prompt for credentials on the secure desktop",
    "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'ConsentPromptBehaviorAdmin' -Value 2",
    "",
    "# Ensure Windows Remote Management is configured properly",
    "Set-Service -Name 'WinRM' -StartupType Automatic",
    "",
    "Write-Output '✓ Azure AD readiness configuration complete'"
  ]
}

# PROVISIONER 2: Security Baseline (Order: 2)
# Applies mandatory security settings
provisioner_security_baseline = {
  type  = "powershell"
  order = 2
  inline = [
    "Write-Output '==============================================='",
    "Write-Output 'OPERATIONS TEAM PROVISIONER: Security Baseline'",
    "Write-Output '==============================================='",
    "Write-Output 'Applying security baseline...'",
    "",
    "# Windows Defender MUST remain enabled (Intune policy requirement)",
    "Write-Output 'Configuring Windows Defender...'",
    "Set-MpPreference -DisableRealtimeMonitoring $false",
    "Set-MpPreference -DisableBehaviorMonitoring $false",
    "Set-MpPreference -DisableIOAVProtection $false",
    "Set-MpPreference -DisableScriptScanning $false",
    "",
    "# Windows Firewall MUST be enabled on all profiles",
    "Write-Output 'Configuring Windows Firewall...'",
    "Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True",
    "",
    "# Enable BitLocker readiness (actual encryption managed by Intune)",
    "Write-Output 'Preparing BitLocker readiness...'",
    "# Ensure TPM is ready",
    "$tpm = Get-WmiObject -Namespace 'Root\\CIMv2\\Security\\MicrosoftTpm' -Class Win32_Tpm -ErrorAction SilentlyContinue",
    "if ($tpm) {",
    "  Write-Output 'TPM is available and will be used for BitLocker'",
    "} else {",
    "  Write-Output 'TPM not detected - BitLocker will use software encryption if enabled'",
    "}",
    "",
    "Write-Output '✓ Security baseline applied successfully'"
  ]
}

# PROVISIONER 3: Compliance and Monitoring Tools (Order: 3)
# Installs mandatory compliance and monitoring agents
provisioner_compliance_tools = {
  type  = "powershell"
  order = 3
  inline = [
    "Write-Output '==============================================='",
    "Write-Output 'OPERATIONS TEAM PROVISIONER: Compliance Tools'",
    "Write-Output '==============================================='",
    "Write-Output 'Installing compliance and monitoring tools...'",
    "",
    "# Ensure Chocolatey is available for package installation",
    "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
    "",
    "# Install Azure CLI (required for DevCenter operations)",
    "Write-Output 'Installing Azure CLI...'",
    "choco install -y azure-cli --limit-output",
    "",
    "# Note: Microsoft Monitoring Agent installation moved to Intune policy",
    "# This ensures centralized management and policy-based deployment",
    "",
    "Write-Output '✓ Compliance tools installation complete'"
  ]
}

# PROVISIONER 4: Audit and Logging Configuration (Order: 4)
# Configures audit policies for compliance tracking
provisioner_audit_logging = {
  type  = "powershell"
  order = 4
  inline = [
    "Write-Output '==============================================='",
    "Write-Output 'OPERATIONS TEAM PROVISIONER: Audit & Logging'",
    "Write-Output '==============================================='",
    "Write-Output 'Configuring audit policies...'",
    "",
    "# Enable PowerShell script block logging (security requirement)",
    "Write-Output 'Enabling PowerShell logging...'",
    "$psLoggingPath = 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\ScriptBlockLogging'",
    "if (-not (Test-Path $psLoggingPath)) {",
    "  New-Item -Path $psLoggingPath -Force | Out-Null",
    "}",
    "Set-ItemProperty -Path $psLoggingPath -Name 'EnableScriptBlockLogging' -Value 1",
    "",
    "# Configure Event Log sizes for better audit trail",
    "Write-Output 'Configuring Event Log retention...'",
    "wevtutil sl Application /ms:104857600  # 100 MB",
    "wevtutil sl Security /ms:104857600     # 100 MB", 
    "wevtutil sl System /ms:52428800        # 50 MB",
    "",
    "Write-Output '✓ Audit and logging configuration complete'"
  ]
}

# PROVISIONER 5: Final Compliance Verification (Order: 100)
# Verifies that all mandatory settings are in place
# This runs AFTER team-specific customizations
provisioner_compliance_verification = {
  type  = "powershell"
  order = 100
  inline = [
    "Write-Output '==============================================='",
    "Write-Output 'OPERATIONS TEAM PROVISIONER: Final Compliance Check'",
    "Write-Output '==============================================='",
    "Write-Output 'Verifying compliance settings...'",
    "",
    "$complianceIssues = @()",
    "",
    "# Verify UAC is enabled",
    "$uac = Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'EnableLUA'",
    "if ($uac.EnableLUA -ne 1) {",
    "  $complianceIssues += 'UAC is not enabled'",
    "}",
    "",
    "# Verify Windows Defender is enabled",
    "$defenderStatus = Get-MpPreference | Select-Object -Property DisableRealtimeMonitoring",
    "if ($defenderStatus.DisableRealtimeMonitoring -eq $true) {",
    "  $complianceIssues += 'Windows Defender real-time monitoring is disabled'",
    "}",
    "",
    "# Verify Windows Firewall is enabled",
    "$firewallProfiles = Get-NetFirewallProfile",
    "foreach ($profile in $firewallProfiles) {",
    "  if ($profile.Enabled -eq $false) {",
    "    $complianceIssues += \"Windows Firewall is disabled on $($profile.Name) profile\"",
    "  }",
    "}",
    "",
    "# Report compliance status",
    "if ($complianceIssues.Count -eq 0) {",
    "  Write-Output '✓ All compliance checks PASSED'",
    "  Write-Output 'Image is ready for deployment to DevCenter'",
    "} else {",
    "  Write-Output '✗ COMPLIANCE ISSUES DETECTED:'",
    "  foreach ($issue in $complianceIssues) {",
    "    Write-Output \"  - $issue\"",
    "  }",
    "  Write-Output ''",
    "  Write-Output 'WARNING: This image may not meet organizational security requirements'",
    "  # Note: We don't exit with error to allow image build, but issues are logged",
    "}",
    "",
    "Write-Output '==============================================='"
  ]
}

# USAGE INSTRUCTIONS FOR TEAM PACKER TEMPLATES:
#
# Team-specific Packer templates MUST include ALL base provisioners.
# Use the following structure in your team template:
#
# build {
#   sources = ["source.azure-arm.your_source"]
#
#   # === REQUIRED: Operations Team Base Provisioners ===
#   # Order 1: Azure AD Readiness
#   provisioner "powershell" {
#     inline = [/* content from provisioner_azuread_readiness.inline */]
#   }
#
#   # Order 2: Security Baseline
#   provisioner "powershell" {
#     inline = [/* content from provisioner_security_baseline.inline */]
#   }
#
#   # Order 3: Compliance Tools
#   provisioner "powershell" {
#     inline = [/* content from provisioner_compliance_tools.inline */]
#   }
#
#   # Order 4: Audit & Logging
#   provisioner "powershell" {
#     inline = [/* content from provisioner_audit_logging.inline */]
#   }
#
#   # === TEAM CUSTOMIZATIONS START HERE (Order: 10-99) ===
#   provisioner "powershell" {
#     inline = [
#       "# Your team-specific software installation",
#       "choco install -y your-tools"
#     ]
#   }
#
#   # === REQUIRED: Final Compliance Check (Order: 100) ===
#   provisioner "powershell" {
#     inline = [/* content from provisioner_compliance_verification.inline */]
#   }
# }
