<#
.SYNOPSIS
    DevOptimizer automation script: nuxt3-optimization.
.DESCRIPTION
    DevOptimizer automation script: nuxt3-optimization.
#>

# Nuxt 3 Optimization Functions - Latest 2024/2025 Best Practices

function Get-Nuxt3Environment {
    Write-Log "Analyzing Nuxt 3 development environment..." -Level "INFO"
    
    try {
        $nuxtEnv = @{
            NodeJS = @{
                Installed = $false
                Version = $null
                Path = $null
                LTS = $false
            }
            PackageManagers = @{
                npm = @{ Installed = $false; Version = $null }
                pnpm = @{ Installed = $false; Version = $null }
                yarn = @{ Installed = $false; Version = $null }
                bun = @{ Installed = $false; Version = $null }
            }
            Nuxt = @{
                GlobalInstalled = $false
                Version = $null
                CLI = $null
            }
            WSL = @{
                Installed = $false
                Distributions = @()
                DefaultDistro = $null
            }
            Git = @{
                Installed = $false
                Version = $null
                Config = @{}
            }
            VSCode = @{
                Installed = $false
                Extensions = @()
            }
            System = @{
                RAM = $script:Config.Performance.MaxMemoryUsage
                CPUCores = $script:Config.Performance.CPUCores
                SSDDrive = $false
            }
        }
        
        # Check Node.js
        try {
            $nodeVersion = node --version 2>&1
            if ($nodeVersion -match "v(\d+\.\d+\.\d+)") {
                $nuxtEnv.NodeJS.Installed = $true
                $nuxtEnv.NodeJS.Version = $matches[1]
                $nuxtEnv.NodeJS.Path = (Get-Command node -ErrorAction SilentlyContinue).Source
                
                # Check if it's LTS (even major versions)
                $majorVersion = [int]($matches[1].Split('.')[0])
                $nuxtEnv.NodeJS.LTS = ($majorVersion % 2 -eq 0)
            }
        } catch {
            Write-Log "Node.js not found or not accessible" -Level "WARN"
        }
        
        # Check package managers
        $packageManagers = @("npm", "pnpm", "yarn", "bun")
        foreach ($pm in $packageManagers) {
            try {
                $version = & $pm --version 2>&1
                if ($version -and $version -match "\d+\.\d+\.\d+") {
                    $nuxtEnv.PackageManagers.$pm.Installed = $true
                    $nuxtEnv.PackageManagers.$pm.Version = $version.Trim()
                }
            } catch {
                # Package manager not installed
            }
        }
        
        # Check Nuxt CLI
        try {
            $nuxtVersion = npx nuxi --version 2>&1
            if ($nuxtVersion -match "(\d+\.\d+\.\d+)") {
                $nuxtEnv.Nuxt.GlobalInstalled = $true
                $nuxtEnv.Nuxt.Version = $matches[1]
                $nuxtEnv.Nuxt.CLI = "nuxi"
            }
        } catch {
            Write-Log "Nuxt CLI not found" -Level "WARN"
        }
        
        # Check WSL
        try {
            $wslList = wsl --list --quiet 2>&1
            if ($wslList -and $wslList.Count -gt 0) {
                $nuxtEnv.WSL.Installed = $true
                $nuxtEnv.WSL.Distributions = $wslList | Where-Object { $_ -and $_.Trim() -ne "" }
                
                # Get default distribution
                $wslDefault = wsl --list --verbose 2>&1 | Where-Object { $_ -match "\*" }
                if ($wslDefault) {
                    $nuxtEnv.WSL.DefaultDistro = ($wslDefault -split "\s+")[1]
                }
            }
        } catch {
            Write-Log "WSL not available" -Level "INFO"
        }
        
        # Check Git
        try {
            $gitVersion = git --version 2>&1
            if ($gitVersion -match "git version (\d+\.\d+\.\d+)") {
                $nuxtEnv.Git.Installed = $true
                $nuxtEnv.Git.Version = $matches[1]
                
                # Get Git config
                try {
                    $gitUser = git config --global user.name 2>&1
                    $gitEmail = git config --global user.email 2>&1
                    $nuxtEnv.Git.Config = @{
                        Name = if ($gitUser -and $gitUser -notmatch "error") { $gitUser } else { $null }
                        Email = if ($gitEmail -and $gitEmail -notmatch "error") { $gitEmail } else { $null }
                    }
                } catch {
                    # Git config not set
                }
            }
        } catch {
            Write-Log "Git not found" -Level "WARN"
        }
        
        # Check VS Code extensions
        if (Get-Command code -ErrorAction SilentlyContinue) {
            $nuxtEnv.VSCode.Installed = $true
            try {
                $extensions = code --list-extensions 2>&1
                $nuxtEnv.VSCode.Extensions = $extensions | Where-Object { $_ -and $_.Trim() -ne "" }
            } catch {
                # Extensions list failed
            }
        }
        
        # Check for SSD
        try {
            $drives = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" }
            $nuxtEnv.System.SSDDrive = ($drives.Count -gt 0)
        } catch {
            # Could not determine drive type
        }
        
        Write-Log "Environment analysis completed" -Level "SUCCESS"
        return $nuxtEnv
    }
    catch {
        Write-Log "Error analyzing Nuxt 3 environment: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Optimize-Nuxt3Windows {
    param(
        [ValidateSet("Development", "Production", "Performance", "Full-Stack")]
        [string]$Profile = "Development"
    )
    
    Write-Log "Optimizing Nuxt 3 for Windows with profile: $Profile" -Level "INFO"
    
    try {
        $env = Get-Nuxt3Environment
        if (-not $env) {
            Write-Log "Could not analyze environment for optimization" -Level "ERROR"
            return $false
        }
        
        $optimizations = 0
        
        # 1. Node.js Environment Variables
        Write-Log "Setting Node.js environment variables..." -Level "INFO"
        $nodeEnvVars = @{
            "NODE_OPTIONS" = "--max-old-space-size=8192 --experimental-vm-modules"
            "NODE_ENV" = "development"
            "NUXT_TELEMETRY_DISABLED" = "1"
            "NITRO_PRESET" = "node-server"
        }
        
        # Adjust based on system specs
        if ($env.System.RAM -ge 32) {
            $nodeEnvVars["NODE_OPTIONS"] = "--max-old-space-size=16384 --experimental-vm-modules"
        } elseif ($env.System.RAM -le 8) {
            $nodeEnvVars["NODE_OPTIONS"] = "--max-old-space-size=4096 --experimental-vm-modules"
        }
        
        foreach ($envVar in $nodeEnvVars.GetEnumerator()) {
            [Environment]::SetEnvironmentVariable($envVar.Key, $envVar.Value, "User")
            Write-Log "Set $($envVar.Key) = $($envVar.Value)" -Level "SUCCESS"
            $optimizations++
        }
        
        # 2. Package Manager Configuration
        Write-Log "Optimizing package manager configurations..." -Level "INFO"
        
        # pnpm configuration (recommended for Nuxt 3)
        if ($env.PackageManagers.pnpm.Installed) {
            $pnpmConfig = @(
                "pnpm config set store-dir C:\\.pnpm-store",
                "pnpm config set cache-dir C:\\.pnpm-cache",
                "pnpm config set state-dir C:\\.pnpm-state",
                "pnpm config set auto-install-peers true",
                "pnpm config set dedupe-peer-dependents true",
                "pnpm config set hoist-pattern '*'",
                "pnpm config set public-hoist-pattern '*eslint*,*prettier*,*typescript*'",
                "pnpm config set shamefully-hoist true"
            )
            
            foreach ($config in $pnpmConfig) {
                try {
                    Invoke-Expression $config
                    Write-Log "Applied pnpm config: $config" -Level "SUCCESS"
                    $optimizations++
                } catch {
                    Write-Log "Failed to apply pnpm config: $config" -Level "WARN"
                }
            }
        }
        
        # npm configuration
        if ($env.PackageManagers.npm.Installed) {
            $npmConfig = @(
                "npm config set fund false",
                "npm config set audit false",
                "npm config set progress false",
                "npm config set loglevel warn",
                "npm config set cache C:\\.npm-cache",
                "npm config set registry https://registry.npmjs.org/"
            )
            
            foreach ($config in $npmConfig) {
                try {
                    Invoke-Expression $config
                    Write-Log "Applied npm config: $config" -Level "SUCCESS"
                    $optimizations++
                } catch {
                    Write-Log "Failed to apply npm config: $config" -Level "WARN"
                }
            }
        }
        
        # 3. Windows Defender Exclusions for better performance
        Write-Log "Adding Windows Defender exclusions for development folders..." -Level "INFO"
        $exclusionPaths = @(
            "C:\.pnpm-store",
            "C:\.npm-cache",
            "C:\Users\$env:USERNAME\node_modules",
            "C:\Users\$env:USERNAME\.nuxt",
            "C:\Users\$env:USERNAME\.output",
            "$env:LOCALAPPDATA\pnpm",
            "$env:APPDATA\npm"
        )
        
        foreach ($path in $exclusionPaths) {
            try {
                Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
                Write-Log "Added Windows Defender exclusion: $path" -Level "SUCCESS"
                $optimizations++
            } catch {
                Write-Log "Could not add Windows Defender exclusion: $path" -Level "WARN"
            }
        }
        
        # 4. Create optimized Nuxt config template
        Write-Log "Creating optimized Nuxt configuration template..." -Level "INFO"
        $nuxtConfigTemplate = @"
// Nuxt 3 Optimized Configuration - Windows $(Get-Date -Format "yyyy-MM-dd")
export default defineNuxtConfig({
  // Performance optimizations
  experimental: {
    payloadExtraction: false,
    renderJsonPayloads: true,
    typedPages: true,
    watcher: 'parcel'
  },

  // Build optimizations
  nitro: {
    esbuild: {
      options: {
        target: 'esnext'
      }
    },
    minify: process.env.NODE_ENV === 'production',
    sourceMap: process.env.NODE_ENV === 'development'
  },

  // Vite optimizations for Windows
  vite: {
    optimizeDeps: {
      include: ['vue', '@vue/runtime-core', '@vue/runtime-dom']
    },
    server: {
      fs: {
        strict: false
      },
      watch: {
        usePolling: false,
        ignored: ['**/node_modules/**', '**/.git/**']
      }
    },
    build: {
      rollupOptions: {
        output: {
          manualChunks: {
            vendor: ['vue'],
            utils: ['lodash-es', 'date-fns']
          }
        }
      }
    }
  },

  // CSS optimizations
  css: {
    devSourcemap: true
  },

  // Development optimizations
  devtools: { enabled: process.env.NODE_ENV === 'development' },
  
  // SSR optimizations
  ssr: true,
  
  // Route generation
  prerender: {
    crawlLinks: false
  },

  // Modules for enhanced development
  modules: [
    '@pinia/nuxt',
    '@nuxtjs/tailwindcss',
    '@vueuse/nuxt'
  ],

  // TypeScript configuration
  typescript: {
    strict: true,
    typeCheck: process.env.NODE_ENV === 'development' ? 'build' : false
  },

  // Build performance
  build: {
    transpile: process.env.NODE_ENV === 'production' ? [] : undefined
  }
})
"@
        
        $configPath = "$env:USERPROFILE\Desktop\nuxt.config.optimized.ts"
        $nuxtConfigTemplate | Out-File -FilePath $configPath -Encoding UTF8
        Write-Log "Created optimized Nuxt config template: $configPath" -Level "SUCCESS"
        $optimizations++
        
        # 5. Create package.json scripts template
        Write-Log "Creating optimized package.json scripts..." -Level "INFO"
        $packageScripts = @{
            "scripts" = @{
                "dev" = "nuxt dev --host 0.0.0.0 --port 3000"
                "dev:turbo" = "nuxt dev --host 0.0.0.0 --port 3000 --no-fork-ts-checker"
                "build" = "nuxt build"
                "build:analyze" = "nuxt build --analyze"
                "preview" = "nuxt preview"
                "postinstall" = "nuxt prepare"
                "clean" = "nuxt cleanup"
                "clean:modules" = "rimraf node_modules .nuxt .output"
                "type-check" = "nuxt typecheck"
                "lint" = "eslint ."
                "lint:fix" = "eslint . --fix"
                "format" = "prettier --write ."
            }
        }
        
        $scriptsPath = "$env:USERPROFILE\Desktop\package-scripts-template.json"
        $packageScripts | ConvertTo-Json -Depth 3 | Out-File -FilePath $scriptsPath -Encoding UTF8
        Write-Log "Created package.json scripts template: $scriptsPath" -Level "SUCCESS"
        $optimizations++
        
        # 6. PowerShell profile optimization for Nuxt development
        Write-Log "Adding Nuxt aliases to PowerShell profile..." -Level "INFO"
        $profilePath = $PROFILE.CurrentUserCurrentHost
        $nuxtAliases = @"

# Nuxt 3 Development Aliases - Added $(Get-Date)
function nuxt-dev { pnpm dev }
function nuxt-build { pnpm build }
function nuxt-clean { pnpm clean; Remove-Item -Recurse -Force .nuxt, .output -ErrorAction SilentlyContinue }
function nuxt-fresh { nuxt-clean; pnpm install }
function nuxt-analyze { pnpm build:analyze }
function nuxt-type-check { pnpm type-check }

# Quick project setup
function nuxt-create { 
    param([string]`$name)
    if (-not `$name) { 
        Write-Host "Usage: nuxt-create <project-name>" -ForegroundColor Yellow
        return 
    }
    npx nuxi@latest init `$name
    Set-Location `$name
    pnpm install
}

Set-Alias -Name nd -Value nuxt-dev
Set-Alias -Name nb -Value nuxt-build
Set-Alias -Name nc -Value nuxt-clean
Set-Alias -Name nf -Value nuxt-fresh
"@
        
        try {
            if (!(Test-Path (Split-Path $profilePath))) {
                New-Item -ItemType Directory -Path (Split-Path $profilePath) -Force | Out-Null
            }
            Add-Content -Path $profilePath -Value $nuxtAliases
            Write-Log "Added Nuxt aliases to PowerShell profile" -Level "SUCCESS"
            $optimizations++
        } catch {
            Write-Log "Could not update PowerShell profile" -Level "WARN"
        }
        
        Write-Log "Windows Nuxt 3 optimization completed: $optimizations optimizations applied" -Level "SUCCESS"
        return $optimizations
    }
    catch {
        Write-Log "Error optimizing Nuxt 3 for Windows: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Install-Nuxt3Prerequisites {
    Write-Log "Installing Nuxt 3 prerequisites for Windows..." -Level "INFO"
    
    try {
        $installed = 0
        
        # Install Node.js LTS if not installed or outdated
        $env = Get-Nuxt3Environment
        if (-not $env.NodeJS.Installed -or -not $env.NodeJS.LTS) {
            Write-Log "Installing Node.js LTS..." -Level "INFO"
            try {
                winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
                Write-Log "Node.js LTS installed successfully" -Level "SUCCESS"
                $installed++
            } catch {
                Write-Log "Failed to install Node.js LTS via winget" -Level "WARN"
            }
        }
        
        # Install pnpm (recommended for Nuxt 3)
        if (-not $env.PackageManagers.pnpm.Installed) {
            Write-Log "Installing pnpm..." -Level "INFO"
            try {
                npm install -g pnpm@latest
                Write-Log "pnpm installed successfully" -Level "SUCCESS"
                $installed++
            } catch {
                Write-Log "Failed to install pnpm" -Level "WARN"
            }
        }
        
        # Install Git if not installed
        if (-not $env.Git.Installed) {
            Write-Log "Installing Git..." -Level "INFO"
            try {
                winget install Git.Git --accept-source-agreements --accept-package-agreements
                Write-Log "Git installed successfully" -Level "SUCCESS"
                $installed++
            } catch {
                Write-Log "Failed to install Git via winget" -Level "WARN"
            }
        }
        
        # Install essential global packages
        Write-Log "Installing essential global packages..." -Level "INFO"
        $globalPackages = @(
            "@nuxt/cli@latest",
            "nuxi@latest", 
            "typescript@latest",
            "@types/node@latest",
            "rimraf@latest",
            "cross-env@latest"
        )
        
        foreach ($package in $globalPackages) {
            try {
                npm install -g $package
                Write-Log "Installed global package: $package" -Level "SUCCESS"
                $installed++
            } catch {
                Write-Log "Failed to install: $package" -Level "WARN"
            }
        }
        
        Write-Log "Prerequisites installation completed: $installed items installed" -Level "SUCCESS"
        return $installed
    }
    catch {
        Write-Log "Error installing Nuxt 3 prerequisites: $($_.Exception.Message)" -Level "ERROR"
        return 0
    }
}

function Optimize-Nuxt3WSL {
    param([string]$Distribution = "Ubuntu")
    
    Write-Log "Optimizing Nuxt 3 for WSL ($Distribution)..." -Level "INFO"
    
    try {
        $env = Get-Nuxt3Environment
        if (-not $env.WSL.Installed) {
            Write-Log "WSL is not installed. Please install WSL first." -Level "ERROR"
            return $false
        }
        
        # Create WSL optimization script
        $wslScript = @"
#!/bin/bash
# Nuxt 3 WSL Optimization Script - $(Get-Date -Format "yyyy-MM-dd")

echo " Starting Nuxt 3 WSL Optimization..."

# Update system
echo " Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Node.js LTS via NodeSource
echo " Installing Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install build essentials
echo " Installing build essentials..."
sudo apt-get install -y build-essential python3-dev

# Install pnpm
echo " Installing pnpm..."
curl -fsSL https://get.pnpm.io/install.sh | sh -

# Source pnpm
source ~/.bashrc

# Configure pnpm
echo " Configuring pnpm..."
pnpm config set store-dir ~/.pnpm-store
pnpm config set cache-dir ~/.pnpm-cache
pnpm config set auto-install-peers true
pnpm config set shamefully-hoist true

# Install global packages
echo " Installing global packages..."
pnpm add -g @nuxt/cli nuxi typescript @types/node rimraf cross-env

# Configure Git (if not configured)
if ! git config --global user.name > /dev/null 2>&1; then
    echo " Please configure Git:"
    read -p "Enter your name: " git_name
    read -p "Enter your email: " git_email
    git config --global user.name "`$git_name"
    git config --global user.email "`$git_email"
fi

# Create Nuxt aliases
echo " Adding Nuxt aliases to .bashrc..."
cat >> ~/.bashrc << 'EOL'

# Nuxt 3 Development Aliases
alias nd='pnpm dev'
alias nb='pnpm build'
alias nc='pnpm clean'
alias nf='rm -rf node_modules .nuxt .output && pnpm install'
alias na='pnpm build:analyze'
alias nt='pnpm type-check'

# Quick project creation
nuxt-create() {
    if [ -z "`$1" ]; then
        echo "Usage: nuxt-create <project-name>"
        return 1
    fi
    npx nuxi@latest init "`$1"
    cd "`$1"
    pnpm install
}
EOL

# Set up optimal .wslconfig (Windows side)
echo " WSL optimization completed!"
echo " Please restart your WSL session to apply changes"
echo " Use 'nd' for dev, 'nb' for build, 'nc' for clean"
"@
        
        $scriptPath = "$env:TEMP\nuxt3-wsl-setup.sh"
        $wslScript | Out-File -FilePath $scriptPath -Encoding UTF8
        
        # Copy script to WSL and execute
        Write-Log "Copying optimization script to WSL..." -Level "INFO"
        wsl -d $Distribution cp $scriptPath /tmp/nuxt3-setup.sh
        wsl -d $Distribution chmod +x /tmp/nuxt3-setup.sh
        
        Write-Log "Executing optimization script in WSL..." -Level "INFO"
        wsl -d $Distribution bash /tmp/nuxt3-setup.sh
        
        # Create optimized .wslconfig
        Write-Log "Creating optimized .wslconfig..." -Level "INFO"
        $wslConfig = @"
[wsl2]
memory=8GB
processors=4
localhostForwarding=true
swap=2GB
swapFile=C:\\temp\\wsl-swap.vhdx

[experimental]
sparseVhd=true
"@
        
        # Adjust based on system specs
        if ($env.System.RAM -ge 32) {
            $wslConfig = $wslConfig -replace "memory=8GB", "memory=16GB"
            $wslConfig = $wslConfig -replace "processors=4", "processors=8"
        } elseif ($env.System.RAM -le 8) {
            $wslConfig = $wslConfig -replace "memory=8GB", "memory=4GB"
            $wslConfig = $wslConfig -replace "processors=4", "processors=2"
        }
        
        $wslConfigPath = "$env:USERPROFILE\.wslconfig"
        $wslConfig | Out-File -FilePath $wslConfigPath -Encoding UTF8
        Write-Log "Created optimized .wslconfig: $wslConfigPath" -Level "SUCCESS"
        
        Write-Log "WSL Nuxt 3 optimization completed successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error optimizing Nuxt 3 for WSL: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-Nuxt3Performance {
    Write-Log "Testing Nuxt 3 performance and configuration..." -Level "INFO"
    
    try {
        $env = Get-Nuxt3Environment
        $results = @{
            NodeJS = $env.NodeJS.Installed
            PackageManager = ($env.PackageManagers.pnpm.Installed -or $env.PackageManagers.npm.Installed)
            Git = $env.Git.Installed
            OptimalSetup = $false
            Recommendations = @()
        }
        
        # Check for optimal setup
        if ($env.NodeJS.LTS -and $env.PackageManagers.pnpm.Installed -and $env.Git.Installed) {
            $results.OptimalSetup = $true
            Write-Log " Optimal Nuxt 3 setup detected!" -Level "SUCCESS"
        } else {
            if (-not $env.NodeJS.LTS) {
                $results.Recommendations += "Install Node.js LTS for best compatibility"
            }
            if (-not $env.PackageManagers.pnpm.Installed) {
                $results.Recommendations += "Install pnpm for faster package management"
            }
            if (-not $env.Git.Installed) {
                $results.Recommendations += "Install Git for version control"
            }
        }
        
        # Performance recommendations
        if ($env.System.RAM -lt 8) {
            $results.Recommendations += "Consider upgrading RAM to 8GB+ for better development experience"
        }
        if (-not $env.System.SSDDrive) {
            $results.Recommendations += "Consider using an SSD for faster build times"
        }
        
        Write-Log "Performance test completed" -Level "SUCCESS"
        return $results
    }
    catch {
        Write-Log "Error testing Nuxt 3 performance: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

