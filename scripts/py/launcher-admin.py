"""Port of tools/Variants/launcher-Admin.bat — delegates to
D:\DevOptimizer\00-LAUNCHER.bat.
"""
import subprocess
import sys


def main():
    r = subprocess.run(["cmd", "/c",
                        "D:" + chr(92) + "DevOptimizer" + chr(92)
                        + "00-LAUNCHER.bat"] + sys.argv[1:])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
