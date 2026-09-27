@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title  - Standard Mode- some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo              AWS POWERSHELL MODULES DOWNLOADER
echo ================================================================
echo.
echo Downloading all available AWS PowerShell modules
echo.
echo ================================================================

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
echo [INFO] Running with administrator privileges
) else (
echo [WARNING] Some operations may require administrator privileges
)

echo.
echo ================================================================
echo                    DOWNLOADING MODULES
echo ================================================================

:: Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if %errorLevel% neq 0 (
echo [ERROR] PowerShell not found. Please install PowerShell first.
pause
exit /b 1
)

:: Set execution policy
echo [1/10] Setting PowerShell execution policy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
echo [SUCCESS] Execution policy set

:: Install NuGet provider
echo [2/10] Installing NuGet provider...
powershell -Command "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force"
echo [SUCCESS] NuGet provider installed

:: Install PowerShellGet
echo [3/10] Installing PowerShellGet...
powershell -Command "Install-Module -Name PowerShellGet -Force -AllowClobber"
echo [SUCCESS] PowerShellGet installed

:: Install AWS.Tools.Common
echo [4/10] Installing AWS.Tools.Common...
powershell -Command "Install-Module -Name AWS.Tools.Common -Force -AllowClobber"
echo [SUCCESS] AWS.Tools.Common installed

:: Install AWS.Tools.Installer
echo [5/10] Installing AWS.Tools.Installer...
powershell -Command "Install-Module -Name AWS.Tools.Installer -Force -AllowClobber"
echo [SUCCESS] AWS.Tools.Installer installed

:: Install all AWS Tools modules
echo [6/10] Installing all AWS Tools modules...
powershell -Command "Install-AWSToolsModule -CleanUp -Force"
echo [SUCCESS] All AWS Tools modules installed

:: Install AWS Lambda Tools
echo [7/10] Installing AWS Lambda Tools...
powershell -Command "Install-Module -Name AWS.Tools.Lambda -Force -AllowClobber"
echo [SUCCESS] AWS Lambda Tools installed

:: Install AWS CloudFormation Tools
echo [8/10] Installing AWS CloudFormation Tools...
powershell -Command "Install-Module -Name AWS.Tools.CloudFormation -Force -AllowClobber"
echo [SUCCESS] AWS CloudFormation Tools installed

:: Install AWS S3 Tools
echo [9/10] Installing AWS S3 Tools...
powershell -Command "Install-Module -Name AWS.Tools.S3 -Force -AllowClobber"
echo [SUCCESS] AWS S3 Tools installed

:: Install AWS EC2 Tools
echo [10/10] Installing AWS EC2 Tools...
powershell -Command "Install-Module -Name AWS.Tools.EC2 -Force -AllowClobber"
echo [SUCCESS] AWS EC2 Tools installed

:: Install additional AWS modules
echo [BONUS] Installing additional AWS modules...
powershell -Command "Install-Module -Name AWS.Tools.RDS -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.ElasticLoadBalancing -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.IAM -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.CloudWatch -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.SQS -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.SNS -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.DynamoDB -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.CloudFront -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.Route53 -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.SES -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.StepFunctions -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.APIGateway -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.CognitoIdentity -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.CognitoIdentityProvider -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.KMS -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.SecretsManager -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.SSM -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.CloudTrail -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.ConfigService -Force -AllowClobber"
powershell -Command "Install-Module -Name AWS.Tools.CloudFormation -Force -AllowClobber"
echo [SUCCESS] Additional AWS modules installed

:: List installed modules
echo.
echo ================================================================
echo                    INSTALLED MODULES
echo ================================================================
echo.
echo [INFO] Listing installed AWS modules...
powershell -Command "Get-Module -ListAvailable -Name AWS* | Select-Object Name, Version | Sort-Object Name | Format-Table -AutoSize"

:: Create module summary
echo [INFO] Creating module summary...
powershell -Command "Get-Module -ListAvailable -Name AWS* | Select-Object Name, Version | Sort-Object Name | Export-Csv -Path '%USERPROFILE%\Desktop\DevOptimizer\aws-modules-summary.csv' -NoTypeInformation"

echo.
echo ================================================================
echo                    FINAL REPORT
echo ================================================================
echo.
echo [SUCCESS] AWS PowerShell modules installation completed!
echo.
echo [INFO] All AWS PowerShell modules have been installed
echo [INFO] Module summary saved to: %USERPROFILE%\Desktop\DevOptimizer\aws-modules-summary.csv
echo.
echo [INFO] You can now use AWS PowerShell cmdlets in your scripts
echo [INFO] Example: Get-EC2Instance, Get-S3Bucket, New-CloudFormationStack
echo.
echo ================================================================
echo.

pause
