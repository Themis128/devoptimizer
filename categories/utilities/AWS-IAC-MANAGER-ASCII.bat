@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title AWS Infrastructure as Code Manager

color 0A
echo.
echo ================================================================
echo              AWS INFRASTRUCTURE AS CODE MANAGER
echo ================================================================
echo.
echo Comprehensive AWS IaC management and monitoring suite
echo.
echo ================================================================

:: Check for AWS CLI
aws --version >nul 2>&1
if %errorLevel% neq 0 (
echo [ERROR] AWS CLI not found. Please install AWS CLI first.
echo [INFO] Download from: https://aws.amazon.com/cli/
pause
exit /b 1
)

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% == 0 (
echo [INFO] Running with administrator privileges
) else (
echo [WARNING] Some operations may require administrator privileges
)

echo.
echo ================================================================
echo                    AWS IAC MENU
echo ================================================================
echo.
echo 1.  [DISCOVER] Infrastructure Discovery
echo 2.  [STACK]    CloudFormation Stack Info
echo 3.  [TERRAFORM] Terraform State Info
echo 4.  [EC2]      EC2 Instance Management
echo 5.  [RDS]      RDS Database Info
echo 6.  [LB]       Load Balancer Info
echo 7.  [SECURITY] Security Group Analysis
echo 8.  [S3]       S3 Bucket Analysis
echo 9.  [LAMBDA]   Lambda Function Info
echo 10. [COST]     Cost Analysis
echo 11. [OPTIMIZE] Resource Optimization
echo 12. [REPORT]   Complete Infrastructure Report
echo 13. [SETUP]    AWS CLI Setup
echo 14. [SYNC]     Sync All Resources
echo 0.  [EXIT]     Exit
echo.
echo ================================================================

:menu
set /p choice="Enter your choice (0-14): "

if "%choice%"=="1" (
echo.
echo [DISCOVER] Running Infrastructure Discovery...
call :infrastructure_discovery
) else if "%choice%"=="2" (
echo.
echo [STACK] Getting CloudFormation Stack Information...
call :cloudformation_info
) else if "%choice%"=="3" (
echo.
echo [TERRAFORM] Analyzing Terraform State...
call :terraform_info
) else if "%choice%"=="4" (
echo.
echo [EC2] Managing EC2 Instances...
call :ec2_management
) else if "%choice%"=="5" (
echo.
echo [RDS] Getting RDS Database Information...
call :rds_info
) else if "%choice%"=="6" (
echo.
echo [LB] Getting Load Balancer Information...
call :loadbalancer_info
) else if "%choice%"=="7" (
echo.
echo [SECURITY] Analyzing Security Groups...
call :security_analysis
) else if "%choice%"=="8" (
echo.
echo [S3] Analyzing S3 Buckets...
call :s3_analysis
) else if "%choice%"=="9" (
echo.
echo [LAMBDA] Getting Lambda Function Information...
call :lambda_info
) else if "%choice%"=="10" (
echo.
echo [COST] Running Cost Analysis...
call :cost_analysis
) else if "%choice%"=="11" (
echo.
echo [OPTIMIZE] Running Resource Optimization...
call :resource_optimization
) else if "%choice%"=="12" (
echo.
echo [REPORT] Generating Complete Infrastructure Report...
call :complete_report
) else if "%choice%"=="13" (
echo.
echo [SETUP] Setting up AWS CLI...
call :aws_cli_setup
) else if "%choice%"=="14" (
echo.
echo [SYNC] Syncing All Resources...
call :sync_resources
) else if "%choice%"=="0" (
echo.
echo [EXIT] Goodbye!
exit /b 0
) else (
echo.
echo [ERROR] Invalid choice! Please enter a number from 0-14.
echo.
pause
goto :menu
)

echo.
echo Press any key to return to menu...
pause >nul
goto :menu

:: Function definitions
:infrastructure_discovery
echo Running AWS infrastructure discovery...
aws ec2 describe-regions --output table
echo.
aws ec2 describe-availability-zones --output table
goto :eof

:cloudformation_info
echo Getting CloudFormation stack information...
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --output table
goto :eof

:terraform_info
echo Analyzing Terraform state...
if exist "terraform.tfstate" (
echo Found terraform.tfstate file
type terraform.tfstate
) else (
echo No terraform.tfstate file found in current directory
)
goto :eof

:ec2_management
echo Managing EC2 instances...
aws ec2 describe-instances --output table
goto :eof

:rds_info
echo Getting RDS database information...
aws rds describe-db-instances --output table
goto :eof

:loadbalancer_info
echo Getting Load Balancer information...
aws elbv2 describe-load-balancers --output table
goto :eof

:security_analysis
echo Analyzing Security Groups...
aws ec2 describe-security-groups --output table
goto :eof

:s3_analysis
echo Analyzing S3 buckets...
aws s3 ls
goto :eof

:lambda_info
echo Getting Lambda function information...
aws lambda list-functions --output table
goto :eof

:cost_analysis
echo Running cost analysis...
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-12-31 --granularity MONTHLY --metrics BlendedCost --output table
goto :eof

:resource_optimization
echo Running resource optimization analysis...
echo Checking for unused resources...
aws ec2 describe-instances --filters "Name=instance-state-name,Values=stopped" --output table
goto :eof

:complete_report
echo Generating complete infrastructure report...
echo ================================================================
echo                    INFRASTRUCTURE REPORT
echo ================================================================
echo.
echo [EC2 Instances]
aws ec2 describe-instances --output table
echo.
echo [RDS Databases]
aws rds describe-db-instances --output table
echo.
echo [S3 Buckets]
aws s3 ls
echo.
echo [Load Balancers]
aws elbv2 describe-load-balancers --output table
echo.
echo ================================================================
goto :eof

:aws_cli_setup
echo Setting up AWS CLI...
aws configure
goto :eof

:sync_resources
echo Syncing all resources...
echo This would sync all AWS resources to local state...
echo Feature not implemented yet.
goto :eof
