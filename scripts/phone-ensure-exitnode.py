"""Set the Tailscale exit node on galaxy-s22 via UI automation.

Called by tailnet-watchdog.ps1 for connectivity repair / exit-node
failover. Idempotent: exits 0 quickly if the requested exit node is
already selected or the app can't be driven.

Usage: phone-ensure-exitnode.py [serial] [exit-node-name|none]
  exit-node-name: tailnet machine name, e.g. office-1-win-exitnode,
                  github-omv, omv-ha. "none" selects no exit node
                  (direct internet via current network).

Requires: python + uiautomator2, phone reachable over ADB.
"""
import re
import sys
import time

import uiautomator2 as u2

PKG = "com.tailscale.ipn"
DEFAULT_TARGET = "office-1-win-exitnode"


def screen_texts(d):
    return [t for t in re.findall(r'text="([^"]+)"', d.dump_hierarchy()) if t.strip()]


def row_center(d, name):
    """Return (x, y) center of the clickable row containing `name`."""
    x = d.dump_hierarchy()
    m = re.search(
        r'<node[^>]*text="' + re.escape(name) + r'"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        x,
    )
    if not m:
        return None
    ty = (int(m.group(2)) + int(m.group(4))) // 2
    # row spans full width; click just left of the text block area
    return (540, ty)


def current_exit_node(d):
    """Name shown on the main screen's EXIT NODE row, or None."""
    x = d.dump_hierarchy()
    nodes = []
    for m in re.finditer(
        r'<node[^>]*text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', x
    ):
        t, x1, y1, x2, y2 = m.group(1), *map(int, m.groups()[1:])
        if t.strip():
            nodes.append((y1, y2, t))
    en = [n for n in nodes if n[2] == "EXIT NODE"]
    if not en:
        return None
    ey2 = en[0][1]
    below = [n for n in nodes if n[0] >= ey2 - 5 and n[2] != "EXIT NODE"]
    if not below:
        return None
    below.sort()
    return below[0][2]


def open_chooser(d):
    x = d.dump_hierarchy()
    if "Choose exit node" in x:
        return True
    for sel in ("description", "textContains"):
        el = d(description="EXIT NODE") if sel == "description" else d(textContains="EXIT NODE")
        if el.exists:
            el.click()
            time.sleep(3)
            break
    time.sleep(1)
    return "Choose exit node" in d.dump_hierarchy()


def main():
    serial = sys.argv[1] if len(sys.argv) > 1 else "RFCTA0AEKZP"
    target = (sys.argv[2] if len(sys.argv) > 2 else DEFAULT_TARGET).strip()
    want_none = target.lower() == "none"
    row_name = "None" if want_none else target

    d = u2.connect(serial)
    d.app_start(PKG)
    time.sleep(5)

    cur = current_exit_node(d)
    want = "None" if want_none else target
    if cur == want:
        print(f"exit node already set to {want}")
        return 0
    print(f"current exit node: {cur}; switching to {want}")

    if not open_chooser(d):
        print("could not open exit-node chooser; texts:", screen_texts(d)[:15])
        return 2

    time.sleep(2)
    pt = row_center(d, row_name)
    if not pt:
        print(f"exit node '{row_name}' not listed; texts:", screen_texts(d)[:20])
        return 2
    d.click(*pt)
    time.sleep(4)

    cur = current_exit_node(d)
    if cur == want:
        print(f"exit node set to {want}")
        return 0
    print(f"verification failed; exit node shows '{cur}'; texts:", screen_texts(d)[:15])
    return 1


if __name__ == "__main__":
    sys.exit(main())
