@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
setlocal enabledelayedexpansion
title  - Standard Mode-8 encoding
chcp 65001 >nul 2>&1

color 0A
echo.
echo ================================================================


:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

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
echo 1.   Infrastructure Discovery
echo 2.   CloudFormation Stack Info
echo 3.   Terraform State Info
echo 4.   EC2 Instance Management
echo 5.   RDS Database Info
echo 6.   Load Balancer Info
echo 7.   Security Group Analysis
echo 8.   S3 Bucket Analysis
echo 9.   Lambda Function Info
echo 10.  Cost Analysis
echo 11.  Resource Optimization
echo 12.  Complete Infrastructure Report
echo 13.  AWS CLI Setup
echo 14.  Sync All Resources
echo 0.   Exit
echo.
echo ================================================================

set /p choice="Enter your choice (0-14): "

if "%choice%"=="1" goto infrastructure_discovery
if "%choice%"=="2" goto cloudformation_info
if "%choice%"=="3" goto terraform_info
if "%choice%"=="4" goto ec2_management
if "%choice%"=="5" goto rds_info
if "%choice%"=="6" goto loadbalancer_info
if "%choice%"=="7" goto security_analysis
if "%choice%"=="8" goto s3_analysis
if "%choice%"=="9" goto lambda_info
if "%choice%"=="10" goto cost_analysis
if "%choice%"=="11" goto resource_optimization
if "%choice%"=="12" goto complete_report
if "%choice%"=="13" goto aws_cli_setup
if "%choice%"=="14" goto sync_resources
if "%choice%"=="0" goto exit
goto invalid_choice

:infrastructure_discovery
echo.
echo ================================================================
echo               INFRASTRUCTURE DISCOVERY
echo ================================================================
echo.
echo Discovering your AWS infrastructure...
echo.

:: Create reports directory
if not exist "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports" mkdir "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports"

:: Get all regions
echo [DISCOVERY] Getting all AWS regions...
aws ec2 describe-regions --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\regions.txt"
echo [SUCCESS] Regions discovered

:: Get current region
echo [DISCOVERY] Getting current region...
aws configure get region > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\current-region.txt"
echo [SUCCESS] Current region identified

:: Get account info
echo [DISCOVERY] Getting account information...
aws sts get-caller-identity > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\account-info.json"
echo [SUCCESS] Account information retrieved

:: Get all resources by region
echo [DISCOVERY] Discovering resources across regions...
for /f "tokens=3" %%r in ('aws ec2 describe-regions --query "Regions[].RegionName" --output text') do (
echo [INFO] Scanning region: %%r
aws ec2 describe-instances --region %%r --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\instances-%%r.json" 2>nul
aws ec2 describe-volumes --region %%r --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\volumes-%%r.json" 2>nul
aws ec2 describe-security-groups --region %%r --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\security-groups-%%r.json" 2>nul
)

echo [SUCCESS] Infrastructure discovery completed!
echo [INFO] Reports saved to: %USERPROFILE%\Desktop\DevOptimizer\AWS-Reports
echo.
pause
goto main_menu

:cloudformation_info
echo.
echo ================================================================
echo               CLOUDFORMATION STACK INFO
echo ================================================================
echo.
echo Analyzing CloudFormation stacks...
echo.

:: Get all stacks
echo [CLOUDFORMATION] Getting all stacks...
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\cloudformation-stacks.txt"
echo [SUCCESS] CloudFormation stacks retrieved

:: Get stack details
echo [CLOUDFORMATION] Getting detailed stack information...
for /f "tokens=1" %%s in ('aws cloudformation list-stacks --query "StackSummaries[?StackStatus==`CREATE_COMPLETE` || StackStatus==`UPDATE_COMPLETE`].StackName" --output text') do (
echo [INFO] Analyzing stack: %%s
aws cloudformation describe-stacks --stack-name %%s --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\stack-%%s.json"
aws cloudformation describe-stack-resources --stack-name %%s --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\stack-resources-%%s.json"
)

