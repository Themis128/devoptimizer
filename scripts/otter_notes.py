#!/usr/bin/env python3
"""Otter notetaker toggle - drives otter.ai Record/Stop over CDP.

Connects to the chrome-debug-profile Chrome instance (remote debugging on
port 9229), finds or opens an otter.ai tab, and clicks Record / Stop on
otter.ai. Prints a single state word to stdout for the WPF widget:

    ON    - recording is live
    OFF   - not recording
    ERR:<message> - something failed (exit code 1)

Usage:
    python otter_notes.py status
    python otter_notes.py on
    python otter_notes.py off
    python otter_notes.py toggle

Note: otter.ai web Record captures the microphone only. For system-audio
capture of calls, the Otter desktop app is required instead.
"""

# CATEGORY: ai-ml
# TAGS: otter, notetaker, recording, cdp, chrome

import json
import subprocess
import sys
import time
import urllib.request

from playwright.sync_api import sync_playwright

CDP_URL = "http://localhost:9229"
OTTER_HOME = "https://otter.ai/home"
CHROME_EXE = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
CHROME_PROFILE = r"C:\Users\tbaltzakis\chrome-debug-profile"

START_BUTTON = "recording-start-button"
STOP_BUTTON = "recorder-bar-record-stop-button"


def _emit(state):
    print(state, flush=True)


def _browser_up():
    try:
        with urllib.request.urlopen(CDP_URL + "/json/version", timeout=3) as r:
            return json.load(r).get("Browser") is not None
    except Exception:
        return False


def ensure_browser():
    """Make sure the debug Chrome is running; launch it if needed."""
    if _browser_up():
        return
    subprocess.Popen(
        [
            CHROME_EXE,
            "--remote-debugging-port=9229",
            f"--user-data-dir={CHROME_PROFILE}",
            "--no-first-run",
            "--no-default-browser-check",
            OTTER_HOME,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        creationflags=getattr(subprocess, "DETACHED_PROCESS", 0)
        | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0),
        close_fds=True,
    )
    deadline = time.time() + 20
    while time.time() < deadline:
        if _browser_up():
            return
        time.sleep(0.5)
    raise RuntimeError("debug Chrome did not come up on :9229")


def get_otter_page(browser):
    """Return an otter.ai page, creating one if necessary."""
    ctx = browser.contexts[0] if browser.contexts else browser.new_context()
    for pg in ctx.pages:
        if "otter.ai" in pg.url:
            return pg
    page = ctx.new_page()
    page.goto(OTTER_HOME, wait_until="domcontentloaded", timeout=30000)
    return page


def is_recording(page):
    try:
        return (
            page.get_by_test_id(STOP_BUTTON).count() > 0
            and page.get_by_test_id(STOP_BUTTON).first.is_visible()
        )
    except Exception:
        return False


def wait_for(page, testid, want_visible, timeout=25):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            loc = page.get_by_test_id(testid)
            if loc.count() > 0 and loc.first.is_visible() == want_visible:
                return True
        except Exception:
            pass
        time.sleep(0.4)
    return False


def cmd_status(page):
    _emit("ON" if is_recording(page) else "OFF")


def cmd_on(page):
    if is_recording(page):
        _emit("ON")
        return
    if "/recording" in page.url or "otter.ai/home" not in page.url:
        page.goto(OTTER_HOME, wait_until="domcontentloaded", timeout=30000)
    try:
        page.context.grant_permissions(["microphone"], origin="https://otter.ai")
    except Exception:
        pass
    if not wait_for(page, START_BUTTON, True, timeout=15):
        page.reload(wait_until="domcontentloaded")
        wait_for(page, START_BUTTON, True, timeout=20)
    btn = page.get_by_test_id(START_BUTTON)
    # button can sit disabled while a previous session spins down
    deadline = time.time() + 20
    while time.time() < deadline:
        if not btn.is_disabled():
            break
        time.sleep(0.5)
    btn.click()
    if wait_for(page, STOP_BUTTON, True, timeout=25):
        _emit("ON")
    else:
        raise RuntimeError("record button clicked but stop control never appeared")


def cmd_off(page):
    if not is_recording(page):
        _emit("OFF")
        return
    page.get_by_test_id(STOP_BUTTON).first.click()
    if wait_for(page, START_BUTTON, True, timeout=25):
        _emit("OFF")
    else:
        raise RuntimeError("stop clicked but record button never came back")


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    ensure_browser()
    with sync_playwright() as p:
        browser = p.chromium.connect_over_cdp(CDP_URL, timeout=15000)
        page = get_otter_page(browser)
        try:
            if action == "status":
                cmd_status(page)
            elif action == "on":
                cmd_on(page)
            elif action == "off":
                cmd_off(page)
            elif action == "toggle":
                cmd_off(page) if is_recording(page) else cmd_on(page)
            else:
                raise RuntimeError(f"unknown action: {action}")
        finally:
            browser.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        _emit(f"ERR:{exc}")
        sys.exit(1)
