"""
Security hardening module for DevOptimizer - Python port of Security-Hardening.ps1.
"""

import subprocess
import os
from pathlib import Path
from dataclasses import dataclass, field
from typing import List


@dataclass
class HardeningResult:
    action: str
    status: str
    details: str = ""
    error: str = ""


@dataclass
class SecurityHardening:
    sysinternals_dir: Path = field(default_factory=lambda: Path("D:/DevOptimizer/tools/sysinternals"))
    results: List[HardeningResult] = field(default_factory=list)

    def add_result(self, action: str, status: str, details: str = "", error: str = "") -> None:
        self.results.append(HardeningResult(action, status, details, error))

    def configure_windows_defender(self) -> None:
        # Defender: Realtime monitoring
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-MpPreference -DisableRealtimeMonitoring $false"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Defender: Realtime Monitoring", "success")
            else:
                self.add_result("Defender: Realtime Monitoring", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Defender: Realtime Monitoring", "failed", error=str(e))

        # Defender: Behavior monitoring
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-MpPreference -DisableBehaviorMonitoring $false"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Defender: Behavior Monitoring", "success")
            else:
                self.add_result("Defender: Behavior Monitoring", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Defender: Behavior Monitoring", "failed", error=str(e))

        # Defender: Cloud protection
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-MpPreference -DisableBlockAtFirstSeen $false"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Defender: Cloud Protection", "success")
            else:
                self.add_result("Defender: Cloud Protection", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Defender: Cloud Protection", "failed", error=str(e))

        # Defender: PUA protection
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-MpPreference -PUAProtection Enabled"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Defender: PUA Protection", "success")
            else:
                self.add_result("Defender: PUA Protection", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Defender: PUA Protection", "failed", error=str(e))

        # Defender: Network protection
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-MpPreference -EnableNetworkProtection Enabled"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Defender: Network Protection", "success")
            else:
                self.add_result("Defender: Network Protection", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Defender: Network Protection", "failed", error=str(e))

        # Defender: Controlled folder access
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-MpPreference -EnableControlledFolderAccess Enabled"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Defender: Controlled Folder Access", "success")
            else:
                self.add_result("Defender: Controlled Folder Access", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Defender: Controlled Folder Access", "failed", error=str(e))

        # Defender: Attack surface reduction
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-MpPreference -AttackSurfaceReductionRules_Ids BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550, D4F940AB-401B-4EFC-AADC-AD5F3C50688A, 3B576869-A4EC-4529-8536-B80A7769E899, 75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84, D3E037E1-3EB8-44C8-A917-57927947596D, 56A863A9-875E-4185-98A7-B882C64B5CE5, 26190899-1602-49E8-8B27-EB1D0A1CE869, CAFA9D8C-7A4E-4B1D-8D9E-9E5E5E5E5E5E"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Defender: ASR Rules", "success")
            else:
                self.add_result("Defender: ASR Rules", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Defender: ASR Rules", "failed", error=str(e))

    def configure_firewall(self) -> None:
        # Firewall: Enable all profiles
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Firewall: Enable All Profiles", "success")
            else:
                self.add_result("Firewall: Enable All Profiles", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Firewall: Enable All Profiles", "failed", error=str(e))

        # Firewall: Block inbound by default
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Firewall: Default Inbound Block", "success")
            else:
                self.add_result("Firewall: Default Inbound Block", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Firewall: Default Inbound Block", "failed", error=str(e))

        # Firewall: Allow outbound by default
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Firewall: Default Outbound Allow", "success")
            else:
                self.add_result("Firewall: Default Outbound Allow", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Firewall: Default Outbound Allow", "failed", error=str(e))

        # Firewall: Log dropped packets
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-NetFirewallProfile -Profile Domain,Public,Private -LogBlocked True -LogAllowed False"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Firewall: Log Dropped Packets", "success")
            else:
                self.add_result("Firewall: Log Dropped Packets", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Firewall: Log Dropped Packets", "failed", error=str(e))

    def configure_uac(self) -> None:
        # UAC: Enable LUA (Admin Approval Mode)
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'EnableLUA' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("UAC: Enable LUA", "success")
            else:
                self.add_result("UAC: Enable LUA", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("UAC: Enable LUA", "failed", error=str(e))

        # UAC: Elevation behavior for admins
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'ConsentPromptBehaviorAdmin' -Value 5 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("UAC: Admin Consent Prompt", "success")
            else:
                self.add_result("UAC: Admin Consent Prompt", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("UAC: Admin Consent Prompt", "failed", error=str(e))

        # UAC: Elevation behavior for standard users
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'ConsentPromptBehaviorUser' -Value 3 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("UAC: User Consent Prompt", "success")
            else:
                self.add_result("UAC: User Consent Prompt", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("UAC: User Consent Prompt", "failed", error=str(e))

        # UAC: Secure desktop
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'PromptOnSecureDesktop' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("UAC: Secure Desktop", "success")
            else:
                self.add_result("UAC: Secure Desktop", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("UAC: Secure Desktop", "failed", error=str(e))

        # UAC: Filter admin token
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'FilterAdministratorToken' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("UAC: Filter Admin Token", "success")
            else:
                self.add_result("UAC: Filter Admin Token", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("UAC: Filter Admin Token", "failed", error=str(e))

    def configure_lsa_protection(self) -> None:
        # LSA: RunAsPPL
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa' -Name 'RunAsPPL' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("LSA: RunAsPPL", "success")
            else:
                self.add_result("LSA: RunAsPPL", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("LSA: RunAsPPL", "failed", error=str(e))

    def configure_smb_signing(self) -> None:
        # SMB: Require signing for client
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanWorkstation\\Parameters' -Name 'RequireSecuritySignature' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("SMB: Client Require Signing", "success")
            else:
                self.add_result("SMB: Client Require Signing", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("SMB: Client Require Signing", "failed", error=str(e))

        # SMB: Enable signing for client
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanWorkstation\\Parameters' -Name 'EnableSecuritySignature' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("SMB: Client Enable Signing", "success")
            else:
                self.add_result("SMB: Client Enable Signing", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("SMB: Client Enable Signing", "failed", error=str(e))

        # SMB: Require signing for server
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters' -Name 'RequireSecuritySignature' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("SMB: Server Require Signing", "success")
            else:
                self.add_result("SMB: Server Require Signing", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("SMB: Server Require Signing", "failed", error=str(e))

        # SMB: Enable signing for server
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters' -Name 'EnableSecuritySignature' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("SMB: Server Enable Signing", "success")
            else:
                self.add_result("SMB: Server Enable Signing", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("SMB: Server Enable Signing", "failed", error=str(e))

    def disable_smbv1(self) -> None:
        # Disable SMBv1
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("SMBv1: Disable", "success")
            else:
                self.add_result("SMBv1: Disable", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("SMBv1: Disable", "failed", error=str(e))

    def configure_tls(self) -> None:
        # TLS 1.2 Client
        try:
            result = subprocess.run(
                ["powershell", "-Command", "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Client' -Force; Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Client' -Name 'DisabledByDefault' -Value 0 -Type DWord -Force; Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Client' -Name 'Enabled' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("TLS 1.2: Client Enable", "success")
            else:
                self.add_result("TLS 1.2: Client Enable", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("TLS 1.2: Client Enable", "failed", error=str(e))

        # TLS 1.2 Server
        try:
            result = subprocess.run(
                ["powershell", "-Command", "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Server' -Force; Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Server' -Name 'DisabledByDefault' -Value 0 -Type DWord -Force; Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.2\\Server' -Name 'Enabled' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("TLS 1.2: Server Enable", "success")
            else:
                self.add_result("TLS 1.2: Server Enable", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("TLS 1.2: Server Enable", "failed", error=str(e))

        # TLS 1.3 Client
        try:
            result = subprocess.run(
                ["powershell", "-Command", "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.3\\Client' -Force; Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.3\\Client' -Name 'DisabledByDefault' -Value 0 -Type DWord -Force; Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.3\\Client' -Name 'Enabled' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("TLS 1.3: Client Enable", "success")
            else:
                self.add_result("TLS 1.3: Client Enable", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("TLS 1.3: Client Enable", "failed", error=str(e))

        # TLS 1.3 Server
        try:
            result = subprocess.run(
                ["powershell", "-Command", "New-Item -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.3\\Server' -Force; Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.3\\Server' -Name 'DisabledByDefault' -Value 0 -Type DWord -Force; Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\TLS 1.3\\Server' -Name 'Enabled' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("TLS 1.3: Server Enable", "success")
            else:
                self.add_result("TLS 1.3: Server Enable", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("TLS 1.3: Server Enable", "failed", error=str(e))

    def configure_audit_policy(self) -> None:
        # Audit: Logon/Logoff
        try:
            result = subprocess.run(
                ["auditpol", "/set", "/subcategory:Logon", "/success:enable", "/failure:enable"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Audit: Logon", "success")
            else:
                self.add_result("Audit: Logon", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Audit: Logon", "failed", error=str(e))

        # Audit: Account Management
        try:
            result = subprocess.run(
                ["auditpol", "/set", "/subcategory:User Account Management", "/success:enable", "/failure:enable"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Audit: Account Management", "success")
            else:
                self.add_result("Audit: Account Management", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Audit: Account Management", "failed", error=str(e))

        # Audit: Process Creation
        try:
            result = subprocess.run(
                ["auditpol", "/set", "/subcategory:Process Creation", "/success:enable", "/failure:enable"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Audit: Process Creation", "success")
            else:
                self.add_result("Audit: Process Creation", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Audit: Process Creation", "failed", error=str(e))

        # Audit: Object Access - File System
        try:
            result = subprocess.run(
                ["auditpol", "/set", "/subcategory:File System", "/success:enable", "/failure:enable"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Audit: File System", "success")
            else:
                self.add_result("Audit: File System", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Audit: File System", "failed", error=str(e))

        # Audit: Registry
        try:
            result = subprocess.run(
                ["auditpol", "/set", "/subcategory:Registry", "/success:enable", "/failure:enable"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Audit: Registry", "success")
            else:
                self.add_result("Audit: Registry", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Audit: Registry", "failed", error=str(e))

        # Audit: System Integrity
        try:
            result = subprocess.run(
                ["auditpol", "/set", "/subcategory:System Integrity", "/success:enable", "/failure:enable"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Audit: System Integrity", "success")
            else:
                self.add_result("Audit: System Integrity", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Audit: System Integrity", "failed", error=str(e))

    def install_sysinternals(self) -> None:
        # Create sysinternals directory using subprocess
        try:
            result = subprocess.run(
                ["powershell", "-Command", "New-Item -Path 'D:/DevOptimizer/tools/sysinternals' -ItemType Directory -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Sysinternals: Directory Create", "success")
            else:
                self.add_result("Sysinternals: Directory Create", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Sysinternals: Directory Create", "failed", error=str(e))

        # Download Sysinternals Suite
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/SysinternalsSuite.zip' -OutFile 'D:/DevOptimizer/tools/sysinternals/SysinternalsSuite.zip'"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Sysinternals: Download", "success")
            else:
                self.add_result("Sysinternals: Download", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Sysinternals: Download", "failed", error=str(e))

        # Extract Sysinternals Suite
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Expand-Archive -Path 'D:/DevOptimizer/tools/sysinternals/SysinternalsSuite.zip' -DestinationPath 'D:/DevOptimizer/tools/sysinternals' -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("Sysinternals: Extract", "success")
            else:
                self.add_result("Sysinternals: Extract", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("Sysinternals: Extract", "failed", error=str(e))

    def disable_llmnr(self) -> None:
        # Disable LLMNR
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\DNSClient' -Name 'EnableMulticast' -Value 0 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("LLMNR: Disable", "success")
            else:
                self.add_result("LLMNR: Disable", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("LLMNR: Disable", "failed", error=str(e))

    def disable_netbios(self) -> None:
        # Disable NetBIOS over TCP/IP
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\NetBT\\Parameters' -Name 'SmbDeviceEnabled' -Value 0 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("NetBIOS: Disable", "success")
            else:
                self.add_result("NetBIOS: Disable", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("NetBIOS: Disable", "failed", error=str(e))

    def configure_wdigest(self) -> None:
        # Disable WDigest credential caching
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\WDigest' -Name 'UseLogonCredential' -Value 0 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("WDigest: Disable Credential Caching", "success")
            else:
                self.add_result("WDigest: Disable Credential Caching", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("WDigest: Disable Credential Caching", "failed", error=str(e))

    def configure_rdp(self) -> None:
        # RDP: Network Level Authentication
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp' -Name 'UserAuthentication' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("RDP: NLA", "success")
            else:
                self.add_result("RDP: NLA", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("RDP: NLA", "failed", error=str(e))

        # RDP: Disable if not needed
        try:
            result = subprocess.run(
                ["powershell", "-Command", "Set-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 1 -Type DWord -Force"],
                capture_output=True, text=True, check=False
            )
            if result.returncode == 0:
                self.add_result("RDP: Deny Connections", "success")
            else:
                self.add_result("RDP: Deny Connections", "failed", error=result.stderr)
        except Exception as e:
            self.add_result("RDP: Deny Connections", "failed", error=str(e))

    def run_all(self) -> List[HardeningResult]:
        self.configure_windows_defender()
        self.configure_firewall()
        self.configure_uac()
        self.configure_lsa_protection()
        self.configure_smb_signing()
        self.disable_smbv1()
        self.configure_tls()
        self.configure_audit_policy()
        self.install_sysinternals()
        self.disable_llmnr()
        self.disable_netbios()
        self.configure_wdigest()
        self.configure_rdp()
        return self.results