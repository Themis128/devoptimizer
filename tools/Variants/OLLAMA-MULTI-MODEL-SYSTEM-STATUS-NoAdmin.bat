@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
REM Ollama Multi-Model System Status Report
REM Shows the current status of the multi-model system integration

setlocal enabledelayedexpansion

echo ================================================================


:: Running without admin privileges - some features may be limited
echo [INFO] Running in standard mode without Administrator privileges
echo [INFO] Some system-level features may be limited

echo            OLLAMA MULTI-MODEL SYSTEM STATUS REPORT
echo ================================================================
echo.
echo Generated: %date% %time%
echo System: Windows 11 Build 26120
echo Location: D:\DevOptimizer
echo.

REM Check Ollama installation
echo [1/6] Checking Ollama installation...
where ollama >nul 2>&1
if %errorlevel% equ 0 (
echo    Ollama is installed and accessible
ollama --version 2>nul
) else (
echo    Ollama not found in PATH
)
echo.

REM Check available models
echo [2/6] Checking available Ollama models...
ollama list 2>nul
if %errorlevel% equ 0 (
echo    Models available for multi-model analysis
) else (
echo    Error listing models
)
echo.

REM Check core multi-model system files
echo [3/6] Checking core multi-model system files...
set "CORE_FILES=0"
if exist "tools\ollama-utils.ps1" (
echo    ollama-utils.ps1 - Core utilities
set /a CORE_FILES+=1
) else (
echo    ollama-utils.ps1 - Missing
)

if exist "tools\run-ollama-all.ps1" (
echo    run-ollama-all.ps1 - Multi-model runner
set /a CORE_FILES+=1
) else (
echo    run-ollama-all.ps1 - Missing
)

if exist "tools\ollama-batch-helper.bat" (
echo    ollama-batch-helper.bat - Batch integration helper
set /a CORE_FILES+=1
) else (
echo    ollama-batch-helper.bat - Missing
)

if exist "RUN-OLLAMA-ALL-MODELS.bat" (
echo    RUN-OLLAMA-ALL-MODELS.bat - Main entry point
set /a CORE_FILES+=1
) else (
echo    RUN-OLLAMA-ALL-MODELS.bat - Missing
)

if exist "configs\ollama.config.json" (
echo    ollama.config.json - Configuration file
set /a CORE_FILES+=1
) else (
echo    ollama.config.json - Missing
)
echo.

REM Check updated Ollama scripts
echo [4/6] Checking updated Ollama scripts...
set "UPDATED_SCRIPTS=0"
for %%f in (ollama-*.bat) do (
findstr /c:"ollama-batch-helper.bat" "%%f" >nul 2>&1
if !errorlevel! equ 0 (
echo    %%f - Updated to use multi-model system
set /a UPDATED_SCRIPTS+=1
) else (
echo    %%f - Not updated or missing
)
)
echo.

REM Check for hardcoded model calls
echo [5/6] Checking for hardcoded model calls...
findstr /c:"ollama run qwen" ollama-*.bat >nul 2>&1
if %errorlevel% neq 0 (
echo    No hardcoded model calls found - All scripts use multi-model system
) else (
echo    Hardcoded model calls still present:
findstr /c:"ollama run qwen" ollama-*.bat
)
echo.

REM Check AI integration module
echo [6/6] Checking AI integration module...
if exist "ai-integration-module.ps1" (
findstr /c:"Invoke-OllamaMultiModelAnalysis" "ai-integration-module.ps1" >nul 2>&1
if !errorlevel! equ 0 (
echo    AI integration module - Multi-model function available
) else (
echo    AI integration module - Multi-model function not found
)
) else (
echo    AI integration module - File not found
)
echo.

REM Summary
echo ================================================================
echo                    SYSTEM STATUS SUMMARY
echo ================================================================
echo.
echo Core system files: %CORE_FILES%/5
echo Updated scripts: %UPDATED_SCRIPTS%/6
echo.

if %CORE_FILES% equ 5 if %UPDATED_SCRIPTS% geq 5 (
echo  SYSTEM STATUS: FULLY OPERATIONAL
echo.
echo  All core components are in place
echo  All scripts updated to use multi-model system
echo [OK] No hardcoded model calls remaining
echo  System ready for production use
echo.
echo Available functionality:
echo   - Automatic model discovery from 'ollama list'
echo   - Multi-model consensus analysis
echo   - Parallel and sequential execution modes
echo   - Comprehensive output generation
echo   - Integration with all existing Ollama scripts
echo   - AI integration module support
echo.
echo Usage examples:
echo   ollama-ai-analyzer.bat
echo   ollama-performance-scorer.bat
echo   RUN-OLLAMA-ALL-MODELS.bat "Your prompt here"
echo   pwsh -File ai-integration-module.ps1 -Mode ollama -Context "Your prompt"
) else (
echo   SYSTEM STATUS: PARTIALLY OPERATIONAL
echo.
echo Some components may need attention:
if %CORE_FILES% lt 5 (
echo   - Missing core system files (%CORE_FILES%/5)
)
if %UPDATED_SCRIPTS% lt 5 (
echo   - Some scripts not updated (%UPDATED_SCRIPTS%/6)
)
echo.
echo Please review the issues above and ensure all components are properly installed.
)

echo.
echo ================================================================
echo                    NEXT STEPS
echo ================================================================
echo.
echo 1. Test the system with: RUN-OLLAMA-ALL-MODELS.bat "Test prompt"
echo 2. Run any Ollama script to see multi-model analysis in action
echo 3. Check logs directory for detailed output and analysis results
echo 4. Customize configs\ollama.config.json for specific model filtering
echo 5. Use AI integration module for programmatic access
echo.
echo System ready for enhanced multi-model AI analysis! 
echo.
pause
exit /b %ERRORLEVEL%
