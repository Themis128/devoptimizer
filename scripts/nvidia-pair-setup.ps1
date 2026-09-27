<#
.SYNOPSIS
    NVIDIA PAIR (Personal AI Router) Manager for DevOptimizer
.DESCRIPTION
    Manages NVIDIA Personal AI Router based on the REAL architecture (verified
    against docs.nvidia.com/local-ai/nvpair and github.com/NVIDIA/Personal-AI-Router):

      - PAIR installs as an Electron desktop app + user-mode service tree
        (nvpair-cluster-manager, nvpair-engine-manager, ...). There is NO
        config.yaml and NO "pair.exe serve". Settings are managed via the
        desktop app or the terminal UI (`nvpair`, one interface per machine).
      - Proxy endpoints (local router): 127.0.0.1:11434 (Ollama-compatible,
        serves OpenAI-shaped /v1 responses for ALL cluster chat models) and
        127.0.0.1:1234 (LM Studio bridge - routes only to LM Studio models).
        Point clients/Cline at 11434.
      - PAIR bundles its own Ollama engine under
        %LOCALAPPDATA%\Nvidia Corporation\Personal AI Router\engine-bin\ollama
        running on port 11435 (see engines\ollama.json).
      - Data root: %LOCALAPPDATA%\Nvidia Corporation\Personal AI Router\
        (configs\, engines\, cluster\, logs\).
      - PAIR only accepts requests from the local system. To cluster, pair
        nodes on the same trusted network via six-digit PIN (desktop:
        Settings -> Cluster; terminal: Cluster tab). Mixed Windows/Linux/macOS
        clusters are supported. Engines: Ollama and LM Studio only.
      - PAIR routes each request to ONE node; it does NOT pool GPU memory or
        shard models across machines.

    Supported actions: -Status (default), -Install, -PullModels, -Verify, -ConfigureCline
.NOTES
    Install runs the official NVPAIR-Setup-<ver>-x64.exe with /S (silent).
    Pairing PIN entry is interactive by design (security) and cannot be scripted.
#>

param(
    [switch]$Status,
    [switch]$Install,
    [switch]$PullModels,
    [switch]$Verify,
    [switch]$ConfigureCline,
    [string[]]$Models = @('qwen2.5-coder:7b', 'qwen3:4b'),
    [string]$Version = 'latest'
)

$colors = @{ Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; Info = 'Cyan'; Header = 'Magenta' }
function Write-Status { param([string]$m, [string]$t = 'Info') Write-Host $m -ForegroundColor $colors[$t] }
function Write-Header  { param([string]$t) Write-Host "`n=== $t ===" -ForegroundColor $colors.Header }

# --- Constants (verified layout on this machine + upstream docs) ---
$PairDataRoot   = Join-Path $env:LOCALAPPDATA 'Nvidia Corporation\Personal AI Router'
$PairExe        = 'C:\Program Files\PAIR\PAIR.exe'
$EngineOllamaExe= Join-Path $PairDataRoot 'engine-bin\ollama\ollama.exe'
$OllamaRuntime  = 'http://127.0.0.1:11435'   # real engine (engines\ollama.json)
$ProxyOpenAI    = 'http://127.0.0.1:11434'   # Ollama-compat router proxy; OpenAI-shaped /v1, ALL cluster chat models (verified)
$ProxyLmStudio  = 'http://127.0.0.1:1234'    # LM Studio bridge - separate engine only
$ReleasesApi    = 'https://api.github.com/repos/NVIDIA/Personal-AI-Router/releases/latest'
$ClineSettings  = 'D:\DevOptimizer\scripts\cline-settings-nvidia-pair.json'

function Test-Installed {
    $svc = Get-Process | Where-Object { $_.Name -match '^nvpair-' } | Select-Object -ExpandProperty Name -Unique
    $app = Test-Path $PairExe
    [pscustomobject]@{ App = $app; Services = ($svc | Measure-Object).Count; ServiceNames = $svc }
}

function Get-LatestInstallerUrl {
    try {
        $rel = Invoke-RestMethod -Uri $ReleasesApi -TimeoutSec 20
        $asset = $rel.assets | Where-Object { $_.name -match '^NVPAIR-Setup-.+-x64\.exe$' } | Select-Object -First 1
        if ($asset) {
            Write-Status "Latest release: $($rel.tag_name)" -Type Info
            return $asset.browser_download_url
        }
    } catch { Write-Status "Could not query releases API: $_" -Type Warning }
    return $null
}

