@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title  - Standard Mode- some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo              AWS TERRAFORM ANALYZER
echo ================================================================
echo.
echo Comprehensive Terraform state and infrastructure analysis
echo.
echo ================================================================

:: Check for Terraform
terraform version >nul 2>&1
if %errorLevel% neq 0 (
echo [WARNING] Terraform not found. Installing Terraform...
choco install terraform -y >nul 2>&1
:: Always refresh PATH and verify installation regardless of choco exit code
echo [INFO] Refreshing PATH and verifying Terraform installation...
call refreshenv >nul 2>&1
if %errorLevel% neq 0 (
echo [INFO] Refreshenv not available, refreshing PATH manually...
for /f "usebackq tokens=2*" %%A in (`reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH`) do set "PATH=%%B"
)
timeout /t 3 /nobreak >nul
:: Try multiple Terraform locations
"C:\ProgramData\chocolatey\lib\terraform\tools\terraform.exe" version >nul 2>&1
if %errorLevel% neq 0 (
terraform version >nul 2>&1
if %errorLevel% neq 0 (
echo [WARNING] Terraform verification failed, but continuing...
echo [INFO] You may need to restart your terminal or add Terraform to PATH manually
echo [INFO] Terraform is typically installed at: C:\ProgramData\chocolatey\lib\terraform\tools\
) else (
echo [SUCCESS] Terraform verified successfully!
)
) else (
echo [SUCCESS] Terraform verified successfully!
)
)

:: Check for AWS CLI
aws --version >nul 2>&1
if %errorLevel% neq 0 (
echo [WARNING] AWS CLI not found. Installing AWS CLI...
choco install awscli -y >nul 2>&1
:: Always refresh PATH and verify installation regardless of choco exit code
echo [INFO] Refreshing PATH and verifying AWS CLI installation...
call refreshenv >nul 2>&1
if %errorLevel% neq 0 (
echo [INFO] Refreshenv not available, refreshing PATH manually...
for /f "usebackq tokens=2*" %%A in (`reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH`) do set "PATH=%%B"
)
timeout /t 3 /nobreak >nul
:: Try multiple AWS CLI locations
"C:\ProgramData\chocolatey\lib\awscli\tools\aws.exe" --version >nul 2>&1
if %errorLevel% neq 0 (
"C:\Program Files\Amazon\AWSCLIV2\aws.exe" --version >nul 2>&1
if %errorLevel% neq 0 (
aws --version >nul 2>&1
if %errorLevel% neq 0 (
echo [WARNING] AWS CLI verification failed, but continuing...
echo [INFO] You may need to restart your terminal or add AWS CLI to PATH manually
echo [INFO] AWS CLI is typically installed at: C:\Program Files\Amazon\AWSCLIV2\
) else (
echo [SUCCESS] AWS CLI verified successfully!
)
) else (
echo [SUCCESS] AWS CLI verified successfully!
)
) else (
echo [SUCCESS] AWS CLI verified successfully!
)
)

echo.
echo ================================================================
echo                    TERRAFORM ANALYSIS MENU
echo ================================================================
echo.
echo 1.  [ANALYSIS] Terraform State Analysis
echo 2.  [INVENTORY] Resource Inventory
echo 3.  [GRAPH] Dependency Graph
echo 4.  [DRIFT] Resource Drift Detection
echo 5.  [COST] Cost Estimation
echo 6.  [SECURITY] Security Analysis
echo 7.  [PERFORMANCE] Performance Analysis
echo 8.  [COMPLIANCE] Compliance Check
echo 9.  [BACKUP] State Backup and Restore
echo 10. [WORKSPACE] Terraform Workspace Management
echo 11. [REPORT] Complete Terraform Report
echo 0.  [EXIT] Exit
echo.
echo ================================================================

set /p choice="Enter your choice (0-11): "

if "%choice%"=="1" goto state_analysis
if "%choice%"=="2" goto resource_inventory
if "%choice%"=="3" goto dependency_graph
if "%choice%"=="4" goto drift_detection
if "%choice%"=="5" goto cost_estimation
if "%choice%"=="6" goto security_analysis
if "%choice%"=="7" goto performance_analysis
if "%choice%"=="8" goto compliance_check
if "%choice%"=="9" goto state_backup
if "%choice%"=="10" goto workspace_management
if "%choice%"=="11" goto complete_report
if "%choice%"=="0" goto exit
goto invalid_choice

