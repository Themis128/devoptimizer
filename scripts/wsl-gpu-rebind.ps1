# wsl-gpu-rebind.ps1 - bounce WSL to rebind the GPU-P channel after an
# NVIDIA driver install/hot-swap left the VM with "GPU access blocked by
# the operating system" (dmesg: dxgvmb_send_create_process failed -75).
#
# Runs Windows-side so it survives the WSL death. After the bounce it
# prewarms the distro and runs the in-VM verify script, which recreates
# ComfyUI if torch still reports cuda=False.
#
# Usage (on demand):   powershell -File wsl-gpu-rebind.ps1
# Or via the task:     Start-ScheduledTask 'DevOptimizer\WSL-GPU-Rebind'

$ErrorActionPreference = 'Continue'
$log = 'D:\DevOptimizer\logs\wsl-gpu-rebind.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null

function Log($m) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    Add-Content -Path $log -Value $line
    Write-Host $line
}

Log '=== WSL GPU rebind starting ==='

# 1. Shut the utility VM down - kills every WSL session and container.
Log 'wsl --shutdown'
& wsl.exe --shutdown 2>&1 | ForEach-Object { Log $_ }
Start-Sleep -Seconds 15

# 2. Prewarm the distro (same call the WSL-PreWarm task uses).
Log 'prewarming Ubuntu-24.04'
& wsl.exe -d Ubuntu-24.04 --exec true 2>&1 | ForEach-Object { Log $_ }
Start-Sleep -Seconds 10

# 3. Docker Desktop needs a moment to re-attach its WSL backend, then run
#    the in-VM verifier (nvidia-smi + comfyui torch.cuda + recreate).
Log 'running in-VM gpu verify'
& wsl.exe -d Ubuntu-24.04 -e bash /home/tbaltzakis/cu130-slim/.devin/skills/windows-host-ops/scripts/wsl-gpu-verify.sh 2>&1 |
    ForEach-Object { Log $_ }

Log '=== WSL GPU rebind finished ==='
