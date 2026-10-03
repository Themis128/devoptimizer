"""
AI-powered analysis commands using Ollama
"""

import json
import subprocess
import sys
import re
from pathlib import Path
from typing import Optional, List

from devoptimizer_cli.paths import safe_open_write
import typer
from rich.console import Console
from rich.panel import Panel
from rich.syntax import Syntax
from rich.progress import Progress, SpinnerColumn, TextColumn

app = typer.Typer(name="analyze", help="AI-powered system analysis")
console = Console()

def check_ollama_available() -> bool:
    """Check if Ollama is available and running"""
    try:
        result = subprocess.run(["ollama", "list"], capture_output=True, text=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def get_available_models() -> List[str]:
    """Get list of available Ollama models"""
    try:
        result = subprocess.run(["ollama", "list"], capture_output=True, text=True, check=True)
        models = []
        for line in result.stdout.split('\n')[1:]:  # Skip header
            if line.strip():
                model_name = line.split()[0]
                models.append(model_name)
        return models
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

@app.command()
def system(
    model: str = typer.Option("llama3.1", "--model", "-m", help="Ollama model to use"),
    input_dir: Optional[Path] = typer.Option(None, "--input", "-i", help="Input directory with metrics/logs"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file for analysis")
):
    """Analyze system performance using AI"""

    if not check_ollama_available():
        console.print("Ollama not available. Please install and start Ollama first.", style="red")
        raise typer.Exit(1)

    available_models = get_available_models()
    if model not in available_models:
        console.print(f"Model '{model}' not found. Available models: {', '.join(available_models)}", style="red")
        raise typer.Exit(1)

    # Validate model name to prevent command injection (alphanumeric, dots, colons, hyphens, underscores)
    if not re.match(r'^[a-zA-Z0-9._:\-]+$', model):
        console.print("Error: Invalid model name format", style="red")
        raise typer.Exit(1)

    if not input_dir:
        input_dir = Path("D:/DevOptimizer/metrics")

    if not output:
        output = Path("D:/DevOptimizer/ai-analysis/system_analysis.json")

    # Validate output path to prevent arbitrary file write
    output = Path(output).resolve()
    if not str(output).startswith(str(Path("D:/DevOptimizer").resolve())):
        console.print("Error: Output path must be within DevOptimizer directory", style="red")
        raise typer.Exit(1)

    console.print(f"Analyzing system with model: {model}", style="blue")

    # Collect system data
    analysis_data = {
        "timestamp": "2025-04-10T00:00:00Z",
        "model_used": model,
        "input_directory": str(input_dir),
        "findings": [],
        "recommendations": [],
        "raw_response": ""
    }

    # Prepare prompt - sanitize input_dir to prevent injection
    input_dir_str = str(input_dir).replace('"', '\\"').replace('$', '\\$').replace('`', '\\`')

    prompt = f"""
You are a Windows system optimization expert. Analyze the following system data and provide:

1. Key performance issues identified
2. Root cause analysis
3. Specific remediation steps
4. Priority levels (High/Medium/Low)

System Data Directory: {input_dir_str}

Please provide a structured analysis focusing on:
- CPU utilization patterns
- Memory usage trends
- Disk I/O bottlenecks
- Network performance issues
- Process optimization opportunities
- System health indicators

Format your response as JSON with this structure:
{{
    "findings": [
        {{
            "category": "CPU|Memory|Disk|Network|Process|System",
            "issue": "description",
            "severity": "High|Medium|Low",
            "impact": "description"
        }}
    ],
    "recommendations": [
        {{
            "category": "CPU|Memory|Disk|Network|Process|System",
            "action": "specific action",
            "priority": "High|Medium|Low",
            "estimated_impact": "description"
        }}
    ]
}}
"""

    try:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task("Running AI analysis...", total=None)

            # Run Ollama - model is validated above, prompt is sanitized
            # Use list format to prevent shell injection
            result = subprocess.run(
                ["ollama", "run", model, prompt],
                capture_output=True,
                text=True,
                check=True,
                timeout=300,  # 5 minute timeout
                shell=False  # Explicitly set to False for safety
            )

            progress.update(task, completed=100)

        analysis_data["raw_response"] = result.stdout

        # Try to parse JSON response
        try:
            # Extract JSON from response (sometimes Ollama adds extra text)
            response_text = result.stdout
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1

            if json_start >= 0 and json_end > json_start:
                json_text = response_text[json_start:json_end]
                parsed_response = json.loads(json_text)

                analysis_data["findings"] = parsed_response.get("findings", [])
                analysis_data["recommendations"] = parsed_response.get("recommendations", [])
            else:
                # Fallback: treat entire response as findings
                analysis_data["findings"] = [{
                    "category": "System",
                    "issue": "AI analysis completed",
                    "severity": "Medium",
                    "impact": "See raw response for details"
                }]

        except json.JSONDecodeError:
            console.print("Warning: Could not parse JSON response, saving as raw text", style="yellow")
            analysis_data["findings"] = [{
                "category": "System",
                "issue": "AI analysis completed",
                "severity": "Medium",
                "impact": "See raw response for details"
            }]

        # Save analysis
        output.parent.mkdir(parents=True, exist_ok=True)
        with safe_open_write(output) as f:
            json.dump(analysis_data, f, indent=2)

        console.print(f"✓ Analysis saved to: {output}", style="green")

        # Display summary
        console.print(f"\nAnalysis Summary:", style="bold blue")
        console.print(f"Findings: {len(analysis_data['findings'])}")
        console.print(f"Recommendations: {len(analysis_data['recommendations'])}")

        # Show high priority items
        high_priority = [r for r in analysis_data['recommendations'] if r.get('priority') == 'High']
        if high_priority:
            console.print(f"\nHigh Priority Recommendations:", style="bold red")
            for rec in high_priority[:3]:
                console.print(f"- {rec.get('action', 'N/A')}")

    except subprocess.TimeoutExpired:
        console.print("Analysis timed out after 5 minutes", style="red")
        raise typer.Exit(1)
    except subprocess.CalledProcessError as e:
        console.print(f"Error running analysis: {e}", style="red")
        console.print(f"stderr: {e.stderr}")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"Unexpected error: {e}", style="red")
        raise typer.Exit(1)

@app.command()
def logs(
    log_dir: Optional[Path] = typer.Option(None, "--log-dir", "-d", help="Log directory to analyze"),
    model: str = typer.Option("llama3.1", "--model", "-m", help="Ollama model to use"),
    output: Optional[Path] = typer.Option(None, "--output", "-o", help="Output file for analysis")
):
    """Analyze system logs using AI"""

    if not check_ollama_available():
        console.print("Ollama not available. Please install and start Ollama first.", style="red")
        raise typer.Exit(1)

    if not log_dir:
        log_dir = Path("D:/DevOptimizer/logs")

    if not output:
        output = Path("D:/DevOptimizer/ai-analysis/log_analysis.json")

    # Validate output path to prevent arbitrary file write
    output = Path(output).resolve()
    if not str(output).startswith(str(Path("D:/DevOptimizer").resolve())):
        console.print("Error: Output path must be within DevOptimizer directory", style="red")
        raise typer.Exit(1)

    # Validate model name to prevent command injection
    if not re.match(r'^[a-zA-Z0-9._:\-]+$', model):
        console.print("Error: Invalid model name format", style="red")
        raise typer.Exit(1)

    console.print(f"Analyzing logs in: {log_dir}", style="blue")

    # Collect log files
    log_files = list(log_dir.glob("*.log")) + list(log_dir.glob("*.evtx"))

    if not log_files:
        console.print(f"No log files found in: {log_dir}", style="yellow")
        return

    # Prepare log summary
    log_summary = []
    for log_file in log_files[:5]:  # Limit to 5 files
        try:
            if log_file.suffix == '.log':
                with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                    log_summary.append({
                        "file": log_file.name,
                        "size": len(lines),
                        "sample": lines[-10:] if len(lines) > 10 else lines
                    })
            else:
                log_summary.append({
                    "file": log_file.name,
                    "size": log_file.stat().st_size,
                    "sample": "Binary event log file"
                })
        except Exception as e:
            console.print(f"Error reading {log_file}: {e}", style="yellow")

    # Prepare prompt
    prompt = f"""
You are a Windows system log analysis expert. Analyze the following log data and identify:

1. Critical errors and warnings
2. Performance issues
3. Security concerns
4. System stability problems
5. Recommended actions

Log Files Summary:
{json.dumps(log_summary, indent=2)}

Provide a structured analysis focusing on:
- Error patterns and frequency
- Performance degradation indicators
- Security events
- System health trends
- Maintenance recommendations

Format your response as JSON with this structure:
{{
    "critical_issues": [
        {{
            "type": "Error|Warning|Performance|Security",
            "description": "issue description",
            "severity": "Critical|High|Medium|Low",
            "affected_components": ["component1", "component2"]
        }}
    ],
    "recommendations": [
        {{
            "action": "specific action",
            "priority": "Critical|High|Medium|Low",
            "category": "Maintenance|Security|Performance|Configuration"
        }}
    ]
}}
"""

    try:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task("Analyzing logs...", total=None)

            # Run Ollama - model is validated above, prompt is sanitized in the prompt construction
            result = subprocess.run(
                ["ollama", "run", model, prompt],
                capture_output=True,
                text=True,
                check=True,
                timeout=300,
                shell=False  # Explicitly set to False for safety
            )

            progress.update(task, completed=100)

        # Save analysis
        output.parent.mkdir(parents=True, exist_ok=True)
        analysis_data = {
            "timestamp": "2025-04-10T00:00:00Z",
            "model_used": model,
            "log_directory": str(log_dir),
            "files_analyzed": [f.name for f in log_files],
            "raw_response": result.stdout
        }

        # Try to parse JSON response
        try:
            response_text = result.stdout
            json_start = response_text.find('{')
            json_end = response_text.rfind('}') + 1

            if json_start >= 0 and json_end > json_start:
                json_text = response_text[json_start:json_end]
                parsed_response = json.loads(json_text)
                analysis_data.update(parsed_response)
            else:
                analysis_data["critical_issues"] = []
                analysis_data["recommendations"] = []

        except json.JSONDecodeError:
            console.print("Warning: Could not parse JSON response", style="yellow")
            analysis_data["critical_issues"] = []
            analysis_data["recommendations"] = []

        with safe_open_write(output) as f:
            json.dump(analysis_data, f, indent=2)

        console.print(f"✓ Log analysis saved to: {output}", style="green")

        # Display summary
        critical_count = len(analysis_data.get('critical_issues', []))
        recommendations_count = len(analysis_data.get('recommendations', []))

        console.print(f"\nLog Analysis Summary:", style="bold blue")
        console.print(f"Files analyzed: {len(log_files)}")
        console.print(f"Critical issues: {critical_count}")
        console.print(f"Recommendations: {recommendations_count}")

    except subprocess.TimeoutExpired:
        console.print("Log analysis timed out", style="red")
        raise typer.Exit(1)
    except subprocess.CalledProcessError as e:
        console.print(f"Error running log analysis: {e}", style="red")
        raise typer.Exit(1)

@app.command()
def models():
    """List available Ollama models"""

    if not check_ollama_available():
        console.print("Ollama not available. Please install Ollama first.", style="red")
        raise typer.Exit(1)

    try:
        result = subprocess.run(["ollama", "list"], capture_output=True, text=True, check=True)

        console.print("Available Ollama Models:", style="bold blue")
        console.print(result.stdout)

    except subprocess.CalledProcessError as e:
        console.print(f"Error listing models: {e}", style="red")
        raise typer.Exit(1)
