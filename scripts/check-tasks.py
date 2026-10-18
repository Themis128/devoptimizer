# Safe version of check-tasks.py - no command injection vulnerabilities
import subprocess
import json
import sys
import re

def get_scheduled_tasks():
    """Get scheduled tasks in the DevOptimizer path."""
    try:
        # Fixed command with no user input
        result = subprocess.run(
            ['powershell', '-Command', 
             "Get-ScheduledTask -TaskPath '\\DevOptimizer\\' -ErrorAction SilentlyContinue | ConvertTo-JSON -Depth 3"],
            capture_output=True, text=True, check=False, timeout=30
        )
        
        if result.returncode != 0:
            return []
        
        if result.stdout.strip():
            tasks = json.loads(result.stdout)
            if isinstance(tasks, dict):
                tasks = [tasks]
            return tasks
        return []
    except (json.JSONDecodeError, subprocess.TimeoutExpired):
        return []
    except Exception:
        return []

def get_task_info(task_name):
    """Get info for a specific scheduled task with strict validation."""
    # Strict validation: only allow safe characters in task names
    if not task_name or not isinstance(task_name, str):
        return {}
    
    # Allow only alphanumeric, spaces, underscores, hyphens, periods
    # Also limit length to prevent DoS
    if not re.match(r'^[a-zA-Z0-9\s_\-\.]{1,100}$', task_name):
        return {}
    
    try:
        # Use parameterized approach - task name as argument to script block
        result = subprocess.run(
            [
                'powershell', 
                '-Command',
                "& { param($name) if ($name) { Get-ScheduledTaskInfo -TaskName $name | ConvertTo-JSON -Depth 3 } }",
                task_name
            ],
            capture_output=True, text=True, check=False, timeout=30
        )
        
        if result.returncode != 0 or not result.stdout.strip():
            return {}
            
        return json.loads(result.stdout)
    except (json.JSONDecodeError, subprocess.TimeoutExpired):
        return {}
    except Exception:
        return {}

def main():
    """Display scheduled tasks in a table format."""
    tasks = get_scheduled_tasks()
    
    if not tasks:
        print("No scheduled tasks found in DevOptimizer path.")
        return
    
    results = []
    for task in tasks:
        task_name = task.get('TaskName', '')
        if not task_name:
            continue
            
        info = get_task_info(task_name)
        
        results.append({
            'TaskName': task_name,
            'NextRunTime': info.get('NextRunTime', 'N/A'),
            'LastRunTime': info.get('LastRunTime', 'N/A'),
            'LastTaskResult': info.get('LastTaskResult', 'N/A')
        })
    
    if results:
        print(f"{'TaskName':<30} {'NextRunTime':<25} {'LastRunTime':<25} {'LastTaskResult':<15}")
        print("-" * 100)
        for r in results:
            print(f"{r['TaskName']:<30} {r['NextRunTime']:<25} {r['LastRunTime']:<25} {r['LastTaskResult']:<15}")
    else:
        print("No task information available.")

if __name__ == "__main__":
    main()