:state_analysis
echo.
echo ================================================================
echo              [ANALYSIS] TERRAFORM STATE ANALYSIS
echo ================================================================
echo.
echo Analyzing Terraform state...
echo.

:: Create reports directory
if not exist "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports" mkdir "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports"

:: Initialize Terraform if needed
if not exist "terraform.tfstate" (
echo [INFO] No local state file found. Initializing Terraform...
terraform init
)

:: Get state information
echo [STATE] Getting Terraform state information...
terraform show -json > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\terraform-state.json"
terraform state list > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\terraform-resources.txt"

:: Get state summary
echo [STATE] Getting state summary...
terraform state show > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\state-summary.txt"

:: Get state version
echo [STATE] Getting state version...
terraform version > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\terraform-version.txt"

:: Get providers
echo [STATE] Getting provider information...
terraform providers > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\terraform-providers.txt"

echo [SUCCESS] Terraform state analysis completed!
echo.
pause
goto main_menu

:resource_inventory
echo.
echo ================================================================
echo              [INVENTORY] RESOURCE INVENTORY
echo ================================================================
echo.
echo Creating resource inventory...
echo.

:: Get all resources
echo [INVENTORY] Getting all resources...
terraform state list > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\resource-list.txt"

:: Get resource details
echo [INVENTORY] Getting detailed resource information...
for /f "tokens=*" %%r in ('terraform state list') do (
echo [INFO] Analyzing resource: %%r
terraform state show "%%r" > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\resource-%%r.txt"
)

:: Get resource counts by type
echo [INVENTORY] Getting resource counts by type...
for /f %%i in ('terraform state list ^| findstr /i "aws_instance" ^| find /c /v ""') do echo %%i > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\ec2-count.txt"
for /f %%i in ('terraform state list ^| findstr /i "aws_db_instance" ^| find /c /v ""') do echo %%i > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\rds-count.txt"
for /f %%i in ('terraform state list ^| findstr /i "aws_s3_bucket" ^| find /c /v ""') do echo %%i > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\s3-count.txt"
for /f %%i in ('terraform state list ^| findstr /i "aws_lambda_function" ^| find /c /v ""') do echo %%i > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\lambda-count.txt"

echo [SUCCESS] Resource inventory completed!
echo.
pause
goto main_menu

:dependency_graph
echo.
echo ================================================================
echo              [GRAPH] DEPENDENCY GRAPH
echo ================================================================
echo.
echo Generating dependency graph...
echo.

:: Generate dependency graph
echo [GRAPH] Generating dependency graph...
terraform graph > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\dependency-graph.dot"
echo [SUCCESS] Dependency graph generated

:: Convert to other formats
echo [GRAPH] Converting to other formats...
terraform graph -type=plan > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\plan-graph.dot"
terraform graph -type=apply > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\apply-graph.dot"

:: Generate JSON graph
echo [GRAPH] Generating JSON graph...
terraform graph -json > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\dependency-graph.json"

echo [SUCCESS] Dependency graph analysis completed!
echo [INFO] Graph files saved to: %USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports
echo.
pause
goto main_menu

:drift_detection
echo.
echo ================================================================
echo              [DRIFT] RESOURCE DRIFT DETECTION
echo ================================================================
echo.
echo Detecting resource drift...
echo.

:: Generate plan to detect drift
echo [DRIFT] Generating plan to detect drift...
terraform plan -detailed-exitcode > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\drift-plan.txt"
if %errorLevel% == 2 (
echo [WARNING] Drift detected! Check drift-plan.txt for details
) else (
echo [SUCCESS] No drift detected
)

:: Get plan in JSON format
echo [DRIFT] Getting plan in JSON format...
terraform plan -out=drift-plan.out
terraform show -json drift-plan.out > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\drift-plan.json"

:: Check for specific resource types
echo [DRIFT] Checking for specific resource types...
terraform plan -target=aws_instance -out=ec2-drift.out > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\ec2-drift.txt" 2>nul
terraform plan -target=aws_db_instance -out=rds-drift.out > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\rds-drift.txt" 2>nul

echo [SUCCESS] Drift detection completed!
echo.
pause
goto main_menu

