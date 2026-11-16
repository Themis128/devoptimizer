"""Port of scripts/wait-docker.ps1 — poll `docker info` until the
engine answers, 30 x 2s (60s max). Exit 0 ready / 1 timeout.
"""
import subprocess
import sys
import time


def main():
    for _ in range(30):
        r = subprocess.run(["docker", "info"],
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
        if r.returncode == 0:
            print("Docker engine ready")
            return 0
        time.sleep(2)
    print("Docker engine not ready after 60s")
    return 1


if __name__ == "__main__":
    sys.exit(main())
