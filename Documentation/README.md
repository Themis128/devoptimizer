# DevOptimizer

A comprehensive Windows optimization and monitoring tool that combines PowerShell automation, Python CLI, and AI-powered analysis for system performance tuning, security hardening, and development environment setup.

## Overview

DevOptimizer provides:
- **Performance Monitoring**: Real-time metrics collection using Windows Performance Toolkit
- **AI-Powered Analysis**: Offline analysis using Ollama models for system optimization
- **Security Hardening**: Automated security audits and hardening measures
- **Development Bootstrap**: Automated setup of development tools and environments
- **Scheduled Automation**: Task Scheduler integration for continuous monitoring

## Architecture

```
D:\DevOptimizer\
├── bin\                    # Third-party tools (Sysinternals, etc.)
│   └── sysinternals\       # Sysinternals Suite
├── ps\                     # PowerShell scripts and modules
│   ├── DevOptimizer.psm1   # Core PowerShell module
│   ├── Install-Modules.ps1 # Module installation script
│   ├── Collect-Metrics.ps1 # Metrics collection script
│   ├── Run-Analysis.ps1    # AI analysis script
│   ├── Security-Hardening.ps1 # Security hardening script
│   ├── Bootstrap-DevEnvironment.ps1 # Development environment setup
│   └── Register-ScheduledTasks.ps1 # Task scheduler management
├── py\                     # Python CLI application
│   ├── devoptimizer_cli\   # Main CLI package
│   │   ├── __init__.py
│   │   ├── __main__.py
│   │   ├── cli.py          # Main CLI entry point
│   │   └── commands\       # CLI command modules
│   │       ├── metrics.py  # Metrics collection commands
│   │       ├── analyze.py  # AI analysis commands
│   │       ├── remediate.py # System remediation commands
│   │       ├── bootstrap.py # Environment setup commands
│   │       └── security.py # Security commands
│   ├── venv\               # Python virtual environment
│   └── requirements.txt    # Python dependencies
├── tasks\                  # Task Scheduler XML definitions
│   ├── DevOptimizer-HourlyMetrics.xml
│   ├── DevOptimizer-DailyAnalysis.xml
│   └── DevOptimizer-WeeklyMaintenance.xml
├── configs\                # Configuration files
│   ├── winget-packages.json # Package installation list
│   └── default-counters.txt # Performance counters
├── .env\                   # Environment variables and secrets
├── metrics\                # Performance metrics data
├── traces\                 # ETW trace files
├── logs\                   # Execution logs
├── ai-analysis\            # AI analysis results
├── security\               # Security audit results
└── README.md               # This file
```

## Prerequisites

### Required Software
- **Windows 10/11** (64-bit recommended)
- **PowerShell 7+** (pwsh.exe)
- **Python 3.12+** (for CLI functionality)
- **Ollama** (for AI analysis - optional but recommended)

### Optional Software
- **winget** (Windows Package Manager)
- **Chocolatey** (alternative package manager)

## Installation

### 1. Initial Setup

Run the installation script to set up the environment:

```powershell
# Run as Administrator
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Install-Modules.ps1"
```

This will:
- Install required PowerShell modules
- Configure SecretManagement vault
- Set up directory structure

### 2. Development Environment Bootstrap

Set up your development environment:

```powershell
# Run as Administrator
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Bootstrap-DevEnvironment.ps1"
```

This will:
- Install development tools via winget/Chocolatey
- Set up Python virtual environment
- Configure Git
- Create desktop shortcuts

### 3. Register Scheduled Tasks

Set up automated monitoring:

```powershell
# Run as Administrator
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Register-ScheduledTasks.ps1"
```

This will register:
- **Hourly Metrics Collection**: Every hour, 5-minute collection
- **Daily AI Analysis**: Daily at 2 AM
- **Weekly Maintenance**: Weekly on Sunday at 3 AM

## Usage

### PowerShell Module

```powershell
# Import the module
Import-Module "D:\DevOptimizer\ps\DevOptimizer.psm1"

# Initialize environment
Initialize-DevOptimizer

# Start metrics collection
Start-PerformanceCollection -Duration 300

# Get system metrics snapshot
Get-SystemMetrics

# Start ETW trace
Start-ETWTrace -Profile "CPU" -Duration 60
```

### Python CLI

```powershell
# Activate virtual environment
D:\DevOptimizer\py\venv\Scripts\Activate.ps1

# Check system status
python -m devoptimizer_cli status

# Collect metrics
python -m devoptimizer_cli metrics collect --duration 300

# Run AI analysis
python -m devoptimizer_cli analyze system --model llama3.1

# Security audit
python -m devoptimizer_cli security audit

# System remediation
python -m devoptimizer_cli remediate cleanup --temp --cache
```

### Manual Script Execution

