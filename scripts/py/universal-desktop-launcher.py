"""Port of tools/Old-Launchers/UNIVERSAL-DESKTOP-LAUNCHER.bat —
opens the DevOptimizer working launcher at D:\\DevOptimizer.
"""
import subprocess
import sys


def main():
    r = subprocess.run(
        ["cmd", "/c", "D:" + chr(92) + "DevOptimizer" + chr(92)
         + "DEVOPTIMIZER-WORKING-LAUNCHER.bat"] + sys.argv[1:])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
