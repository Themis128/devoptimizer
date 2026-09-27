@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
:: Windows Temporary File Cleaner Batch Version
:: Review this script carefully before running!
:: It will clean temp files from safe locations only

echo =================================================
echo Windows Temporary File Cleaner (Batch Version)
echo =================================================
echo.
echo This script will clean temporary files from known safe locations.
echo Review the script before running - it shows what will be deleted.
echo.

:: Initialize counters
set /a totalDeleted=0
set /a totalSize=0

:: Function to get readable size (simplified for batch)
:: We'll just show KB/MB approximation

echo Scanning for temporary files...
echo.

:: Define temp locations to clean
set "TEMP_LOCATIONS=%TEMP% %WINDIR%\Temp %LOCALAPPDATA%\Microsoft\Windows\INetCache %LOCALAPPDATA%\Microsoft\Windows\WebCache %LOCALAPPDATA%\Temp"

:: Process each location
for %%L in (%TEMP_LOCATIONS%) do (
if exist "%%L" (
echo Checking: %%L
echo.

:: Get list of files older than 1 day (to avoid in-use files)
:: Using forfiles to find files older than 1 day
forfiles /p "%%L" /s /m *.* /d -1 /c "cmd /c echo @path @fsize" 2>nul | (
set fileCount=0
set totalBytes=0
set "fileList="
while read line do (
set /a fileCount+=1
for /f "tokens=1*" %%A in ("!line!") do (
set "filePath=%%A"
set fileSize=%%B
set /a totalSizeBytes+=!fileSize!
)
)

if !fileCount! gtr 0 (
echo Found !fileCount! files totaling !totalSizeBytes! bytes (~ !totalSizeBytes/1024! KB)
echo.
set /p answer=Delete these files? (y/n):
if /i "!answer!"=="y" (
forfiles /p "%%L" /s /m *.* /d -1 /c "cmd /c del @path" 2>nul
echo Deleted !fileCount! files.
set /a totalDeleted+=!fileCount!
)
) else (
echo No old files found.
)
)
echo.
)
)

:: Browser cleanup (simplified - just Chrome for example)
if exist "%LOCALAPPDATA%\Google\Chrome\User Data\*" (
echo Checking Chrome Cache...
for /d %%C in ("%LOCALAPPDATA%\Google\Chrome\User Data\*") do (
if exist "%%C\Cache" (
echo Found Chrome Cache in %%C\Cache
set /p answer=Delete Chrome cache? (y/n):
if /i "!answer!"=="y" (
rmdir /s /q "%%C\Cache" 2>nul
echo Chrome cache deleted.
)
)
)
echo.
)

:: Recycle Bin emptying
echo.
echo To empty Recycle Bin, you can use:
echo   PowerShell:  (New-Object -ComObject Shell.Application).Namespace(0xA).Items() | ForEach-Object { $_.Delete() }
echo   Or right-click Recycle Bin -> Empty Recycle Bin
echo.

:: Summary (approximate)
echo =================================================
echo Cleanup Complete!
echo Approximate files processed: %totalDeleted%
echo =================================================
pause
exit /b %ERRORLEVEL%