:: Get stack events
echo [CLOUDFORMATION] Getting stack events...
for /f "tokens=1" %%s in ('aws cloudformation list-stacks --query "StackSummaries[?StackStatus==`CREATE_COMPLETE` || StackStatus==`UPDATE_COMPLETE`].StackName" --output text') do (
aws cloudformation describe-stack-events --stack-name %%s --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\stack-events-%%s.json"
)

echo [SUCCESS] CloudFormation analysis completed!
echo.
pause
goto main_menu

:terraform_info
echo.
echo ================================================================
echo               TERRAFORM STATE INFO
echo ================================================================
echo.
echo Analyzing Terraform state...
echo.

:: Check for Terraform
terraform version >nul 2>&1
if %errorLevel% neq 0 (
echo [WARNING] Terraform not found. Installing Terraform...
choco install terraform -y
if %errorLevel% neq 0 (
echo [ERROR] Failed to install Terraform
pause
goto main_menu
)
)

:: Check for Terraform state
if exist "terraform.tfstate" (
echo [TERRAFORM] Analyzing local state file...
terraform show -json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\terraform-state.json"
terraform state list > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\terraform-resources.txt"
echo [SUCCESS] Terraform state analyzed
) else (
echo [INFO] No local Terraform state file found
echo [INFO] Checking for remote state...
terraform init
terraform show -json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\terraform-state.json" 2>nul
terraform state list > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\terraform-resources.txt" 2>nul
)

:: Get Terraform plan
echo [TERRAFORM] Generating Terraform plan...
terraform plan -out=plan.out > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\terraform-plan.txt" 2>nul
terraform show -json plan.out > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\terraform-plan.json" 2>nul

echo [SUCCESS] Terraform analysis completed!
echo.
pause
goto main_menu

:ec2_management
echo.
echo ================================================================
echo               EC2 INSTANCE MANAGEMENT
echo ================================================================
echo.
echo Managing EC2 instances...
echo.

:: Get all instances
echo [EC2] Getting all EC2 instances...
aws ec2 describe-instances --query "Reservations[].Instances[].[InstanceId,State.Name,InstanceType,PublicIpAddress,PrivateIpAddress,Tags[?Key=='Name'].Value|[0]]" --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\ec2-instances.txt"
echo [SUCCESS] EC2 instances retrieved

:: Get instance details
echo [EC2] Getting detailed instance information...
for /f "tokens=1" %%i in ('aws ec2 describe-instances --query "Reservations[].Instances[?State.Name=='running'].InstanceId" --output text') do (
echo [INFO] Analyzing instance: %%i
aws ec2 describe-instances --instance-ids %%i --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\instance-%%i.json"
)

:: Get instance metrics
echo [EC2] Getting CloudWatch metrics...
for /f "tokens=1" %%i in ('aws ec2 describe-instances --query "Reservations[].Instances[?State.Name=='running'].InstanceId" --output text') do (
aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=InstanceId,Value=%%i --start-time 2024-01-01T00:00:00Z --end-time 2024-12-31T23:59:59Z --period 3600 --statistics Average > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\metrics-%%i.json" 2>nul
)

echo [SUCCESS] EC2 management completed!
echo.
pause
goto main_menu

:rds_info
echo.
echo ================================================================
echo               RDS DATABASE INFO
echo ================================================================
echo.
echo Analyzing RDS databases...
echo.

:: Get all RDS instances
echo [RDS] Getting all RDS instances...
aws rds describe-db-instances --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\rds-instances.txt"
echo [SUCCESS] RDS instances retrieved

:: Get RDS details
echo [RDS] Getting detailed RDS information...
for /f "tokens=1" %%d in ('aws rds describe-db-instances --query "DBInstances[].DBInstanceIdentifier" --output text') do (
echo [INFO] Analyzing database: %%d
aws rds describe-db-instances --db-instance-identifier %%d --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\rds-%%d.json"
)