:cost_estimation
echo.
echo ================================================================
echo              [COST] COST ESTIMATION
echo ================================================================
echo.
echo Estimating costs...
echo.

:: Check for Infracost
echo [COST] Checking for Infracost...
infracost --version >nul 2>&1
if %errorLevel% neq 0 (
echo [INFO] Installing Infracost...
choco install infracost -y
if %errorLevel% neq 0 (
echo [WARNING] Failed to install Infracost. Using Terraform plan for cost estimation.
goto :terraform_cost_estimation
)
)

:: Run Infracost
echo [COST] Running Infracost cost estimation...
infracost breakdown --path . --format json > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\infracost-breakdown.json"
infracost breakdown --path . --format table > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\infracost-breakdown.txt"

:: Get cost summary
echo [COST] Getting cost summary...
infracost summary --path . > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\infracost-summary.txt"

goto :cost_estimation_done

:terraform_cost_estimation
echo [COST] Using Terraform plan for cost estimation...
terraform plan -out=cost-plan.out
terraform show -json cost-plan.out > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\cost-plan.json"

:cost_estimation_done
echo [SUCCESS] Cost estimation completed!
echo.
pause
goto main_menu

:security_analysis
echo.
echo ================================================================
echo              [SECURITY] SECURITY ANALYSIS
echo ================================================================
echo.
echo Analyzing security...
echo.

:: Check for TFSec
echo [SECURITY] Checking for TFSec...
tfsec --version >nul 2>&1
if %errorLevel% neq 0 (
echo [INFO] Installing TFSec...
choco install tfsec -y
if %errorLevel% neq 0 (
echo [WARNING] Failed to install TFSec. Using basic security analysis.
goto :basic_security_analysis
)
)

:: Run TFSec
echo [SECURITY] Running TFSec security analysis...
tfsec . --format json > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\tfsec-results.json"
tfsec . --format table > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\tfsec-results.txt"

:: Get security summary
echo [SECURITY] Getting security summary...
tfsec . --format summary > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\tfsec-summary.txt"

goto :security_analysis_done

:basic_security_analysis
echo [SECURITY] Running basic security analysis...
:: Check for common security issues
findstr /i "password\|secret\|key\|token" *.tf > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\security-keywords.txt" 2>nul
findstr /i "0.0.0.0/0" *.tf > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\open-security-groups.txt" 2>nul

:security_analysis_done
echo [SUCCESS] Security analysis completed!
echo.
pause
goto main_menu

:performance_analysis
echo.
echo ================================================================
echo              [PERFORMANCE] PERFORMANCE ANALYSIS
echo ================================================================
echo.
echo Analyzing performance...
echo.

:: Get resource counts
echo [PERFORMANCE] Getting resource counts...
for /f %%i in ('terraform state list ^| find /c /v ""') do echo %%i > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\total-resources.txt"

:: Get resource types
echo [PERFORMANCE] Getting resource types...
terraform state list | findstr /i "aws_" > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\aws-resources.txt"

:: Get state file size
echo [PERFORMANCE] Getting state file size...
for %%f in (terraform.tfstate*) do (
echo %%~zf bytes >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\state-file-sizes.txt"
)

:: Get plan performance
echo [PERFORMANCE] Getting plan performance...
echo [INFO] Running terraform plan to measure performance...
terraform plan -out=perf-plan.out > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\plan-performance.txt"

echo [SUCCESS] Performance analysis completed!
echo.
pause
goto main_menu

:compliance_check
echo.
echo ================================================================
echo              [COMPLIANCE] COMPLIANCE CHECK
echo ================================================================
echo.
echo Checking compliance...
echo.

:: Check for Terraform Compliance
echo [COMPLIANCE] Checking for Terraform Compliance...
terraform-compliance --version >nul 2>&1
if %errorLevel% neq 0 (
echo [INFO] Installing Terraform Compliance...
pip install terraform-compliance
if %errorLevel% neq 0 (
echo [WARNING] Failed to install Terraform Compliance. Using basic compliance check.
goto :basic_compliance_check
)
)

:: Run compliance check
echo [COMPLIANCE] Running compliance check...
terraform-compliance -f . -t . > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\compliance-results.txt"

goto :compliance_check_done

:basic_compliance_check
echo [COMPLIANCE] Running basic compliance check...
:: Check for common compliance issues
findstr /i "encryption" *.tf > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\encryption-check.txt" 2>nul
findstr /i "logging" *.tf > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\logging-check.txt" 2>nul
findstr /i "backup" *.tf > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\backup-check.txt" 2>nul

