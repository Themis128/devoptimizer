@echo off
cd /d "%~dp0"
"C:\Program Files\Python312\python.exe" "C:\Users\tbaltzakis\AppData\Roaming\devin\skills\gmail-send-ops\scripts\gmail-schedule-reply.py" --send --state "D:\DevOptimizer\synigoros-followup\ombudsman-followup-state.json" >> "D:\DevOptimizer\synigoros-followup\ombudsman-followup-state.log" 2>&1
