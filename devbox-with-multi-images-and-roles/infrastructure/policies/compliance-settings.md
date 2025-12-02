# Intune Compliance Settings
# This file documents the compliance requirements for DevBox images
# Managed by Security Team and Operations Team

## Required Security Settings

### Windows Defender
- Real-time protection: ENABLED (enforced by base provisioners)
- Behavior monitoring: ENABLED
- Cloud-delivered protection: ENABLED
- Automatic sample submission: ENABLED

### Windows Firewall
- Domain profile: ENABLED (enforced by base provisioners)
- Private profile: ENABLED
- Public profile: ENABLED

### BitLocker (Managed by Intune Policy)
- OS Drive encryption: REQUIRED
- Fixed data drives: REQUIRED
- Encryption method: XTS-AES 256

### Windows Updates (Managed by Intune Policy)
- Quality updates: Install within 7 days
- Feature updates: Defer 30 days
- Restart behavior: Schedule outside business hours

### User Account Control
- Enabled: YES (enforced by base provisioners)
- Prompt behavior: Prompt for credentials on secure desktop

## Intune Device Compliance Policies

### Password Requirements
- Minimum length: 12 characters
- Complexity: Required
- Expiration: 90 days
- Prevent reuse: 10 previous passwords

### Device Health Attestation
- BitLocker: Required
- Secure Boot: Required
- Code Integrity: Required

### System Security
- Antivirus: Required and up-to-date
- Antispyware: Required and up-to-date
- Windows Defender Firewall: Required

## Conditional Access Policies

### Require Compliant Device
- Target: All Dev Box users
- Condition: Accessing corporate resources
- Requirement: Device must be compliant

### Multi-Factor Authentication
- Target: All Dev Box users
- Condition: Sign-in to Dev Box
- Requirement: MFA required

## Application Control

### Allowed Application Categories
- Development tools and IDEs
- Source control clients
- Cloud CLI tools
- Productivity software
- Communication tools

### Blocked Applications
- Unauthorized remote access tools
- Peer-to-peer file sharing
- Cryptocurrency miners
- Unauthorized VPN clients

## Audit and Monitoring

### Required Logging
- PowerShell script block logging: ENABLED
- Process creation events: ENABLED
- Windows Event Log retention: 90 days minimum

### Microsoft Defender for Endpoint
- Onboarding: Required for all Dev Boxes
- Data collection: Full
- Response actions: Enabled

## Enforcement

These settings are enforced through:
1. Base Packer provisioners (required-provisioners.hcl)
2. Intune device compliance policies
3. Azure AD conditional access policies
4. Regular compliance scans

Any Dev Box found non-compliant will:
1. Generate alert to security team
2. Be marked as non-compliant in Intune
3. Potentially lose access to corporate resources
4. Require remediation before re-enabling access
