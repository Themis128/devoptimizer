# DevOptimizer PowerShell to Python Migration Plan

## Overview
This plan outlines the migration of 137 PowerShell scripts to Python equivalents within the DevOptimizer CLI framework. The migration will maintain all existing functionality while improving cross-platform compatibility, testability, and maintainability.

## Current State
- **PowerShell scripts**: 137 total scripts in `/scripts/` directory
- **Python CLI commands**: 6 modules (`metrics`, `analyze`, `bootstrap`, `remediate`, `security`, `cleanup`)
- **Python cleanup commands**: 5 commands already migrated (`win11-safe-cleanup`, `check-cleanup-status`, `compact-vhdx`, `win11-admin-cleanup`, `extended-cleanup`)

## Migration Strategy

### Phase 1: Foundation & Assessment (Weeks 1-2)
1. **Create migration framework**
   - Establish common Python utilities for file operations, process management, etc.
   - Create base classes for different script types (cleanup, diagnostics, utilities)
   - Set up logging and error handling patterns consistent with existing Python CLI

2. **Catalog and categorize scripts**
   - Analyze all 137 PowerShell scripts by functionality
   - Group into logical categories matching Python CLI structure
   - Identify scripts with existing Python equivalents

3. **Prioritize migration targets**
   - Start with high-impact, frequently used scripts
   - Focus on scripts that complement existing Python modules

### Phase 2: Core Migration (Weeks 3-8)
Migrate scripts in priority order, integrating with appropriate Python CLI modules.

#### Category 1: System Diagnostics & Monitoring (Target: `analyze` module)
Scripts to migrate:
- `check-devin.ps1`, `check-devin-logs.ps1`, `check-devin-processes.ps1`
- `check-host-memory.ps1`, `check-disks.ps1`, `check-tasks.ps1`
- `check-social-apps.ps1`, `check-store-apps.ps1`, `check-reboot-status.ps1`
- `ADVANCED-DIAGNOSTICS.ps1`, `check-nextcloud-sync.ps1`
- `check-trigger*.ps1` series, `check-elevated-task.ps1`

#### Category 2: System Maintenance & Cleanup (Target: `cleanup` module)
Scripts to migrate:
- `win11-safe-cleanup.ps1` (already started)
- `extended-cleanup.ps1` (already started)
- `admin-cleanup-elevated.ps1` (already started)
- `check-cleanup-status.ps1` (already started)
- `bound-container-logs.ps1`, `backup-docker-nas.ps1`
- `docker`-related scripts, `WSL` maintenance scripts

#### Category 3: Development Environment & Tools (Target: `bootstrap` module)
Scripts to migrate:
- `Build-App.ps1`, `apply-cline-settings.ps1`, `apply-cline-settings-pair.ps1`
- `ai-development-tools.ps1`, `ai-integration-module.ps1`
- `automation-module.ps1`, `CENTERAL-LAUNCHER.ps1`
- Development environment setup and configuration scripts

#### Category 4: Security & Hardening (Target: `security` module)
Scripts to migrate:
- Security scanning and hardening scripts
- Certificate management, firewall configuration
- Permission and access control scripts

#### Category 5: Utilities & Helpers (Distributed across modules)
Scripts to migrate:
- File manipulation, path utilities
- Process management helpers
- Configuration readers/writers
- Notification and alerting scripts

### Phase 3: Integration & Testing (Weeks 9-12)
1. **Hub integration**
   - Ensure migrated scripts register properly in `hub-registry.json`
   - Maintain compatibility with deep link protocol
   - Preserve parameter collection and validation mechanisms

2. **Testing strategy**
   - Unit tests for each migrated script
   - Integration tests for CLI command execution
   - Regression testing against existing functionality
   - Cross-platform validation where applicable

3. **Documentation & knowledge transfer**
   - Update inline documentation and XML comments
   - Create migration guide for future contributors
   - Document any platform-specific limitations

