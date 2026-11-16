"""Port of scripts/sshd-repair.ps1 — diagnose + repair Windows OpenSSH
Server: config test, ProgramData\\ssh ACL repair (vendor script /
icacls), host-key ownership, SCM recovery hardening, DefaultShell pin,
start+verify with logs-dir quarantine escalation, optional
\\DevOptimizer\\Sshd-Watch registration.
"""
import ctypes
import datetime
import os
import re
import subprocess
import sys
import time
from pathlib import Path

LOG = Path("D:" + chr(92) + "DevOptimizer" + chr(92) + "logs"
           + chr(92) + "sshd-repair.log")


def log(m):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    line = time.strftime("%Y-%m-%d %H:%M:%S") + " " + m
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")
    print(m)


def elevated():
    return bool(ctypes.windll.shell32.IsUserAnAdmin())


def svc_status():
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "(Get-Service sshd -ErrorAction"
                        " SilentlyContinue) | Select-Object Status,"
                        "StartType | ConvertTo-Json"],
                       capture_output=True, text=True)
    try:
        import json
        return json.loads(r.stdout) if r.stdout.strip() else None
    except ValueError:
        return None


def svc_running(svc):
    # Windows PS serializes ServiceControllerStatus numerically
    # (4=Running); PS7 emits the name string.
    return svc is not None and str(svc.get("Status")) in \
        ("Running", "4")


def ps(cmd):
    return subprocess.run(["powershell", "-NoProfile", "-Command",
                           cmd], capture_output=True, text=True)