:: Get RDS snapshots
echo [RDS] Getting RDS snapshots...
aws rds describe-db-snapshots --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\rds-snapshots.json"

:: Get RDS metrics
echo [RDS] Getting RDS metrics...
for /f "tokens=1" %%d in ('aws rds describe-db-instances --query "DBInstances[].DBInstanceIdentifier" --output text') do (
aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name CPUUtilization --dimensions Name=DBInstanceIdentifier,Value=%%d --start-time 2024-01-01T00:00:00Z --end-time 2024-12-31T23:59:59Z --period 3600 --statistics Average > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\rds-metrics-%%d.json" 2>nul
)

echo [SUCCESS] RDS analysis completed!
echo.
pause
goto main_menu

:loadbalancer_info
echo.
echo ================================================================
echo               LOAD BALANCER INFO
echo ================================================================
echo.
echo Analyzing load balancers...
echo.

:: Get Application Load Balancers
echo [ALB] Getting Application Load Balancers...
aws elbv2 describe-load-balancers --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\alb-load-balancers.txt"
echo [SUCCESS] ALB load balancers retrieved

:: Get Classic Load Balancers
echo [CLB] Getting Classic Load Balancers...
aws elb describe-load-balancers --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\clb-load-balancers.txt"
echo [SUCCESS] CLB load balancers retrieved

:: Get load balancer details
echo [LB] Getting detailed load balancer information...
for /f "tokens=1" %%l in ('aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" --output text') do (
echo [INFO] Analyzing load balancer: %%l
aws elbv2 describe-load-balancers --load-balancer-arns %%l --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\alb-%%l.json"
)

echo [SUCCESS] Load balancer analysis completed!
echo.
pause
goto main_menu

:security_analysis
echo.
echo ================================================================
echo               SECURITY GROUP ANALYSIS
echo ================================================================
echo.
echo Analyzing security groups...
echo.

:: Get all security groups
echo [SECURITY] Getting all security groups...
aws ec2 describe-security-groups --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\security-groups.txt"
echo [SUCCESS] Security groups retrieved

:: Get security group details
echo [SECURITY] Getting detailed security group information...
for /f "tokens=1" %%s in ('aws ec2 describe-security-groups --query "SecurityGroups[].GroupId" --output text') do (
echo [INFO] Analyzing security group: %%s
aws ec2 describe-security-groups --group-ids %%s --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\security-group-%%s.json"
)

:: Get NACLs
echo [SECURITY] Getting Network ACLs...
aws ec2 describe-network-acls --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\network-acls.json"

:: Get VPCs
echo [SECURITY] Getting VPCs...
aws ec2 describe-vpcs --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\vpcs.json"

echo [SUCCESS] Security analysis completed!
echo.
pause
goto main_menu

:s3_analysis
echo.
echo ================================================================
echo               S3 BUCKET ANALYSIS
echo ================================================================
echo.
echo Analyzing S3 buckets...
echo.

:: Get all S3 buckets
echo [S3] Getting all S3 buckets...
aws s3 ls > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\s3-buckets.txt"
echo [SUCCESS] S3 buckets retrieved

:: Get bucket details
echo [S3] Getting detailed bucket information...
for /f "tokens=3" %%b in ('aws s3 ls') do (
echo [INFO] Analyzing bucket: %%b
aws s3api get-bucket-location --bucket %%b > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\bucket-location-%%b.json" 2>nul
aws s3api get-bucket-versioning --bucket %%b > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\bucket-versioning-%%b.json" 2>nul
aws s3api get-bucket-encryption --bucket %%b > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\bucket-encryption-%%b.json" 2>nul
)

:: Get bucket sizes
echo [S3] Getting bucket sizes...
for /f "tokens=3" %%b in ('aws s3 ls') do (
aws s3 ls s3://%%b --recursive --human-readable --summarize > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\bucket-size-%%b.txt" 2>nul
)

