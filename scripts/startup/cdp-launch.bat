@echo off
rem Debug-CDP lane: headless chrome (loopback:9330) + userspace relay (0.0.0.0:9229).
rem No taskkill — headless + dedicated profile coexists with the user's chrome.
rem chrome-debug-profile keeps its LinkedIn/session cookies between runs.
netstat -ano | findstr /R "LISTENING.*:9330" >nul
if errorlevel 1 (
  start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" ^
    --headless=new --remote-debugging-port=9330 --remote-allow-origins=* ^
    --user-data-dir="C:\Users\tbaltzakis\chrome-debug-profile" about:blank
)
netstat -ano | findstr /R "LISTENING.*:9229" >nul
if errorlevel 1 (
  start "" /min pythonw "C:\Users\tbaltzakis\devin-scripts\cdp_relay.py"
)