def main():
    register = "--register-task" in sys.argv
    dry = "--dry-run" in sys.argv
    elev = elevated()
    log(f"=== sshd-repair (elevated={elev} dryRun={dry}) ===")

    svc = svc_status()
    if not svc:
        log("[sshd] service not installed - nothing to do")
        return 0
    log(f"[sshd] state={svc.get('Status')} startType="
        f"{svc.get('StartType')}")

    # 1. config syntax test
    sshd = Path(os.environ.get("WINDIR", r"C:\Windows")
                + chr(92) + "System32" + chr(92) + "OpenSSH"
                + chr(92) + "sshd.exe")
    sshd_exe = str(sshd) if sshd.exists() else None
    if not sshd_exe:
        import shutil
        sshd_exe = shutil.which("sshd.exe")
    if sshd_exe:
        r = subprocess.run([sshd_exe, "-t"], capture_output=True,
                           text=True)
        cfg = r.stdout + r.stderr
        if r.returncode != 0:
            if not elev and "no hostkeys" in cfg:
                log("[config] indeterminate non-elevated (host keys"
                    " unreadable by design) - continuing")
            else:
                first = (cfg.splitlines() or ["?"])[0]
                log(f"[config] sshd -t FAILED: {first}")
                log("[config] fix sshd_config first (common: empty"
                    " DenyUsers/AllowUsers value); aborting")
                return 1
        else:
            log("[config] OK (sshd -t clean)")
    else:
        log("[config] sshd.exe not found - skipping syntax test")

    # 2. ACL repair (elevated only)
    fix_script = Path(os.environ.get("WINDIR", r"C:\Windows")
                      + chr(92) + "System32" + chr(92) + "OpenSSH"
                      + chr(92) + "FixHostFilePermissions.ps1")
    logs_path = Path(r"C:\ProgramData\ssh\logs")
    if not elev:
        log("[acl] not elevated - skipping ProgramData\\ssh repair"
            " (run via AdminCleanupTask)")
    elif fix_script.exists():
        if not dry:
            r = subprocess.run(["powershell", "-NoProfile",
                                "-ExecutionPolicy", "Bypass", "-File",
                                str(fix_script), "-Confirm:$false"],
                               capture_output=True, text=True)
            tail = (r.stdout + r.stderr).splitlines()[-2:]
            log("[acl] FixHostFilePermissions ran:"
                f" {' | '.join(tail)}")
        else:
            log("[acl] would run FixHostFilePermissions.ps1"
                " (dry-run)")
    elif logs_path.exists():
        if not dry:
            subprocess.run(["icacls", str(logs_path), "/inheritance:r",
                            "/grant", "SYSTEM:(OI)(CI)F",
                            "Administrators:(OI)(CI)F"],
                           capture_output=True)
            log("[acl] logs dir re-ACL'd manually (vendor script"
                " absent)")
        else:
            log(f"[acl] would re-ACL {logs_path} to SYSTEM+Admins"
                " only (dry-run)")

    # 2b. host-key ownership + ACL hardening
    if elev and not dry:
        for k in Path(r"C:\ProgramData\ssh").glob("ssh_host_*_key"):
            if k.suffix == ".pub":
                continue
            subprocess.run(["icacls", str(k), "/setowner",
                            "NT AUTHORITY" + chr(92) + "SYSTEM"],
                           capture_output=True)
            subprocess.run(["icacls", str(k), "/inheritance:r",
                            "/grant", "NT AUTHORITY" + chr(92)
                            + "SYSTEM:(F)",
                            "BUILTIN" + chr(92)
                            + "Administrators:(F)"],
                           capture_output=True)
            log(f"[acl] hardened host key {k.name} (owner=SYSTEM,"
                " SYSTEM+Admins only)")

    # 3. SCM recovery hardening
    r = subprocess.run(["sc.exe", "qfailure", "sshd"],
                       capture_output=True, text=True)
    if "RESTART" not in (r.stdout + r.stderr):
        if elev and not dry:
            subprocess.run(
                ["sc.exe", "failure", "sshd", "reset=86400",
                 "actions=restart/60000/restart/60000/restart/60000"],
                capture_output=True)
            log("[scm] recovery actions set: restart x3 @60s, reset"
                " after 1d")
        else:
            log("[scm] no recovery actions configured - need"
                " elevation to set (restart x3 @60s)")
    else:
        log("[scm] recovery actions already configured")

    # 3b. DefaultShell registry pin
    if elev and not dry:
        shell = os.environ.get("WINDIR", r"C:\Windows") + chr(92) \
            + "System32" + chr(92) + "WindowsPowerShell" + chr(92) \
            + "v1.0" + chr(92) + "powershell.exe"
        import winreg
        try:
            key = winreg.CreateKey(winreg.HKEY_LOCAL_MACHINE,
                                   r"SOFTWARE\OpenSSH")
            try:
                cur, _ = winreg.QueryValueEx(key, "DefaultShell")
            except FileNotFoundError:
                cur = None
            if cur != shell:
                winreg.SetValueEx(key, "DefaultShell", 0,
                                  winreg.REG_SZ, shell)
                winreg.SetValueEx(key, "DefaultShellCommandOption",
                                  0, winreg.REG_SZ, "/c")
                log(f"[shell] DefaultShell pinned -> {shell}")
            else:
                log(f"[shell] DefaultShell already {shell}")
            key.Close()
        except OSError as e:
            log(f"[shell] registry pin failed: {e}")

    # 4. start + verify
    svc2 = svc_status()
    if svc2 and not svc_running(svc2):
        if elev and not dry:
            ps("Start-Service sshd -ErrorAction SilentlyContinue")
            time.sleep(2)
        else:
            log(f"[start] sshd is {svc2.get('Status')} - need"
                " elevation to start (or wait for SCM)")
    svc2 = svc_status()
    if svc2 and not svc_running(svc2) and elev and not dry:
        if logs_path.exists():
            bak = str(logs_path) + ".bak-" \
                + datetime.datetime.now().strftime("%Y%m%d%H%M%S")
            try:
                logs_path.rename(bak)
                log(f"[escalate] crash-loop: moved logs dir -> {bak};"
                    " retrying start")
                ps("Start-Service sshd -ErrorAction"
                   " SilentlyContinue")
                time.sleep(3)
                svc2 = svc_status()
            except OSError as e:
                log(f"[escalate] logs-dir move failed: {e}")
    if svc_running(svc2):
        r = subprocess.run(["netstat", "-ano"], capture_output=True,
                           text=True)
        listening = bool(re.search(r":22\s+.*LISTENING", r.stdout))
        log(f"[verify] sshd Running; port22 listening: {listening}")
    else:
        log(f"[verify] sshd still {svc2.get('Status') if svc2 else '?'}")
        if elev and not dry and sshd_exe:
            log("[diag] running sshd -d on :22222 for 6s to capture"
                " the failure...")
            proc = subprocess.Popen([sshd_exe, "-d", "-p", "22222"],
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT,
                                    text=True)
            try:
                out, _ = proc.communicate(timeout=6)
            except subprocess.TimeoutExpired:
                proc.kill()
                out, _ = proc.communicate()
            for l in (out or "").splitlines()[-12:]:
                log(f"[diag] {l}")
            diag_script = Path("D:" + chr(92) + "DevOptimizer"
                               + chr(92) + "scripts" + chr(92)
                               + "sshd-system-diag.ps1")
            diag_out = Path("D:" + chr(92) + "DevOptimizer" + chr(92)
                            + "logs" + chr(92)
                            + "sshd-system-diag.log")
            if diag_script.exists():
                try:
                    ps("Register-ScheduledTask -TaskPath"
                       " '\\DevOptimizer\\' -TaskName"
                       " 'Sshd-SystemDiag-Temp' -Action"
                       " (New-ScheduledTaskAction -Execute"
                       " 'C:\\Windows\\System32\\conhost.exe'"
                       " -Argument '--headless powershell.exe"
                       " -NoProfile -ExecutionPolicy Bypass -File \""
                       + str(diag_script)
                       + "\"') -Principal (New-ScheduledTaskPrincipal"
                       " -UserId 'SYSTEM' -LogonType ServiceAccount"
                       " -RunLevel Highest) -Force | Out-Null")
                    diag_out.unlink(missing_ok=True)
                    ps("Start-ScheduledTask -TaskPath"
                       " '\\DevOptimizer\\' -TaskName"
                       " 'Sshd-SystemDiag-Temp'")
                    waited = 0
                    while not diag_out.exists() and waited < 30:
                        time.sleep(2)
                        waited += 2
                    time.sleep(15)
                    if diag_out.exists():
                        for l in diag_out.read_text(
                                errors="replace").splitlines()[-40:]:
                            log(f"[sysdiag] {l}")
                    else:
                        log("[sysdiag] no output produced (task may"
                            " have failed to launch)")
                except OSError as e:
                    log(f"[sysdiag] failed: {e}")
                finally:
                    ps("Unregister-ScheduledTask -TaskPath"
                       " '\\DevOptimizer\\' -TaskName"
                       " 'Sshd-SystemDiag-Temp' -Confirm:$false"
                       " -ErrorAction SilentlyContinue")

    # 5. self-register elevated watch task
    if register:
        if not elev:
            log("[task] --register-task needs elevation; bootstrap"
                " via: schtasks /run /tn AdminCleanupTask")
            return 3
        if dry:
            log("[task] would register \\DevOptimizer\\Sshd-Watch"
                " (dry-run)")
            return 0
        ps("$act = New-ScheduledTaskAction -Execute"
           " 'C:\\Windows\\System32\\conhost.exe' -Argument"
           " '--headless powershell.exe -NoProfile -ExecutionPolicy"
           " Bypass -File"
           " \"D:\\DevOptimizer\\scripts\\sshd-repair.ps1\"'\n"
           "$trg = New-ScheduledTaskTrigger -Once -At (Get-Date)"
           " -RepetitionInterval (New-TimeSpan -Minutes 15)\n"
           "$pri = New-ScheduledTaskPrincipal -UserId $env:USERNAME"
           " -LogonType Interactive -RunLevel Highest\n"
           "Register-ScheduledTask -TaskPath '\\DevOptimizer\\'"
           " -TaskName 'Sshd-Watch' -Action $act -Trigger $trg"
           " -Principal $pri -Force | Out-Null")
        log("[task] \\DevOptimizer\\Sshd-Watch registered (15 min,"
            " headless)")
    log("=== sshd-repair done ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