function Invoke-Install {
    Write-Header 'Installing NVIDIA PAIR (official installer)'
    if (Test-Path $PairExe) { Write-Status 'PAIR already installed at C:\Program Files\PAIR' -Type Success; return }
    $url = Get-LatestInstallerUrl
    if (-not $url) { Write-Status 'No installer URL found - download manually from https://github.com/NVIDIA/Personal-AI-Router/releases' -Type Error; return }
    $tmp = Join-Path $env:TEMP 'NVPAIR-Setup-x64.exe'
    Write-Status "Downloading $url ..." -Type Info
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
    Write-Status 'Running silent install (/S)...' -Type Info
    Start-Process -FilePath $tmp -ArgumentList '/S' -Wait
    if (Test-Path $PairExe) { Write-Status 'PAIR installed. Launch the desktop app (or run: nvpair for the terminal UI) to set up engines/pairing.' -Type Success }
    else { Write-Status 'Install did not produce C:\Program Files\PAIR - check the installer window.' -Type Warning }
}

function Show-Status {
    Write-Header 'NVIDIA PAIR Status'
    $st = Test-Installed
    Write-Status ("Desktop app installed : {0}" -f $st.App) -Type $(if ($st.App) { 'Success' } else { 'Error' })
    Write-Status ("Service processes     : {0}" -f $st.Services) -Type $(if ($st.Services -ge 8) { 'Success' } else { 'Warning' })

    foreach ($p in @(@('Router proxy (all chat models)', $ProxyOpenAI), @('LM Studio bridge', $ProxyLmStudio), @('Ollama engine', $OllamaRuntime))) {
        try {
            $r = Invoke-RestMethod -Uri ($p[1] + '/v1/models') -TimeoutSec 5
            $n = ($r.data | Measure-Object).Count
            Write-Status ("{0,-22}: UP   {1}  ({2} models)" -f $p[0], $p[1], $n) -Type 'Success'
        } catch {
            Write-Status ("{0,-22}: DOWN {1}" -f $p[0], $p[1]) -Type 'Warning'
        }
    }

    if (Test-Path $EngineOllamaExe) {
        Write-Status "`nLocal engine models:" -Type Info
        & $EngineOllamaExe list 2>&1 | ForEach-Object { Write-Status "  $_" -Type Info }
    }

    Write-Status "`nCluster: pair nodes via the desktop app (Settings -> Cluster) or terminal UI (Cluster tab, six-digit PIN)." -Type Info
}

function Invoke-PullModels {
    Write-Header 'Pulling models into PAIR engine'
    if (-not (Test-Path $EngineOllamaExe)) { Write-Status 'Bundled Ollama engine not found - is PAIR installed and run once?' -Type Error; return }
    $env:OLLAMA_HOST = '127.0.0.1:11435'
    foreach ($m in $Models) {
        Write-Status "Pulling $m ..." -Type Info
        & $EngineOllamaExe pull $m 2>&1 | Select-Object -Last 1 | Out-Host
    }
    & $EngineOllamaExe list
}

function Invoke-Verify {
    Write-Header 'Verifying PAIR end-to-end'
    try {
        $r = Invoke-RestMethod -Uri "$ProxyOpenAI/v1/models" -TimeoutSec 10
        Write-Status "Cluster-wide models via ${ProxyOpenAI}:" -Type Success
        $r.data | ForEach-Object { Write-Status "  $($_.id)" -Type Info }
        if (($r.data | Where-Object id -like 'text-embedding*').Count -eq $r.data.Count) {
            Write-Status 'Only embedding models available - pull a chat model (-PullModels).' -Type Warning
        }
    } catch { Write-Status "OpenAI proxy check failed: $_" -Type Error }
    try {
        $body = '{"model":"qwen2.5-coder:7b","messages":[{"role":"user","content":"Reply with: PAIR OK"}],"max_tokens":20}'
        $resp = Invoke-RestMethod -Uri "$ProxyOpenAI/v1/chat/completions" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 180
        Write-Status "Inference test: $($resp.choices[0].message.content)" -Type Success
    } catch { Write-Status "Inference test failed: $_" -Type Warning }
}

function Invoke-ConfigureCline {
    Write-Header 'Configuring Cline for PAIR'
    $dst = Join-Path $env:APPDATA 'Code\User\globalStorage\saoudrizwan.claude-dev\settings'
    if (-not (Test-Path $dst)) { New-Item -Path $dst -ItemType Directory -Force | Out-Null }
    $target = Join-Path $dst 'cline_mcp_settings.json'
    Write-Status "Template: $ClineSettings" -Type Info
    Write-Status "Review and copy settings into Cline. Endpoint: $ProxyOpenAI/v1" -Type Info
    Write-Status "Models: plan=qwen3:4b  act=qwen2.5-coder:7b  (restart VS Code after change)" -Type Info
}

# --- main ---
if (-not ($Install -or $PullModels -or $Verify -or $ConfigureCline)) { $Status = $true }
if ($Install)        { Invoke-Install }
if ($PullModels)     { Invoke-PullModels }
if ($ConfigureCline) { Invoke-ConfigureCline }
if ($Verify)         { Invoke-Verify }
if ($Status)         { Show-Status }