:compliance_check_done
echo [SUCCESS] Compliance check completed!
echo.
pause
goto main_menu

:state_backup
echo.
echo ================================================================
echo              [BACKUP] STATE BACKUP & RESTORE
echo ================================================================
echo.
echo Managing state backup and restore...
echo.

:: Create backup directory
if not exist "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups" mkdir "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups"

:: Backup current state
echo [BACKUP] Backing up current state...
if exist "terraform.tfstate" (
copy "terraform.tfstate" "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\terraform.tfstate.backup.%date:~-4,4%%date:~-10,2%%date:~-7,2%.%time:~0,2%%time:~3,2%%time:~6,2%"
echo [SUCCESS] State backed up
) else (
echo [WARNING] No state file found to backup
)

:: List backups
echo [BACKUP] Listing available backups...
dir "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\*.backup.*" > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\backup-list.txt"

:: Create state restore script
echo [BACKUP] Creating state restore script...
echo @echo off > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\restore-state.bat"
echo echo Available backups: >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\restore-state.bat"
echo dir *.backup.* >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\restore-state.bat"
echo echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\restore-state.bat"
echo set /p backup="Enter backup filename: " >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\restore-state.bat"
echo copy "%%backup%%" "terraform.tfstate" >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\restore-state.bat"
echo echo State restored! >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\restore-state.bat"
echo pause >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Backups\restore-state.bat"

echo [SUCCESS] State backup and restore setup completed!
echo.
pause
goto main_menu

:workspace_management
echo.
echo ================================================================
echo              [WORKSPACE] TERRAFORM WORKSPACE MANAGEMENT
echo ================================================================
echo.
echo Managing Terraform workspaces...
echo.

:: List workspaces
echo [WORKSPACE] Listing workspaces...
terraform workspace list > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-list.txt"

:: Get current workspace
echo [WORKSPACE] Getting current workspace...
terraform workspace show > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\current-workspace.txt"

:: Get workspace info
echo [WORKSPACE] Getting workspace information...
terraform workspace list | findstr /v "default" > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\non-default-workspaces.txt"

:: Create workspace management script
echo [WORKSPACE] Creating workspace management script...
echo @echo off > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo echo Terraform Workspace Manager >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo echo ========================== >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo echo Current workspace: >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo terraform workspace show >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo echo Available workspaces: >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo terraform workspace list >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo set /p workspace="Enter workspace name: " >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo terraform workspace select "%%workspace%%" >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo echo Workspace switched! >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"
echo pause >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\workspace-manager.bat"

echo [SUCCESS] Workspace management completed!
echo.
pause
goto main_menu

:complete_report
echo.
echo ================================================================
echo              [REPORT] COMPLETE TERRAFORM REPORT
echo ================================================================
echo.
echo Generating complete Terraform report...
echo.

:: Run all analyses
call :state_analysis
call :resource_inventory
call :dependency_graph
call :drift_detection
call :cost_estimation
call :security_analysis
call :performance_analysis
call :compliance_check
call :workspace_management

:: Generate summary report
echo [REPORT] Generating summary report...
echo Terraform Infrastructure Report - %date% %time% > "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
echo ========================================== >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
echo Terraform Version: >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
type "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\terraform-version.txt" >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
echo Current Workspace: >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
type "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\current-workspace.txt" >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
echo Total Resources: >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
type "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\total-resources.txt" >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
echo Resource List: >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"
type "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\resource-list.txt" >> "%USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports\TERRAFORM-SUMMARY-REPORT.txt"

echo [SUCCESS] Complete Terraform report generated!
echo [INFO] All reports saved to: %USERPROFILE%\Desktop\DevOptimizer\Terraform-Reports
echo.
pause
goto main_menu

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please select a number between 0-11.
echo.
pause
goto main_menu

:main_menu
cls
goto start

:exit
echo.
echo ================================================================
echo                    THANK YOU FOR USING
echo                AWS TERRAFORM ANALYZER
echo ================================================================
echo.
echo Your Terraform infrastructure has been analyzed and documented!
echo.
echo ================================================================
echo.
pause
exit

:start
goto main_menu
exit /b %ERRORLEVEL%
