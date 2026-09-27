#Requires -RunAsAdministrator

# Machine Learning Frameworks Setup Script
# Comprehensive ML environment setup for Windows

param(
    [switch]$InstallAll,
    [switch]$TensorFlowOnly,
    [switch]$PyTorchOnly,
    [switch]$JupyterOnly,
    [switch]$Verbose
)

# Enhanced logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "DEBUG" { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Check if Python is installed
function Test-PythonInstallation {
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
            Write-Log "Python found: $pythonVersion" -Level "SUCCESS"
            return $true
        }
    }
    catch {
        Write-Log "Python not found. Installing Python..." -Level "WARNING"
        return $false
    }
    return $false
}

# Install Python if not present
function Install-Python {
    Write-Log "Installing Python..." -Level "INFO"
    
    try {
        # Download and install Python
        $pythonUrl = "https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe"
        $pythonInstaller = "$env:TEMP\python-installer.exe"
        
        Write-Log "Downloading Python installer..." -Level "INFO"
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
        
        Write-Log "Installing Python..." -Level "INFO"
        Start-Process -FilePath $pythonInstaller -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait
        Remove-Item $pythonInstaller -Force
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Log "Python installation completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error installing Python: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Setup TensorFlow
function Install-TensorFlow {
    Write-Log "Setting up TensorFlow..." -Level "INFO"
    
    try {
        # Install TensorFlow with GPU support
        pip install tensorflow[gpu]
        
        # Install additional TensorFlow tools
        pip install tensorflow-hub
        pip install tensorflow-datasets
        pip install tensorflow-addons
        pip install tensorflow-model-optimization
        
        # Install TensorFlow Serving (optional)
        # pip install tensorflow-serving-api
        
        Write-Log "TensorFlow setup completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error setting up TensorFlow: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Setup PyTorch
function Install-PyTorch {
    Write-Log "Setting up PyTorch..." -Level "INFO"
    
    try {
        # Install PyTorch with CUDA support
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
        
        # Install additional PyTorch tools
        pip install torch-geometric
        pip install torch-scatter torch-sparse torch-cluster torch-spline-conv
        pip install pytorch-lightning
        pip install torchmetrics
        
        Write-Log "PyTorch setup completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error setting up PyTorch: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Setup Jupyter environment
function Install-Jupyter {
    Write-Log "Setting up Jupyter environment..." -Level "INFO"
    
    try {
        # Install Jupyter Lab and Notebook
        pip install jupyterlab
        pip install notebook
        pip install ipywidgets
        pip install jupyter_contrib_nbextensions
        
        # Install Jupyter extensions
        jupyter nbextension enable --py widgetsnbextension
        jupyter labextension install @jupyter-widgets/jupyterlab-manager
        
        # Install additional data science packages
        pip install pandas numpy matplotlib seaborn plotly
        pip install scikit-learn scipy statsmodels
        pip install opencv-python pillow
        pip install requests beautifulsoup4 lxml
        
        # Create Jupyter configuration
        $jupyterConfig = "$env:USERPROFILE\.jupyter\jupyter_lab_config.py"
        $jupyterDir = Split-Path $jupyterConfig -Parent
        if (!(Test-Path $jupyterDir)) {
            New-Item -ItemType Directory -Path $jupyterDir -Force | Out-Null
        }
        
        @"
# Jupyter Lab Configuration
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.allow_root = True
c.ServerApp.allow_origin = '*'
c.ServerApp.token = ''
c.ServerApp.password = ''
"@ | Out-File -FilePath $jupyterConfig -Encoding UTF8
        
        Write-Log "Jupyter environment setup completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error setting up Jupyter: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Setup additional ML tools
function Install-AdditionalMLTools {
    Write-Log "Setting up additional ML tools..." -Level "INFO"
    
    try {
        # Install additional ML frameworks
        pip install transformers datasets accelerate
        pip install sentence-transformers
        pip install openai
        pip install langchain langchain-community
        
        # Install visualization tools
        pip install streamlit gradio
        pip install dash plotly-dash
        
        # Install model serving tools
        pip install fastapi uvicorn
        pip install mlflow
        
        # Install development tools
        pip install black isort flake8 mypy
        pip install pytest pytest-cov
        pip install pre-commit
        
        Write-Log "Additional ML tools setup completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error setting up additional ML tools: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Create ML development environment
function New-MLEnvironment {
    Write-Log "Creating ML development environment..." -Level "INFO"
    
    try {
        # Create ML projects directory
        $mlDir = "$env:USERPROFILE\ML-Projects"
        if (!(Test-Path $mlDir)) {
            New-Item -ItemType Directory -Path $mlDir -Force | Out-Null
        }
        
        # Create subdirectories
        $subdirs = @("models", "data", "notebooks", "scripts", "experiments")
        foreach ($dir in $subdirs) {
            $path = Join-Path $mlDir $dir
            if (!(Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            }
        }
        
        # Create sample Jupyter notebook
        $sampleNotebook = Join-Path $mlDir "notebooks\sample_ml_project.ipynb"
        @"
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Sample ML Project\\n",
    "\\n",
    "This is a sample Jupyter notebook for ML development."
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import pandas as pd\\n",
    "import numpy as np\\n",
    "import matplotlib.pyplot as plt\\n",
    "import seaborn as sns\\n",
    "\\n",
    "print('ML environment is ready!')"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
"@ | Out-File -FilePath $sampleNotebook -Encoding UTF8
        
        Write-Log "ML development environment created: $mlDir" -Level "SUCCESS"
    }
    catch {
        Write-Log "Error creating ML environment: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Main execution
try {
    Write-Log "Starting Machine Learning Frameworks Setup..." -Level "INFO"
    
    # Check and install Python if needed
    if (!(Test-PythonInstallation)) {
        Install-Python
    }
    
    if ($InstallAll -or $TensorFlowOnly) {
        Install-TensorFlow
    }
    
    if ($InstallAll -or $PyTorchOnly) {
        Install-PyTorch
    }
    
    if ($InstallAll -or $JupyterOnly) {
        Install-Jupyter
    }
    
    if ($InstallAll) {
        Install-AdditionalMLTools
        New-MLEnvironment
    }
    
    Write-Log "Machine Learning Frameworks setup completed successfully!" -Level "SUCCESS"
    Write-Log "You can now start Jupyter Lab with: jupyter lab" -Level "INFO"
}
catch {
    Write-Log "Unhandled error: $($_.Exception.Message)" -Level "ERROR"
}
