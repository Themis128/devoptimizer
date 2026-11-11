"""Re-assert the Tailscale exit node on galaxy-s22 via UI automation.

Called by tailnet-watchdog.ps1 when the phone loses public DNS/internet
(the known failure mode: exit node drops -> MagicDNS has no upstream ->
all public resolution fails). Idempotent: exits 0 quickly if the exit
node is already office-1-win-exitnode or the app can't be driven.

Requires: python + uiautomator2, phone reachable over ADB as RFCTA0AEKZP.
"""
import re
import sys
import time

import uiautomator2 as u2

PKG = "com.tailscale.ipn"
TARGET = "office-1-win-exitnode"


def texts(d):
    return [t for t in re.findall(r'text="([^"]+)"', d.dump_hierarchy()) if t.strip()]


def main():
    serial = sys.argv[1] if len(sys.argv) > 1 else "RFCTA0AEKZP"
    d = u2.connect(serial)
    d.app_start(PKG)
    time.sleep(5)

    x = d.dump_hierarchy()
    if TARGET in x and "EXIT NODE" in x:
        print("exit node already set")
        return 0

    # If we're not on the exit-node chooser, open it from the main screen.
    if "Choose exit node" not in x:
        el = d(description="EXIT NODE")
        if not el.exists:
            el = d(textContains="EXIT NODE")
        if el.exists:
            el.click()
            time.sleep(3)
        else:
            # try tapping the exit-node row by its current value text
            m = re.search(r'text="(office-1-win-exitnode|None|Mullvad VPN)"', x)
            print("no EXIT NODE row found; screen texts:", texts(d)[:15])
            return 2

    time.sleep(2)
    x = d.dump_hierarchy()
    if "Choose exit node" not in x:
        print("chooser did not open")
        return 2

    # Click the row containing the target name. The TextView itself is not
    # clickable; click the row center under it instead.
    m = re.search(
        r'<node[^>]*text="' + re.escape(TARGET) + r'"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        x,
    )
    if not m:
        print("target exit node not listed")
        return 2
    cx = (int(m.group(1)) + int(m.group(3))) // 2
    cy = (int(m.group(2)) + int(m.group(4))) // 2
    d.click(cx, cy)
    time.sleep(4)

    x = d.dump_hierarchy()
    if TARGET in x and "EXIT NODE" in x:
        print("exit node set to", TARGET)
        return 0
    print("verification failed; screen texts:", texts(d)[:15])
    return 1


if __name__ == "__main__":
    sys.exit(main())
