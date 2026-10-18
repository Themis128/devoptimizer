#!/usr/bin/env python3
"""
DevOptimizer System - Configuration Loader Module
This module provides centralized configuration management for the DevOptimizer system
"""

import os
import json
from pathlib import Path
from typing import Any, Dict, Optional

# Global configuration variable
_dev_optimizer_config: Optional[Dict[str, Any]] = None

# Define the base directory as the DevOptimizer root (constant)
_DEV_OPTIMIZER_ROOT = Path("D:/DevOptimizer").resolve()

def get_config_path(config_path: str = "configs/system-config.json") -> Path:
    """
    Gets the full path to the configuration file with security validation.
    
    Args:
        config_path: Relative path to the configuration file.
        
    Returns:
        Path: Full path to the configuration file.
    """
    # Handle empty or None path by using default
    if not config_path or not isinstance(config_path, str):
        config_path = "configs/system-config.json"
    
    # EXPLICIT CHECK FOR PATH TRAVERSAL ATTEMPTS (to satisfy static analysis tools)
    # Define dangerous patterns that could lead to path traversal
    # We check for patterns that could escape the base directory when joined
    
    # Check for absolute Unix paths (starting with /)
    if config_path.startswith('/'):
        print(f"[WARN] Potentially dangerous path detected: {config_path}")
        return _DEV_OPTIMIZER_ROOT / "configs" / "system-config.json"
    
    # Check for parent directory traversal patterns
    if '..' in config_path:
        print(f"[WARN] Potentially dangerous path detected: {config_path}")
        return _DEV_OPTIMIZER_ROOT / "configs" / "system-config.json"
    
    # Additional check for Windows drive paths (e.g., "C:\\" or "D:/")
    if len(config_path) >= 2 and config_path[1] == ':':
        print(f"[WARN] Potentially dangerous path detected: {config_path}")
        return _DEV_OPTIMIZER_ROOT / "configs" / "system-config.json"
    
    # Convert to Path object for safe manipulation
    try:
        # Construct the full path by joining the base directory with the user-provided path
        # Using Path.joinpath() is safer than string concatenation
        full_path = (_DEV_OPTIMIZER_ROOT / config_path).resolve()
        
        # CRITICAL SECURITY CHECK: Verify the resolved path is still within the base directory
        # This prevents path traversal attacks like "../../etc/passwd"
        try:
            full_path.relative_to(_DEV_OPTIMIZER_ROOT)
            # If we get here, the path is within the allowed directory
            return full_path
        except ValueError:
            # The resolved path is outside the base directory - potential path traversal attempt
            print(f"[WARN] Path traversal attempt blocked: {config_path}")
            # Return a safe default path within the allowed directory
            return _DEV_OPTIMIZER_ROOT / "configs" / "system-config.json"
            
    except Exception:
        # If any other error occurs (e.g., invalid path characters), use safe default
        print(f"[WARN] Invalid config path: {config_path}, using default")
        return _DEV_OPTIMIZER_ROOT / "configs" / "system-config.json"