```powershell
# Collect metrics
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Collect-Metrics.ps1" -Duration 600

# Run AI analysis
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Run-Analysis.ps1" -SystemAnalysis -LogAnalysis

# Security hardening
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Security-Hardening.ps1" -RunSecurityAudit -ScanMalware
```

## Configuration

### Performance Counters

Edit `D:\DevOptimizer\configs\default-counters.txt` to customize performance counter collection.

### Package Installation

Modify `D:\DevOptimizer\configs\winget-packages.json` to add or remove development tools.

### Task Scheduling

Task schedules can be modified in the XML files in `D:\DevOptimizer\tasks\`:
- **HourlyMetrics**: Adjust repetition interval
- **DailyAnalysis**: Change start time
- **WeeklyMaintenance**: Modify day and time

## AI Analysis

### Ollama Setup

1. Install Ollama from https://ollama.ai
2. Pull required models:
   ```bash
   ollama pull llama3.1
   ollama pull codellama
   ```

### Analysis Types

- **System Analysis**: Performance issues, optimization recommendations
- **Log Analysis**: Error patterns, security events, system stability
- **Remediation Scripts**: AI-generated PowerShell and batch scripts

## Security Features

### Security Audit
- Process analysis for suspicious activity
- Service enumeration and optimization
- Startup program review
- Windows Defender status check
- Network connection monitoring

### Security Hardening
- Disable unnecessary services
- Configure Windows Defender settings
- Set firewall rules
- Registry optimizations
- Malware scanning

### Sysinternals Integration
- Autoruns analysis
- Process monitoring
- File system monitoring
- Registry monitoring
- Network monitoring

## Monitoring and Logs

### Log Locations
- **Execution Logs**: `D:\DevOptimizer\logs\`
- **Metrics Data**: `D:\DevOptimizer\metrics\`
- **Analysis Results**: `D:\DevOptimizer\ai-analysis\`
- **Security Reports**: `D:\DevOptimizer\security\`

### Log Rotation
- Metrics files: Automatic rotation by timestamp
- Log files: 90-day retention
- Analysis results: 30-day retention
- Security reports: 1-year retention

## Troubleshooting

### Common Issues

1. **PowerShell Execution Policy**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **Ollama Not Available**
   - Install Ollama from https://ollama.ai
   - Start Ollama service
   - Pull required models

3. **Permission Denied**
   - Run scripts as Administrator
   - Check file permissions
   - Verify antivirus exclusions

4. **Module Import Errors**
   - Run `Install-Modules.ps1`
   - Check PowerShell version (7+ required)
   - Verify module paths

### Debug Mode

Enable verbose logging:

```powershell
$VerbosePreference = "Continue"
pwsh -ExecutionPolicy Bypass -File "D:\DevOptimizer\ps\Collect-Metrics.ps1" -Verbose
```

## Performance Impact

### Resource Usage
- **CPU**: < 5% during collection
- **Memory**: < 100MB for CLI, < 50MB for background tasks
- **Disk**: ~10MB per hour of metrics collection
- **Network**: Minimal (offline-first design)

### Optimization
- Metrics collection uses minimal resources
- AI analysis runs during low-usage periods
- Automatic cleanup of old data
- Efficient data compression

## Security Considerations

### Data Privacy
- All data processed locally
- No external network communication
- Secrets stored in PowerShell SecretManagement
- Configurable data retention

### Access Control
- Administrator privileges required for system changes
- Least privilege execution for scheduled tasks
- Secure credential handling
- Audit logging for all operations

## Contributing

### Development Setup
1. Clone the repository
2. Run bootstrap script
3. Activate Python virtual environment
4. Install development dependencies

### Code Standards
- PowerShell: Follow PowerShell Best Practices
- Python: Follow PEP 8 guidelines
- Documentation: Update README for new features
- Testing: Test all scripts before deployment

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

### Documentation
- Check this README for common issues
- Review log files for error details
- Consult PowerShell and Python documentation

### Reporting Issues
1. Check existing logs in `D:\DevOptimizer\logs\`
2. Include system information
3. Provide reproduction steps
4. Attach relevant log files

## Changelog

### Version 1.0.0 (2025-04-10)
- Initial release
- PowerShell module with core functionality
- Python CLI with Typer framework
- AI analysis integration with Ollama
- Security hardening capabilities
- Development environment bootstrap
- Scheduled task automation
- Comprehensive documentation

## Roadmap

### Future Features
- Web dashboard for monitoring
- Advanced AI models integration
- Cloud sync capabilities
- Mobile app for monitoring
- Integration with other monitoring tools
- Advanced reporting features
- Multi-language support
- Plugin architecture

## Acknowledgments

- Microsoft for PowerShell and Windows APIs
- Ollama team for AI model hosting
- Sysinternals for system analysis tools
- Python community for excellent libraries
- Open source contributors

---

**DevOptimizer** - Optimizing Windows systems with AI-powered intelligence.
