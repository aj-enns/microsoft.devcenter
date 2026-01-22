# =============================================================================
# JAVA DEV TEAM DEVBOX IMAGE
# =============================================================================
# Managed by: Java Development Team
# Purpose: Custom image with Java development tools, WSL, and Ubuntu
#
# IMPORTANT: This template MUST use SecurityBaselineImage as the source.
# The baseline image contains mandatory security configurations that cannot
# be bypassed. This template adds Java-specific customizations on top.
#
# Protected by: CI/CD validation ensures SecurityBaselineImage is used
# =============================================================================

packer {
  required_version = ">= 1.9.0"
  
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2.0"
    }
  }
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name where the image will be stored"
}

variable "gallery_name" {
  type        = string
  description = "Name of the Azure Compute Gallery"
}

variable "baseline_image_version" {
  type        = string
  description = "Version of SecurityBaselineImage to build from (e.g., 1.0.0)"
  default     = "1.0.0"
}

variable "image_version" {
  type        = string
  description = "Version of this team image (format: x.x.x)"
  default     = "1.0.0"
}

variable "location" {
  type        = string
  description = "Azure location"
  default     = "eastus"
}

variable "vm_size" {
  type        = string
  description = "Size of the build VM"
  default     = "Standard_D4s_v3"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  image_name = "JavaDevImage"
}

# =============================================================================
# SOURCE CONFIGURATION
# =============================================================================
# CRITICAL: Uses SecurityBaselineImage from the gallery (Operations-controlled)
# This ensures all mandatory security configurations are present

source "azure-arm" "javadev_customization" {
  # Authentication
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id

  # Build Configuration
  # Publish directly to gallery (required for TrustedLaunch/SecureBoot support)
  location                 = var.location
  vm_size                  = var.vm_size
  build_resource_group_name = var.resource_group_name  # Build VM in same RG as gallery

  # =========================================================================
  # SOURCE IMAGE: SecurityBaselineImage (REQUIRED - DO NOT CHANGE)
  # =========================================================================
  # This image contains mandatory security configurations managed by the
  # Operations Team. Attempting to use any other source will fail CI/CD.
  
  shared_image_gallery {
    subscription   = var.subscription_id
    resource_group = var.resource_group_name
    gallery_name   = var.gallery_name
    image_name     = "SecurityBaselineImage"
    image_version  = var.baseline_image_version
  }

  # Destination: Java Dev Team Image (direct to gallery)
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.resource_group_name
    gallery_name         = var.gallery_name
    image_name           = local.image_name
    image_version        = var.image_version
    replication_regions  = [var.location]
    storage_account_type = "Standard_LRS"
  }

  # OS Configuration
  os_type = "Windows"

  # Security Configuration - REQUIRED for TrustedLaunch source images
  security_type       = "TrustedLaunch"
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Communicator Settings
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "15m"
  winrm_username = "packer"

  # Tags
  azure_tags = {
    Created_by    = "Packer"
    Team          = "JavaDev-Team"
    Purpose       = "DevCenter_JavaDev_Image"
    BaselineImage = "SecurityBaselineImage-${var.baseline_image_version}"
    Timestamp     = local.timestamp
  }

  # Cleanup
  async_resourcegroup_delete = true
}

# =============================================================================
# BUILD PROCESS
# =============================================================================

