# 🚀 DevOptimizer Hub v4.0 - Quick Start

## What is DevOptimizer Hub?

A centralized system optimization suite where:
- **PowerShell scripts (.ps1)** stay in `D:\DevOptimizer` (the hub)
- **BAT files** can be moved anywhere on your PC
- **BAT files automatically find and connect** to the hub

## 📁 Structure

```
D:\DevOptimizer\              (Fixed Hub Location)
├── scripts\                  (PowerShell modules)
├── logs\                     (Operation logs)
├── config\                   (Settings)
└── Portable-*.bat           (Can be moved anywhere)

Your Desktop\                 (Example - BAT files work anywhere)
├── MyOptimizer.bat          (Connects to D:\DevOptimizer)
└── InsiderTool.bat          (Connects to D:\DevOptimizer)
```

## 🚀 Quick Setup

1. **Install Hub** (as Administrator):
   ```batch
   D:\DevOptimizer\Hub-Installer.bat
   ```

2. **Use Portable Tools**:
   ```batch
   # These work from anywhere:
   Portable-DevOptimizer.bat
   Portable-InsiderAutomation.bat
   ```

## 🎯 Main Features

- **System Optimization**: Performance tuning, cleanup
- **Cursor AI Setup**: Latest 2024/2025 AI development features
- **Windows Insider**: Channel management, automation
- **Development Tools**: Nuxt 4, Docker, VS Code optimization

## 📖 Usage

1. Run any portable BAT file from anywhere
2. It automatically finds the hub at `D:\DevOptimizer`
3. Executes PowerShell scripts from the hub
4. All results logged to hub directories

## 🔧 How It Works

**Hub Discovery Process:**
1. Environment variable `DEVOPTIMIZER_HUB`
2. Registry: `HKLM\SOFTWARE\DevOptimizer`
3. Default location: `D:\DevOptimizer`
4. Search common paths

**Connection Flow:**
```
BAT File (anywhere) → Find Hub → Execute PowerShell → Return Results
```

That's it! The hub system is now complete and production-ready! 🎉
