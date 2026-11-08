MANUAL SYSTEM TASK CREATION INSTRUCTIONS
========================================

The Admin-Cleanup-System task MUST be created manually via Task Scheduler GUI
because registering SYSTEM tasks requires actual SYSTEM context.

STEPS:
1. Open Task Scheduler (taskschd.msc) AS ADMINISTRATOR:
   - Press Win+R, type "taskschd.msc", press Ctrl+Shift+Enter

2. Navigate to: Task Scheduler Library → DevOptimizer

3. Right-click → Create Task...

4. General tab:
   - Name: "Admin-Cleanup-System"
   - Description: "Admin cleanup suite run as SYSTEM - DISM, update caches, shadow-copy pruning, DO cache"
   - Security options:
     * Select "Run whether user is logged on or not"
     * Click "Change User or Group..."
     * Type "SYSTEM", click Check Names, OK
     * Check "Run with highest privileges"
     * Configure for: Windows 10/11

5. Triggers tab:
   - New...
   - Begin the task: On a schedule
   - Settings: Weekly, Sunday, Start: 03:00:00
   - Enabled: Yes
   - OK

6. Actions tab:
   - New...
   - Action: Start a program
   - Program/script: pwsh.exe
   - Add arguments: -NoProfile -ExecutionPolicy Bypass -File "D:\DevOptimizer\scripts\admin-cleanup-system.ps1"
   - Start in: D:\DevOptimizer\scripts
   - OK

7. Conditions tab:
   - Uncheck "Start the task only if the computer is on AC power"
   - Uncheck "Stop if the computer switches to battery power"
   - OK

8. Settings tab:
   - Check "Allow task to be run on demand"
   - Check "Run task as soon as possible after a scheduled start is missed"
   - Check "If the task fails, restart every: 1 hour" (or leave unchecked)
   - Check "Stop the task if it runs longer than: 72 hours"
   - If the task is already running: "Do not start a new instance"
   - OK

9. Enter your admin password when prompted (for "Run whether user is logged on or not")

VERIFICATION:
After creation, run in PowerShell:
  Get-ScheduledTask -TaskName 'Admin-Cleanup-System' -TaskPath '\DevOptimizer\' | Format-Table TaskName, UserId, RunLevel

Expected output:
TaskName              UserId  RunLevel
--------              ------  --------
Admin-Cleanup-System  SYSTEM  Highest

TO TEST RUN:
Right-click task → Run
Check log: D:\DevOptimizer\logs\admin-cleanup-system.log