build {
  name    = "javadev-team-image"
  sources = ["source.azure-arm.javadev_customization"]

  # ---------------------------------------------------------------------------
  # INITIAL SETUP
  # ---------------------------------------------------------------------------
  # The baseline image already has Chocolatey, Azure CLI, and all security
  # configurations. We only add Java-specific tools here.
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Java Dev Team Customization Build ==='",
      "Write-Host 'Base Image: SecurityBaselineImage v${var.baseline_image_version}'",
      "Write-Host 'Target Version: ${var.image_version}'",
      "Write-Host ''",
      "Write-Host 'Waiting for system to stabilize...'",
      "Start-Sleep -Seconds 30",
      "",
      "# Refresh environment",
      "$env:ChocolateyInstall = 'C:\\ProgramData\\chocolatey'",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"
    ]
  }

  # ---------------------------------------------------------------------------
  # JAVA DEVELOPMENT TOOLS
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Installing Java Development Tools ==='",
      "",
      "# Refresh environment to use Chocolatey from baseline image",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "",
      "Write-Host 'Installing OpenJDK 21 (LTS)...'",
      "choco install -y openjdk21 --limit-output",
      "",
      "Write-Host 'Installing OpenJDK 17 (LTS)...'",
      "choco install -y openjdk17 --limit-output",
      "",
      "Write-Host 'Installing OpenJDK 11 (LTS)...'",
      "choco install -y openjdk11 --limit-output",
      "",
      "Write-Host 'Installing Maven...'",
      "choco install -y maven --limit-output",
      "",
      "Write-Host 'Installing Gradle...'",
      "choco install -y gradle --limit-output",
      "",
      "Write-Host 'Installing Git...'",
      "choco install -y git --params '/GitAndUnixToolsOnPath /NoAutoCrlf' --limit-output",
      "",
      "Write-Host '✓ Java development tools installation complete'"
    ]
    valid_exit_codes = [0, 3010]
  }

  # ---------------------------------------------------------------------------
  # IDE INSTALLATION
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Installing Java IDEs ==='",
      "",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "",
      "Write-Host 'Installing IntelliJ IDEA Community Edition...'",
      "choco install -y intellijidea-community --limit-output",
      "",
      "Write-Host 'Installing Visual Studio Code...'",
      "choco install -y vscode --limit-output",
      "",
      "Write-Host 'Installing Eclipse IDE for Java Developers...'",
      "choco install -y eclipse-java-oxygen --limit-output",
      "",
      "Write-Host '✓ IDE installation complete'"
    ]
    valid_exit_codes = [0, 3010]
  }

  # ---------------------------------------------------------------------------
  # WSL 2 INSTALLATION
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Installing WSL 2 ==='",
      "",
      "# Enable WSL feature",
      "Write-Host 'Enabling WSL feature...'",
      "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -All | Out-Null",
      "",
      "# Enable Virtual Machine Platform (required for WSL 2)",
      "Write-Host 'Enabling Virtual Machine Platform...'",
      "Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -All | Out-Null",
      "",
      "Write-Host '✓ WSL features enabled (restart required)'"
    ]
    valid_exit_codes = [0, 3010]
  }

  # Restart after enabling WSL features
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # Install WSL 2 and Ubuntu after restart
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Configuring WSL 2 and Installing Ubuntu ==='",
      "",
      "# Update WSL to latest version first (critical step)",
      "Write-Host 'Updating WSL to latest version...'",
      "wsl --update",
      "Write-Host ('WSL update completed with exit code: ' + $LASTEXITCODE)",
      "",
      "# Set WSL 2 as default version",
      "Write-Host 'Setting WSL 2 as default...'",
      "wsl --set-default-version 2",
      "Write-Host ('Set default version completed with exit code: ' + $LASTEXITCODE)",
      "",
      "# Download and install Ubuntu using AppX method (more reliable for automation)",
      "Write-Host 'Downloading Ubuntu 22.04 LTS distribution...'",
      "Write-Host 'This may take several minutes...'",
      "",
      "try {",
      "    # Download Ubuntu AppX package directly",
      "    $ubuntuUrl = 'https://aka.ms/wslubuntu2204'",
      "    $appxPath = Join-Path $env:TEMP 'Ubuntu.appx'",
      "    ",
      "    Write-Host ('Downloading from: ' + $ubuntuUrl)",
      "    Invoke-WebRequest -Uri $ubuntuUrl -OutFile $appxPath -UseBasicParsing",
      "    Write-Host ('Downloaded to: ' + $appxPath)",
      "    ",
      "    # Install the AppX package",
      "    Write-Host 'Installing Ubuntu distribution...'",
      "    Add-AppxPackage -Path $appxPath",
      "    Write-Host 'Ubuntu AppX package installed'",
      "    ",
      "    # Clean up downloaded file",
      "    Remove-Item -Path $appxPath -Force -ErrorAction SilentlyContinue",
      "    Write-Host 'Cleaned up temporary files'",
      "    ",
      "    # Wait for distribution to register",
      "    Write-Host 'Waiting for distribution to register with WSL...'",
      "    Start-Sleep -Seconds 15",
      "    ",
      "} catch {",
      "    Write-Host ('Warning: Ubuntu installation encountered an issue: ' + $_.Exception.Message) -ForegroundColor Yellow",
      "    Write-Host 'Ubuntu may need to be configured on first login to Dev Box' -ForegroundColor Yellow",
      "}",
      "",
      "# Verify WSL installation",
      "Write-Host 'Verifying WSL installation...'",
      "try {",
      "    wsl --version",
      "    wsl --list --verbose",
      "    Write-Host 'WSL verification complete'",
      "} catch {",
      "    Write-Host 'WSL commands executed (verification may show no output until first use)' -ForegroundColor Yellow",
      "}",
      "",
      "Write-Host 'WSL 2 and Ubuntu configuration complete' -ForegroundColor Green",
      "Write-Host 'Note: Ubuntu will complete setup on first launch by end user' -ForegroundColor Cyan",
      "exit 0"
    ]
    valid_exit_codes = [0, 1, 3010]
  }

  # ---------------------------------------------------------------------------
  # ADDITIONAL DEVELOPMENT TOOLS
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Installing Additional Development Tools ==='",
      "",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "",
      "Write-Host 'Installing Docker Desktop...'",
      "choco install -y docker-desktop --limit-output",
      "",
      "Write-Host 'Installing Node.js (for web services)...'",
      "choco install -y nodejs-lts --limit-output",
      "",
      "Write-Host 'Installing Postman (API testing)...'",
      "choco install -y postman --limit-output",
      "",
      "Write-Host 'Installing DBeaver (database tool)...'",
      "choco install -y dbeaver --limit-output",
      "",
      "Write-Host '✓ Additional tools installation complete'"
    ]
    valid_exit_codes = [0, 3010]
  }

  # ---------------------------------------------------------------------------
  # VS CODE EXTENSIONS FOR JAVA
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Installing VS Code Extensions for Java ==='",
      "",
      "# Refresh PATH",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "",
      "$extensions = @(",
      "  'vscjava.vscode-java-pack',",
      "  'vscjava.vscode-maven',",
      "  'vscjava.vscode-gradle',",
      "  'redhat.java',",
      "  'vscjava.vscode-spring-initializr',",
      "  'pivotal.vscode-spring-boot',",
      "  'ms-azuretools.vscode-docker',",
      "  'ms-vscode-remote.remote-wsl',",
      "  'github.copilot',",
      "  'ms-vscode.azure-account',",
      "  'esbenp.prettier-vscode',",
      "  'dbaeumer.vscode-eslint'",
      ")",
      "",
      "foreach ($ext in $extensions) {",
      "  try {",
      "    Write-Host \"Installing extension: $ext\"",
      "    & 'C:\\Program Files\\Microsoft VS Code\\bin\\code.cmd' --install-extension $ext --force 2>&1 | Out-Null",
      "  } catch {",
      "    Write-Host \"Warning: Failed to install $ext\" -ForegroundColor Yellow",
      "  }",
      "}",
      "",
      "Write-Host '✓ VS Code extensions installed'"
    ]
    pause_before = "30s"
    valid_exit_codes = [0, 1, 3010]
  }

  # ---------------------------------------------------------------------------
  # CONFIGURE JAVA ENVIRONMENT
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Configuring Java Environment ==='",
      "",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "",
      "# Set JAVA_HOME to JDK 21 (latest LTS)",
      "Write-Host 'Setting JAVA_HOME to OpenJDK 21...'",
      "",
      "# Chocolatey installs OpenJDK to multiple possible locations, check them all",
      "$possiblePaths = @(",
      "  'C:\\Program Files\\OpenJDK\\jdk-21*',",
      "  'C:\\Program Files\\Eclipse Adoptium\\jdk-21*',",
      "  'C:\\Program Files\\Temurin\\jdk-21*',",
      "  'C:\\Program Files (x86)\\OpenJDK\\jdk-21*'",
      ")",
      "",
      "$jdk21Path = $null",
      "foreach ($pathPattern in $possiblePaths) {",
      "  $basePath = Split-Path $pathPattern -Parent",
      "  if (Test-Path $basePath) {",
      "    $found = Get-ChildItem $pathPattern -Directory -ErrorAction SilentlyContinue | Select-Object -First 1",
      "    if ($found) {",
      "      $jdk21Path = $found.FullName",
      "      break",
      "    }",
      "  }",
      "}",
      "",
      "# Also check Chocolatey's own installation directory",
      "if (-not $jdk21Path) {",
      "  $chocoJdk = 'C:\\ProgramData\\chocolatey\\lib\\openjdk21*'",
      "  $found = Get-ChildItem $chocoJdk -Directory -ErrorAction SilentlyContinue | Select-Object -First 1",
      "  if ($found) {",
      "    # Look for the actual JDK directory inside",
      "    $jdkDir = Get-ChildItem (Join-Path $found.FullName 'tools\\jdk-*') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1",
      "    if ($jdkDir) {",
      "      $jdk21Path = $jdkDir.FullName",
      "    }",
      "  }",
      "}",
      "",
      "if ($jdk21Path) {",
      "  [System.Environment]::SetEnvironmentVariable('JAVA_HOME', $jdk21Path, 'Machine')",
      "  Write-Host ('JAVA_HOME set to: ' + $jdk21Path) -ForegroundColor Green",
      "} else {",
      "  Write-Host 'Warning: JDK 21 not found. Java environment may need manual configuration.' -ForegroundColor Yellow",
      "  Write-Host 'Note: JDK binaries should still be in PATH from Chocolatey installation.' -ForegroundColor Yellow",
      "}",
      "",
      "# Configure Maven settings",
      "Write-Host 'Configuring Maven...'",
      "$mavenBase = 'C:\\ProgramData\\chocolatey\\lib\\maven'",
      "if (Test-Path $mavenBase) {",
      "  $mavenPath = Get-ChildItem (Join-Path $mavenBase 'apache-maven-*') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1",
      "  if ($mavenPath) {",
      "    [System.Environment]::SetEnvironmentVariable('MAVEN_HOME', $mavenPath.FullName, 'Machine')",
      "    Write-Host ('Maven HOME set to: ' + $mavenPath.FullName) -ForegroundColor Green",
      "  }",
      "} else {",
      "  Write-Host 'Warning: Maven installation not found' -ForegroundColor Yellow",
      "}",
      "",
      "# Configure Gradle settings",
      "Write-Host 'Configuring Gradle...'",
      "$gradleHome = 'C:\\ProgramData\\chocolatey\\lib\\gradle'",
      "if (Test-Path $gradleHome) {",
      "  [System.Environment]::SetEnvironmentVariable('GRADLE_HOME', $gradleHome, 'Machine')",
      "  Write-Host ('Gradle HOME set to: ' + $gradleHome) -ForegroundColor Green",
      "} else {",
      "  Write-Host 'Warning: Gradle installation not found' -ForegroundColor Yellow",
      "}",
      "",
      "Write-Host 'Java environment configuration complete' -ForegroundColor Green"
    ]
    valid_exit_codes = [0, 1]
  }

  # ---------------------------------------------------------------------------
  # CONFIGURE GIT
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Configuring Git ==='",
      "",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "",
      "git config --system core.autocrlf false",
      "git config --system core.longpaths true",
      "git config --system credential.helper manager-core",
      "",
      "Write-Host '✓ Git configuration complete'"
    ]
  }

  # ---------------------------------------------------------------------------
  # TEAM-SPECIFIC CONFIGURATIONS
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Configuring Performance Optimizations ==='",
      "",
      "# Add Defender exclusions for common Java dev folders (improves performance)",
      "Add-MpPreference -ExclusionPath 'C:\\Dev' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\Projects' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\workspace' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\Users\\*\\.m2' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\Users\\*\\.gradle' -ErrorAction SilentlyContinue",
      "",
      "Write-Host '✓ Performance optimizations configured'"
    ]
  }

  # Create Java-specific directories
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Creating Java Development Directories ==='",
      "",
      "New-Item -Path 'C:\\workspace' -ItemType Directory -Force | Out-Null",
      "New-Item -Path 'C:\\repos' -ItemType Directory -Force | Out-Null",
      "New-Item -Path 'C:\\Projects\\Java' -ItemType Directory -Force | Out-Null",
      "",
      "Write-Host '✓ Java development directories created'"
    ]
  }

  # Restart Windows
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # ---------------------------------------------------------------------------
  # SECURITY VALIDATION
  # ---------------------------------------------------------------------------
  # Verify baseline security configurations are still intact
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Verifying Security Baseline ==='",
      "",
      "$errors = @()",
      "",
      "# Check UAC (from baseline image)",
      "$uac = Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'EnableLUA' -ErrorAction SilentlyContinue",
      "if ($uac.EnableLUA -ne 1) { $errors += 'UAC is not enabled' }",
      "else { Write-Host '✓ UAC enabled' }",
      "",
      "# Check Windows Defender (from baseline image)",
      "$defender = Get-MpPreference",
      "if ($defender.DisableRealtimeMonitoring -eq $true) { $errors += 'Windows Defender disabled' }",
      "else { Write-Host '✓ Windows Defender enabled' }",
      "",
      "# Check Firewall (from baseline image)",
      "$fwProfiles = Get-NetFirewallProfile",
      "$fwDisabled = $fwProfiles | Where-Object { $_.Enabled -eq $false }",
      "if ($fwDisabled.Count -gt 0) { $errors += 'Windows Firewall is disabled on some profiles' }",
      "else { Write-Host '✓ Windows Firewall enabled' }",
      "",
      "# Check Azure CLI (from baseline image)",
      "try {",
      "    $null = az --version 2>&1",
      "    Write-Host '✓ Azure CLI available'",
      "} catch {",
      "    $errors += 'Azure CLI is not available'",
      "}",
      "",
      "# Verify WSL installation",
      "Write-Host 'Checking WSL installation...'",
      "try {",
      "    $null = wsl --status 2>&1",
      "    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 50) {",
      "        Write-Host '✓ WSL configured'",
      "    } else {",
      "        Write-Host 'Warning: WSL status returned code ' + $LASTEXITCODE -ForegroundColor Yellow",
      "    }",
      "} catch {",
      "    Write-Host 'Warning: WSL status check failed (may need configuration on first boot)' -ForegroundColor Yellow",
      "}",
      "$LASTEXITCODE = 0  # Reset exit code",
      "",
      "Write-Host ''",
      "if ($errors.Count -eq 0) {",
      "    Write-Host '=== ✓ SECURITY VALIDATION PASSED ===' -ForegroundColor Green",
      "    Write-Host 'All baseline security configurations are intact' -ForegroundColor Green",
      "    exit 0",
      "} else {",
      "    Write-Host '=== ⚠ SECURITY VALIDATION FAILED ===' -ForegroundColor Red",
      "    foreach ($error in $errors) {",
      "        Write-Host \"  ✗ $error\" -ForegroundColor Red",
      "    }",
      "    exit 1",
      "}"
    ]
  }

  # ---------------------------------------------------------------------------
  # DEBUG: System State Check
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== DEBUG: System State Before Cleanup ===' -ForegroundColor Cyan",
      "Write-Host 'Checking system readiness...'",
      "",
      "try {",
      "  # Check disk space",
      "  Write-Host 'Disk Space:'",
      "  $drive = Get-PSDrive C -ErrorAction SilentlyContinue",
      "  if ($drive) {",
      "    $freeGB = [math]::Round($drive.Free/1GB,2)",
      "    $usedGB = [math]::Round($drive.Used/1GB,2)",
      "    Write-Host \"  Free: $freeGB GB, Used: $usedGB GB\"",
      "  }",
      "} catch {",
      "  Write-Host 'Could not check disk space' -ForegroundColor Yellow",
      "}",
      "",
      "try {",
      "  # Check running processes",
      "  Write-Host 'High CPU processes:'",
      "  Get-Process -ErrorAction SilentlyContinue | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {",
      "    Write-Host \"  $($_.Name): CPU=$($_.CPU)\"",
      "  }",
      "} catch {",
      "  Write-Host 'Could not check processes' -ForegroundColor Yellow",
      "}",
      "",
      "# Check pending reboot",
      "Write-Host 'Checking for pending reboot:'",
      "if (Test-Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Component Based Servicing\\RebootPending') {",
      "    Write-Host 'WARNING: Reboot pending from CBS' -ForegroundColor Yellow",
      "} else {",
      "    Write-Host '  No CBS reboot pending'",
      "}",
      "if (Test-Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired') {",
      "    Write-Host 'WARNING: Reboot pending from Windows Update' -ForegroundColor Yellow",
      "} else {",
      "    Write-Host '  No Windows Update reboot pending'",
      "}",
      "",
      "# Check Chocolatey status",
      "Write-Host 'Chocolatey status:'",
      "try {",
      "    $chocoVersion = choco --version 2>&1 | Select-Object -First 1",
      "    Write-Host \"  Chocolatey version: $chocoVersion\"",
      "} catch {",
      "    Write-Host '  Chocolatey not accessible' -ForegroundColor Yellow",
      "}",
      "",
      "Write-Host 'System state check complete' -ForegroundColor Green",
      "Write-Host ''",
      "exit 0"
    ]
  }

  # ---------------------------------------------------------------------------
  # CLEANUP & FINALIZATION
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Cleanup & Optimization ===' -ForegroundColor Cyan",
      "Write-Host 'Starting cleanup process...'",
      "",
      "# Clear temporary files",
      "Write-Host 'Step 1: Clearing Windows temp files...'",
      "try {",
      "    Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "    Write-Host '  ✓ Windows temp cleared'",
      "} catch {",
      "    Write-Host \"  Warning: $_\" -ForegroundColor Yellow",
      "}",
      "",
      "Write-Host 'Step 2: Clearing user temp files...'",
      "try {",
      "    Remove-Item -Path 'C:\\Users\\*\\AppData\\Local\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "    Write-Host '  ✓ User temp cleared'",
      "} catch {",
      "    Write-Host \"  Warning: $_\" -ForegroundColor Yellow",
      "}",
      "",
      "# Clear Recycle Bin",
      "Write-Host 'Step 3: Clearing Recycle Bin...'",
      "try {",
      "    Clear-RecycleBin -Force -ErrorAction SilentlyContinue",
      "    Write-Host '  ✓ Recycle Bin cleared'",
      "} catch {",
      "    Write-Host \"  Warning: $_\" -ForegroundColor Yellow",
      "}",
      "",
      "Write-Host '✓ Cleanup complete' -ForegroundColor Green",
      "Write-Host ''"
    ]
    valid_exit_codes = [0, 1, 3010]
  }

  # Pre-restart validation
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Pre-Restart Validation ===' -ForegroundColor Cyan",
      "Write-Host 'Verifying system is ready for restart...'",
      "",
      "# Check for locked files or processes",
      "Write-Host 'Checking for blocking processes...'",
      "$blockingProcesses = Get-Process | Where-Object { $_.ProcessName -match 'msiexec|setup|install' }",
      "if ($blockingProcesses) {",
      "    Write-Host 'WARNING: Found installer processes running:' -ForegroundColor Yellow",
      "    $blockingProcesses | Format-Table Name, Id -AutoSize",
      "} else {",
      "    Write-Host '  ✓ No blocking processes found'",
      "}",
      "",
      "Write-Host 'System ready for restart' -ForegroundColor Green",
      "Write-Host 'Initiating restart in 5 seconds...'",
      "Start-Sleep -Seconds 5"
    ]
  }

  # Restart Windows
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # Post-restart validation
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Post-Restart Validation ===' -ForegroundColor Cyan",
      "Write-Host 'System restarted successfully'",
      "Write-Host 'Verifying system state...'",
      "",
      "# Wait for system to stabilize",
      "Start-Sleep -Seconds 15",
      "",
      "Write-Host 'System ready for Sysprep' -ForegroundColor Green",
      "Write-Host ''"
    ]
  }

  # Generalize image (Sysprep)
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Generalizing Image (Sysprep) ===' -ForegroundColor Cyan",
      "Write-Host 'Preparing image for deployment...'",
      "",
      "# Verify Sysprep exists",
      "$sysprepPath = \"$env:SystemRoot\\System32\\Sysprep\\sysprep.exe\"",
      "if (Test-Path $sysprepPath) {",
      "    Write-Host \"Sysprep found at: $sysprepPath\"",
      "} else {",
      "    throw 'Sysprep.exe not found!'",
      "}",
      "",
      "Write-Host 'Launching Sysprep...'",
      "& $sysprepPath /generalize /oobe /quit /mode:vm",
      "",
      "Write-Host 'Sysprep initiated. VM will shut down automatically.' -ForegroundColor Green"
    ]
  }

  # Generate manifest
  post-processor "manifest" {
    output     = "manifest-java-devbox.json"
    strip_path = true
    custom_data = {
      team_name           = "Java Dev Team"
      image_name          = local.image_name
      image_version       = var.image_version
      baseline_image      = "SecurityBaselineImage"
      baseline_version    = var.baseline_image_version
      build_time          = timestamp()
      description         = "Java development image with JDK 11/17/21, Maven, Gradle, IntelliJ, Eclipse, VS Code, WSL 2, and Ubuntu"
      java_versions       = "OpenJDK 11, 17, 21 (LTS)"
      wsl_version         = "WSL 2 with Ubuntu"
    }
  }
}
