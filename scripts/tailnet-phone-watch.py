#!/usr/bin/env python3
"""Tailnet phone-watchdog for github-omv (always-on node).

Runs every 5 min via cron. Covers the gap left by the office-1 watchdog:
if office-1-win-exitnode (the phone's exit node AND the watchdog host)
dies, this agent still alerts via Telegram and fails the phone's internet
over to the current network (exit node 'none') or back to office-1.

Checks:
  1. office-1-win-exitnode online? -> Telegram on transitions.
  2. Phone internet (ping cloudflare.com via adb) -> exit-node failover
     chain office-1-win-exitnode -> none.

Phone adb endpoints tried in order:
  192.168.1.77:5555  (office LAN - always allowed)
  100.84.31.85:5555  (tailnet - needs ACL grant for tagged src -> :5555)

State: ~/tailnet-watch/state.json   Token: ~/tailnet-watch/tg-token (600)
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

HOME = os.path.expanduser("~")
DIR = os.path.join(HOME, "tailnet-watch")
STATE = os.path.join(DIR, "state.json")
TOKEN_FILE = os.path.join(DIR, "tg-token")
CHAT_ID = "7017840434"

ADB = "adb"  # /usr/bin/adb installed via apt (aarch64)
PHONE_ENDPOINTS = ["192.168.1.77:5555", "100.84.31.85:5555"]
OFFICE_TS_IP = "100.83.120.93"
OFFICE_NAME = "office-1-win-exitnode"
PKG = "com.tailscale.ipn"
EXIT_CHAIN = [OFFICE_NAME, "none"]


def sh(cmd, timeout=30):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                          timeout=timeout).stdout


def adb(endpoint, *args, timeout=30):
    return subprocess.run([ADB, "-s", endpoint, *args], capture_output=True,
                          text=True, timeout=timeout).stdout


def log(msg):
    line = "%s %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(DIR, "watch.log"), "a") as f:
        f.write(line + "\n")


def notify(text):
    try:
        token = open(TOKEN_FILE).read().strip()
    except OSError:
        log("tg token missing")
        return
    try:
        body = json.dumps({"chat_id": CHAT_ID, "text": text}).encode()
        req = urllib.request.Request(
            "https://api.telegram.org/bot%s/sendMessage" % token,
            data=body, headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=15)
        log("tg sent: " + text[:80])
    except Exception as e:
        log("tg failed: %s" % e)


def load_state():
    try:
        return json.load(open(STATE))
    except Exception:
        return {}


def save_state(st):
    os.makedirs(DIR, exist_ok=True)
    json.dump(st, open(STATE, "w"), indent=1)


def office_online():
    out = sh("tailscale status --json", timeout=20)
    try:
        st = json.loads(out)
    except Exception:
        return None
    for p in (st.get("Peer") or {}).values():
        if OFFICE_TS_IP in (p.get("TailscaleIPs") or []):
            return bool(p.get("Online"))
    return None


def adb_devices():
    out = sh("%s devices" % ADB)
    return set(re.findall(r"^(\S+:\d+)\s+device\s*$", out, re.M))


def try_connect(ep):
    try:
        sh("%s connect %s" % (ADB, ep), timeout=12)
    except Exception:
        pass


def find_phone():
    devs = adb_devices()
    for ep in PHONE_ENDPOINTS:
        if ep in devs:
            return ep
    for ep in PHONE_ENDPOINTS:
        try_connect(ep)
    devs = adb_devices()
    for ep in PHONE_ENDPOINTS:
        if ep in devs:
            return ep
    return None


def phone_inet_ok(endpoint):
    out = adb(endpoint, "shell", "ping", "-c", "1", "-W", "3",
              "cloudflare.com", timeout=15)
    return "1 received" in out


def ui_xml(endpoint):
    adb(endpoint, "shell", "uiautomator", "dump", "/sdcard/tw-ui.xml")
    return adb(endpoint, "shell", "cat", "/sdcard/tw-ui.xml", timeout=20)


def current_exit_node(endpoint):
    xml = ui_xml(endpoint)
    nodes = []
    for m in re.finditer(
            r'<node[^>]*text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
            xml):
        t = m.group(1)
        if t.strip():
            nodes.append((int(m.group(3)), int(m.group(5)), t))
    en = [n for n in nodes if n[2] == "EXIT NODE"]
    if not en:
        return None
    below = sorted(n for n in nodes
                   if n[0] >= en[0][1] - 5 and n[2] != "EXIT NODE")
    return below[0][2] if below else None


def open_chooser(endpoint):
    xml = ui_xml(endpoint)
    if "Choose exit node" in xml:
        return True
    m = re.search(
        r'<node[^>]*text="EXIT NODE"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        xml)
    if not m:
        return False
    cy = (int(m.group(2)) + int(m.group(4))) // 2
    adb(endpoint, "shell", "input", "tap", "540", str(cy))
    time.sleep(3)
    return "Choose exit node" in ui_xml(endpoint)


def set_exit_node(endpoint, name):
    want = "None" if name == "none" else name
    adb(endpoint, "shell", "monkey", "-p", PKG, "-c",
        "android.intent.category.LAUNCHER", "1")
    time.sleep(5)
    if current_exit_node(endpoint) == want:
        log("exit node already %s" % want)
        return True
    if not open_chooser(endpoint):
        log("chooser did not open")
        return False
    time.sleep(1)
    xml = ui_xml(endpoint)
    m = re.search(
        r'<node[^>]*text="' + re.escape(want) +
        r'"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml)
    if not m:
        log("exit node '%s' not listed" % want)
        return False
    cy = (int(m.group(2)) + int(m.group(4))) // 2
    adb(endpoint, "shell", "input", "tap", "540", str(cy))
    time.sleep(4)
    ok = current_exit_node(endpoint) == want
    log("set exit node -> %s : %s" % (want, "ok" if ok else "verify failed"))
    return ok


def phone_failover(endpoint, st):
    last = st.get("phone_lastfix")
    if last and time.time() - float(last) < 1800:
        return
    log("phone internet check failed - failover chain %s" % EXIT_CHAIN)
    for node in EXIT_CHAIN:
        set_exit_node(endpoint, node)
        time.sleep(8)
        if phone_inet_ok(endpoint):
            notify("tailnet-watch(omv): galaxy-s22 internet restored via exit node '%s'" % node)
            st["phone_lastfix"] = time.time()
            return
    notify("tailnet-watch(omv): galaxy-s22 internet dead, failover %s all failed" % EXIT_CHAIN)
    st["phone_lastfix"] = time.time()


def main():
    os.makedirs(DIR, exist_ok=True)
    st = load_state()

    # --- office-1 exit node / watchdog host health ---
    on = office_online()
    prev = st.get("office_online")
    if on is True and prev is False:
        notify("tailnet-watch(omv): %s is back ONLINE" % OFFICE_NAME)
    elif on is False and prev is not False:
        notify("tailnet-watch(omv): %s is OFFLINE - phone exit node + office watchdog down; attempting phone failover" % OFFICE_NAME)
    if on is not None:
        st["office_online"] = on

    # --- phone connectivity + failover ---
    endpoint = find_phone()
    if endpoint:
        if not phone_inet_ok(endpoint):
            phone_failover(endpoint, st)
        else:
            st.pop("phone_lastfix", None)
    else:
        log("phone not reachable over adb")

    save_state(st)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log("error: %s" % e)
    sys.exit(0)
