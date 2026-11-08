# DevOptimizer Integration Skill

This skill provides Devin Desktop integration with the DevOptimizer script hub.

## Overview

DevOptimizer is a Windows system optimization and maintenance toolkit with 487+ commands across 16 categories, including:

- System cleanup (safe, extended, admin/system-level)
- WSL2/Docker Desktop integration management
- Devin Desktop infrastructure automation
- NAS backup orchestration
- Host resource monitoring

## Available Commands

### Devin-Specific Commands
- `check-devin-health` - WSL remote health check
- `check-devin-doctor` - Data store integrity check
- `verify-devin-setup` - Comprehensive setup verification
- `invoke-devin-daily-maintenance` - 7-step daily maintenance
- `repair-devin` - Guarded repair actions
- `tune-windows-for-devin` - Windows optimization for Devin

### System Commands
- `win11-safe-cleanup` - Safe daily cleanup
- `extended-cleanup` - Weekly deep cleanup
- `admin-cleanup-system` - SYSTEM-level cleanup (DISM, vssadmin)
- `wsl-ubuntu-cleanup` - WSL guest cleanup
- `check-wsl-system-status` - WSL status fine-tuning
- `sync-docker-wsl` - Docker-WSL port sync
- `wsl-permanent-fix` - 4-layer WSL self-healing

### Backup Commands
- `backup-docker-nas` - NAS backup with pg_dumpall

## Integration with Devin

This skill enables Devin to:
1. Execute DevOptimizer commands via the script hub
2. Monitor Devin's own infrastructure health
3. Automate daily maintenance
4. Recover from common failure modes

## Usage

Commands are registered in the DevOptimizer hub registry and can be invoked via:
- Devin Desktop chat: "run check-devin-health"
- CLI: `devoptimizer check-devin-health`
- Scheduled tasks: Automatic daily/weekly runs

## Configuration

The skill references:
- `D:\DevOptimizer\scripts\devin\` - Devin-specific scripts
- `D:\DevOptimizer\config\hub-registry.json` - Command registry
- `D:\DevOptimizer\scripts\lib\` - Shared libraries (Notify, Log, State, TaskUtil)

## Requirements

- Windows 11
- WSL2 with Ubuntu-24.04
- Docker Desktop with WSL integration
- Devin Desktop 3.12+
- PowerShell 5.1+ (pwsh 7.6+ recommended)