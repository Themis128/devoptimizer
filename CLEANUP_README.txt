Windows Temporary File Cleanup Guide
====================================

This package contains tools to help you clean temporary files and garbage from your Windows OS.
ALL TOOLS ARE DESIGNED TO BE SAFE - they will show you what will be deleted before deleting anything.

IMPORTANT SAFETY NOTES:
======================
1. These scripts ONLY target known temporary file locations
2. They skip files that are currently in use (to avoid errors)
3. They show you what will be deleted before asking for confirmation
4. NEVER run scripts from untrusted sources - review these scripts first!
5. Consider creating a system restore point before major cleanup

FILES INCLUDED:
===============
1. WindowsTempCleaner.ps1 - PowerShell script (RECOMMENDED)
   - More robust error handling
   - Better file age filtering (skips files <24 hours old)
   - Shows detailed file lists
   - Handles wildcards in paths (like Chrome profile folders)

2. WindowsTempCleaner.bat - Batch file alternative
   - Works without PowerShell execution policy changes
   - Simpler but still safe
   - Good for quick cleanups

3. This README file

HOW TO USE:
===========

OPTION 1: PowerShell Script (Recommended)
-----------------------------------------
1. Right-click WindowsTempCleaner.ps1
2. Select "Run with PowerShell"
   - If you get an execution policy error, you may need to:
     a. Open PowerShell as Administrator
     b. Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
     c. Then run the script again
3. Review what files will be deleted
4. Type 'y' to confirm deletion for each location
5. Type 'all' to delete all remaining locations without further prompts

OPTION 2: Batch File
--------------------
1. Double-click WindowsTempCleaner.bat
2. Review what files will be deleted at each location
3. Type 'y' to confirm deletion
4. Follow the prompts

ALTERNATIVE METHODS:
===================
- Windows Built-in Disk Cleanup:
  * Press Win + S, type "Disk Cleanup", open it
  * Select your system drive (usually C:)
  * Check: Temporary files, Recycle Bin, Thumbnails, etc.
  * Click OK -> Delete Files

- Storage Sense (Windows 10/11):
  * Settings -> System -> Storage
  * Turn on Storage Sense
  * Configure automatic cleanup

LOCATIONS CLEANED:
==================
- User Temp Folder (%TEMP%)
- Windows Temp Folder (C:\Windows\Temp)
- Internet Cache
- Web Cache
- Local AppData Temp
- Browser Caches (Chrome, Firefox, Edge - if installed)
- Recycle Bin (via manual confirmation)

WHAT IS NOT TOUCHED:
====================
- Personal files (Documents, Pictures, etc.)
- Installed programs
- System files (except temp files in Windows\Temp)
- Recently used files (<24 hours old by default)
- Windows installation files
- Drivers

TROUBLESHOOTING:
================
- "Access denied" errors: File is likely in use - skip it
- PowerShell execution errors: See OPTION 1 step 2 above
- No files found: Either no temp files or all are currently in use

MAINTENANCE SCHEDULE:
=====================
- Light cleanup: Weekly (using Storage Sense or monthly manual)
- Deep cleanup: Monthly (after major updates or software installations)
- After major Windows updates: Run Disk Cleanup -> "Clean up system files"

DISCLAIMER:
===========
These scripts are provided as-is. While designed to be safe, always:
1. Review scripts before running
2. Close applications before cleaning
3. Skip files that fail to delete (they're likely in use)
4. Keep backups of important data

Created for: Windows OS Temporary File Cleanup
Location: D:\DevOptimizer\ (review scripts here before running on your system)