def load_configuration(config_path: str = "configs/system-config.json") -> Dict[str, Any]:
    """
    Loads the system configuration from JSON file.
    
    Args:
        config_path: Path to the configuration file.
        
    Returns:
        Dict[str, Any]: The loaded configuration object.
    """
    global _dev_optimizer_config
    
    try:
        full_path = get_config_path(config_path)
        
        if not full_path.exists():
            print(f"[WARN] Configuration file not found: {full_path}")
            print("[INFO] Creating default configuration...")
            new_default_configuration(config_path)
        
        with open(full_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        # Validate configuration structure
        is_valid = test_configuration(config)
        if not is_valid:
            print("[WARN] Configuration validation failed. Using default values.")
            config = get_default_configuration()
        
        # Store in global variable
        _dev_optimizer_config = config
        
        print(f"[INFO] Configuration loaded successfully from: {full_path}")
        return config
        
    except Exception as e:
        print(f"[ERROR] Failed to load configuration: {e}")
        
        # Return default configuration as fallback
        default_config = get_default_configuration()
        _dev_optimizer_config = default_config
        return default_config

def get_configuration() -> Dict[str, Any]:
    """
    Gets the current system configuration.
    
    Returns:
        Dict[str, Any]: The system configuration object.
    """
    global _dev_optimizer_config
    
    if _dev_optimizer_config is None:
        _dev_optimizer_config = load_configuration()
    
    # Ensure we return a dict, not a list
    if isinstance(_dev_optimizer_config, list):
        print("[WARN] Configuration loaded as array, taking first element")
        return _dev_optimizer_config[0] if _dev_optimizer_config else {}
    
    return _dev_optimizer_config

def get_config_value(path: str, default_value: Any = None) -> Any:
    """
    Gets a specific configuration value using dot notation.
    
    Args:
        path: Dot notation path to the configuration value (e.g., "ollama.concurrency").
        default_value: Default value to return if the path is not found.
        
    Returns:
        Any: The configuration value or default value.
    """
    try:
        config = get_configuration()
        
        # Split path by dots and navigate through the object
        path_parts = path.split('.')
        current = config
        
        for part in path_parts:
            if isinstance(current, dict) and part in current:
                current = current[part]
            else:
                print(f"[WARN] Configuration path not found: {path}")
                return default_value
        
        return current
        
    except Exception as e:
        print(f"[ERROR] Error getting configuration value '{path}': {e}")
        return default_value

def test_configuration(config: Dict[str, Any]) -> bool:
    """
    Validates the configuration object structure.
    
    Args:
        config: Configuration object to validate.
        
    Returns:
        bool: True if configuration is valid, false otherwise.
    """
    try:
        # Check for required top-level properties
        required_properties = ['system', 'ollama', 'onedrive', 'development']
        
        for prop in required_properties:
            if prop not in config:
                print(f"[WARN] Missing required configuration property: {prop}")
                return False
        
        # Check system configuration
        if 'logLevel' not in config.get('system', {}):
            print("[WARN] Missing system.logLevel configuration")
            return False
        
        # Check ollama configuration
        ollama_config = config.get('ollama', {})
        concurrency = ollama_config.get('concurrency')
        if concurrency is None or not isinstance(concurrency, int) or concurrency < 1:
            print("[WARN] Invalid ollama.concurrency configuration")
            return False
        
        return True
        
    except Exception as e:
        print(f"[ERROR] Configuration validation error: {e}")
        return False

def get_default_configuration() -> Dict[str, Any]:
    """
    Gets the default configuration object.
    
    Returns:
        Dict[str, Any]: Default configuration object.
    """
    return {
        "system": {
            "name": "DevOptimizer System",
            "version": "2.0.0",
            "logLevel": "INFO",
            "backupLocation": "D:/DevOptimizer/backups",
            "logsLocation": "D:/DevOptimizer/logs",
            "maxLogFiles": 10,
            "maxLogSize": "10MB",
            "autoCleanup": True,
            "cleanupDays": 30
        },
        "ollama": {
            "serverUrl": "http://127.0.0.1:11434",
            "port": 11434,
            "autoPort": True,
            "maxPorts": 10,
            "host": "127.0.0.1",
            "defaultModels": ["qwen2.5-coder:7b", "llama2:7b", "codellama:7b"],
            "preferredModels": ["qwen2.5-coder:7b", "llama2:7b"],
            "concurrency": 2,
            "maxLoaded": 2,
            "timeoutSeconds": 300,
            "keepAliveSec": 600,
            "retryAttempts": 3,
            "backoffDelay": 0.5,
            "enableMultiModel": True,
            "enableStreaming": True,
            "maxPromptLength": 8000,
            "maxResponseLength": 512,
            "maxContextLength": 2048,
            "laptopOptimization": True,
            "autoStart": True,
            "healthCheckInterval": 60,
            "logLevel": "INFO",
            "metricsEnabled": True,
            "metricsLogPath": "logs/ollama"
        },
        "onedrive": {
            "accounts": [
                {
                    "name": "Personal",
                    "path": f"C:/Users/{os.environ.get('USERNAME', 'User')}/OneDrive"
                }
            ],
            "syncInterval": 300,
            "backupEnabled": True
        },
        "development": {
            "nodejs": {
                "version": "18.x",
                "globalPackages": ["@angular/cli", "@vue/cli", "typescript"]
            },
            "python": {
                "version": "3.11",
                "globalPackages": ["jupyter", "tensorflow"]
            }
        },
        "security": {
            "enableFirewall": True,
            "enableDefender": True,
            "scanInterval": 86400
        },
        "user": {
            "preferences": {
                "theme": "dark",
                "language": "en",
                "notifications": True
            }
        }
    }

def new_default_configuration(config_path: str = "configs/system-config.json") -> None:
    """
    Creates a new default configuration file.
    
    Args:
        config_path: Path where to create the configuration file.
    """
    try:
        default_config = get_default_configuration()
        save_configuration(default_config, config_path)
        print(f"[INFO] Default configuration created: {config_path}")
    except Exception as e:
        print(f"[ERROR] Failed to create default configuration: {e}")

def save_configuration(config: Optional[Dict[str, Any]] = None, 
                      config_path: str = "configs/system-config.json") -> None:
    """
    Saves the configuration to the JSON file.
    
    Args:
        config: Configuration object to save. If not provided, uses the global config.
        config_path: Path to save the configuration file.
    """
    global _dev_optimizer_config
    
    try:
        if config is None:
            config = get_configuration()
        
        full_path = get_config_path(config_path)
        
        # Ensure directory exists
        config_dir = full_path.parent
        config_dir.mkdir(parents=True, exist_ok=True)
        
        # Convert to JSON with proper formatting
        json_content = json.dumps(config, indent=2)
        
        # Save to file
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(json_content)
        
        print(f"[INFO] Configuration saved to: {full_path}")
        
    except Exception as e:
        print(f"[ERROR] Failed to save configuration: {e}")

def reset_configuration() -> None:
    """
    Resets the configuration to default values.
    """
    global _dev_optimizer_config
    
    try:
        default_config = get_default_configuration()
        _dev_optimizer_config = default_config
        save_configuration(default_config)
        print("[INFO] Configuration reset to default values")
    except Exception as e:
        print(f"[ERROR] Failed to reset configuration: {e}")

# For testing purposes
if __name__ == "__main__":
    # Simple test when run directly
    config = load_configuration()
    print("Configuration loaded:")
    print(json.dumps(config, indent=2))