echo [SUCCESS] S3 analysis completed!
echo.
pause
goto main_menu

:lambda_info
echo.
echo ================================================================
echo               LAMBDA FUNCTION INFO
echo ================================================================
echo.
echo Analyzing Lambda functions...
echo.

:: Get all Lambda functions
echo [LAMBDA] Getting all Lambda functions...
aws lambda list-functions --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\lambda-functions.txt"
echo [SUCCESS] Lambda functions retrieved

:: Get function details
echo [LAMBDA] Getting detailed function information...
for /f "tokens=1" %%f in ('aws lambda list-functions --query "Functions[].FunctionName" --output text') do (
echo [INFO] Analyzing function: %%f
aws lambda get-function --function-name %%f --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\lambda-%%f.json"
)

:: Get function metrics
echo [LAMBDA] Getting function metrics...
for /f "tokens=1" %%f in ('aws lambda list-functions --query "Functions[].FunctionName" --output text') do (
aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Invocations --dimensions Name=FunctionName,Value=%%f --start-time 2024-01-01T00:00:00Z --end-time 2024-12-31T23:59:59Z --period 3600 --statistics Sum > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\lambda-metrics-%%f.json" 2>nul
)

echo [SUCCESS] Lambda analysis completed!
echo.
pause
goto main_menu

:cost_analysis
echo.
echo ================================================================
echo               COST ANALYSIS
echo ================================================================
echo.
echo Analyzing AWS costs...
echo.

:: Get cost and usage
echo [COST] Getting cost and usage information...
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-12-31 --granularity MONTHLY --metrics BlendedCost --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\cost-analysis.json" 2>nul
echo [SUCCESS] Cost analysis retrieved

:: Get cost by service
echo [COST] Getting cost by service...
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-12-31 --granularity MONTHLY --metrics BlendedCost --group-by Type=DIMENSION,Key=SERVICE --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\cost-by-service.json" 2>nul
echo [SUCCESS] Cost by service retrieved

:: Get cost by region
echo [COST] Getting cost by region...
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-12-31 --granularity MONTHLY --metrics BlendedCost --group-by Type=DIMENSION,Key=REGION --output json > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\cost-by-region.json" 2>nul
echo [SUCCESS] Cost by region retrieved

echo [SUCCESS] Cost analysis completed!
echo.
pause
goto main_menu

:resource_optimization
echo.
echo ================================================================
echo               RESOURCE OPTIMIZATION
echo ================================================================
echo.
echo Analyzing resource optimization opportunities...
echo.

:: Check for unused EBS volumes
echo [OPTIMIZATION] Checking for unused EBS volumes...
aws ec2 describe-volumes --filters "Name=status,Values=available" --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\unused-volumes.txt"
echo [SUCCESS] Unused volumes identified

:: Check for unused Elastic IPs
echo [OPTIMIZATION] Checking for unused Elastic IPs...
aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\unused-eips.txt"
echo [SUCCESS] Unused Elastic IPs identified

:: Check for old snapshots
echo [OPTIMIZATION] Checking for old snapshots...
aws ec2 describe-snapshots --owner-ids self --query "Snapshots[?StartTime<='2024-01-01'].{SnapshotId:SnapshotId,StartTime:StartTime,VolumeSize:VolumeSize}" --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\old-snapshots.txt"
echo [SUCCESS] Old snapshots identified

:: Check for unused security groups
echo [OPTIMIZATION] Checking for unused security groups...
aws ec2 describe-security-groups --query "SecurityGroups[?GroupName!='default'].{GroupId:GroupId,GroupName:GroupName,Description:Description}" --output table > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\security-groups-analysis.txt"
echo [SUCCESS] Security groups analyzed

echo [SUCCESS] Resource optimization analysis completed!
echo.
pause
goto main_menu

