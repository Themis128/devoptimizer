#!/usr/bin/env python3
import subprocess
import json
import sys

def get_appx_package(package_name):
    """Run PowerShell to get the AppxPackage details as JSON."""
    # Define a PowerShell script block that takes a parameter $name
    script_block = """param($name)
Get-AppxPackage -Name $name | Select-Object Name, Version, PublisherDisplayName, InstallLocation, IsFramework, IsResourcePackage, Status | ConvertTo-Json"""
    # Build the command: powershell.exe -Command "<script_block>" -name <package_name>
    cmd = [
        'powershell.exe',
        '-Command',
        script_block,
        '-name',
        package_name
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if result.returncode == 0 and result.stdout.strip():
            # Parse the JSON
            return json.loads(result.stdout)
        else:
            # If there was an error or no output, return None
            return None
    except Exception as e:
        print(f"Error running command for {package_name}: {e}", file=sys.stderr)
        return None

def main():
    # List of package names to check
    apps = [
        '5319275A.WhatsAppDesktop',
        '7EE7776C.LinkedInforWindows',
        'BytedancePte.Ltd.TikTok',
        'com.tinyspeck.slackdesktop',
        'FACEBOOK.FACEBOOK',
        'Facebook.InstagramBeta',
        'Instagram.ThreadsanInstagramapp',
        'MSTeams',
        'SpotifyAB.SpotifyMusic',
        'TelegramMessengerLLP.TelegramDesktop',
        'www.messenger.com-43D6998D'
    ]

    for app in apps:
        pkg_info = get_appx_package(app)
        if pkg_info:
            print(f"=== {pkg_info['Name']} ===")
            print(f"  Version: {pkg_info['Version']}")
            print(f"  Publisher: {pkg_info['PublisherDisplayName']}")
            print(f"  InstallLocation: {pkg_info['InstallLocation']}")
            print(f"  IsFramework: {pkg_info['IsFramework']}")
            print(f"  IsResourcePackage: {pkg_info['IsResourcePackage']}")
            print(f"  Status: {pkg_info['Status']}")
            print()

if __name__ == '__main__':
    main()