## Technical Approach

### Core Libraries & Patterns
- **File operations**: `pathlib`, `shutil`, `os`
- **Process management**: `subprocess`, `psutil` (already used in Python CLI)
- **Registry access**: `winreg` (Windows-specific) with fallback abstractions
- **Network operations**: `httpx`, `requests`
- **JSON/YAML**: `json`, `yaml`, `pydantic` for configuration
- **Date/time**: `datetime`, `dateutil`
- **Logging**: Structured logging compatible with existing Python CLI
- **Error handling**: Consistent exception handling with user-friendly messages

### Safety Features Preservation
- Dry-run modes (`-DryRun` flags)
- Confirmation prompts for destructive operations
- Permission/elevation checks
- File locking and conflict resolution
- Backup mechanisms where appropriate

### Registry Integration
- Python scripts must register in `hub-registry.json` with proper metadata
- Maintain compatibility with existing script hub deep link protocol
- Preserve parameter collection and validation mechanisms
- Support for elevation requirements and execution policies

## Migration Waves

### Wave 1: Quick Wins (Weeks 1-2)
Migrate scripts with direct Python equivalents or simple translations:
- `check-cleanup-status.ps1` → Enhance existing Python version
- `check-devin.ps1` and variants → `analyze` module
- Simple utility scripts (file checks, path validations)

### Wave 2: Core Functionality (Weeks 3-6)
Migrate frequently used, high-value scripts:
- Cleanup scripts (user and admin levels)
- Diagnostic scripts (system health, process monitoring)
- Development environment scripts

### Wave 3: Specialized & Complex (Weeks 7-10)
Migrate complex scripts requiring careful translation:
- Build and deployment scripts
- Integration scripts (AI, Docker, WSL)
- Security hardening scripts

### Wave 4: Polish & Integration (Weeks 11-12)
- Finalize hub integration
- Comprehensive testing
- Documentation updates
- Performance optimization

## Success Criteria
1. **Functional equivalence**: All migrated scripts provide identical functionality to PowerShell originals
2. **Safety preservation**: All safety checks, dry-run modes, and confirmation prompts work identically
3. **CLI integration**: Migrated scripts appear as native commands in DevOptimizer CLI
4. **Registry compatibility**: Scripts properly register and work with script hub
5. **Testing coverage**: Minimum 80% unit test coverage for migrated scripts
6. **Backward compatibility**: Existing PowerShell scripts remain functional during transition

## Estimated Effort
- **Total scripts**: 137 PowerShell scripts
- **Already migrated**: 5 cleanup commands (in cleanup.py)
- **Remaining**: ~132 scripts to migrate
- **Average complexity**: Moderate (most scripts are focused utilities)
- **Estimated time**: 12 weeks for complete migration with focused effort

## Risks & Mitigation
1. **Platform-specific dependencies**: Use abstraction layers for Windows-specific calls
   - Mitigation: Create cross-platform wrappers with graceful degradation
   
2. **Complex PowerShell features**: Some scripts may use advanced PowerShell features
   - Mitigation: Break complex scripts into smaller, focused Python functions
   
3. **Performance differences**: Python may have different performance characteristics
   - Mitigation: Profile and optimize critical paths, use appropriate algorithms
   
4. **Testing gaps**: Ensuring all edge cases are covered
   - Mitigation: Comprehensive test suite with property-based testing where applicable

## Next Steps Immediate Action Items
1. **Create migration framework utilities** in `devoptimizer_cli/core/`
2. **Begin Wave 1 migration** with simple diagnostic scripts
3. **Establish weekly migration goals** and review process
4. **Set up automated testing** for migrated scripts
5. **Create migration tracking spreadsheet** to monitor progress

## Conclusion
This migration will transform DevOptimizer from a PowerShell-centric tool to a modern Python-based CLI while preserving all existing functionality and safety features. The modular approach allows for incremental migration with continuous validation, ensuring system stability throughout the process.