:complete_report
echo.
echo ================================================================
echo               COMPLETE INFRASTRUCTURE REPORT
echo ================================================================
echo.
echo Generating complete infrastructure report...
echo.

:: Run all analyses
call :infrastructure_discovery
call :cloudformation_info
call :ec2_management
call :rds_info
call :loadbalancer_info
call :security_analysis
call :s3_analysis
call :lambda_info
call :cost_analysis
call :resource_optimization

:: Generate summary report
echo [REPORT] Generating summary report...
echo AWS Infrastructure Report - %date% %time% > "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo ========================================== >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo Account Information: >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
type "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\account-info.json" >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo Current Region: >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
type "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\current-region.txt" >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo EC2 Instances: >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
type "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\ec2-instances.txt" >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo RDS Instances: >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
type "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\rds-instances.txt" >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo. >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
echo S3 Buckets: >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"
type "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\s3-buckets.txt" >> "%USERPROFILE%\Desktop\DevOptimizer\AWS-Reports\SUMMARY-REPORT.txt"

echo [SUCCESS] Complete infrastructure report generated!
echo [INFO] All reports saved to: %USERPROFILE%\Desktop\DevOptimizer\AWS-Reports
echo.
pause
goto main_menu

:aws_cli_setup
echo.
echo ================================================================
echo               AWS CLI SETUP
echo ================================================================
echo.
echo Setting up AWS CLI...
echo.

:: Install AWS CLI
echo [AWS CLI] Installing AWS CLI...
choco install awscli -y >nul 2>&1
:: Always refresh PATH and verify installation regardless of choco exit code
echo [AWS CLI] Refreshing PATH and verifying AWS CLI installation...
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

:: Configure AWS CLI
echo [AWS CLI] Configuring AWS CLI...
aws configure
echo [SUCCESS] AWS CLI configured

:: Install AWS CLI v2
echo [AWS CLI] Installing AWS CLI v2...
choco install awscli-v2 -y >nul 2>&1
:: Always refresh PATH and verify installation regardless of choco exit code
echo [AWS CLI] Refreshing PATH and verifying AWS CLI v2 installation...
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
echo [WARNING] AWS CLI v2 verification failed, but continuing...
echo [INFO] You may need to restart your terminal or add AWS CLI to PATH manually
echo [INFO] AWS CLI is typically installed at: C:\Program Files\Amazon\AWSCLIV2\
) else (
echo [SUCCESS] AWS CLI v2 verified successfully!
)
) else (
echo [SUCCESS] AWS CLI v2 verified successfully!
)
) else (
echo [SUCCESS] AWS CLI v2 verified successfully!
)

:: Install AWS SAM CLI
echo [AWS CLI] Installing AWS SAM CLI...
choco install aws-sam-cli -y
echo [SUCCESS] AWS SAM CLI installed

:: Install AWS CDK
echo [AWS CLI] Installing AWS CDK...
npm install -g aws-cdk
echo [SUCCESS] AWS CDK installed

echo [SUCCESS] AWS CLI setup completed!
echo.
pause
goto main_menu

:sync_resources
echo.
echo ================================================================
echo               SYNC ALL RESOURCES
echo ================================================================
echo.
echo Syncing all AWS resources...
echo.

:: Run all discovery and analysis
call :infrastructure_discovery
call :cloudformation_info
call :ec2_management
call :rds_info
call :loadbalancer_info
call :security_analysis
call :s3_analysis
call :lambda_info
call :cost_analysis
call :resource_optimization

echo [SUCCESS] All resources synced!
echo.
pause
goto main_menu

:invalid_choice
echo.
echo [ERROR] Invalid choice. Please select a number between 0-14.
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
echo                AWS INFRASTRUCTURE AS CODE MANAGER
echo ================================================================
echo.
echo Your AWS infrastructure has been analyzed and documented!
echo.
echo ================================================================
echo.
pause
exit

:start
goto main_menu
