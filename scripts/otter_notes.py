#!/usr/bin/env python3
"""Otter notetaker toggle - drives otter.ai Record/Stop over a CDP link.

Prefers the Otter desktop app (system-audio capture of both sides of a
call), launched with --remote-debugging-port=9333 and the
ELECTRON_RUN_AS_NODE env var stripped (that var makes every Electron app
boot as plain node and exit). Falls back to the chrome-debug-profile
Chrome instance on port 9229 (microphone only) when the desktop app is
not available.

Prints a single state word to stdout for the WPF widget:

    ON    - recording is live
    OFF   - not recording
    ERR:<message> - something failed (exit code 1)

Usage:
    python otter_notes.py status/on/off/toggle
"""

# CATEGORY: ai-ml
# TAGS: otter, notetaker, recording, cdp, chrome, desktop

import json
import os
import subprocess
import sys
import time
import urllib.request

from playwright.sync_api import sync_playwright

DESKTOP_CDP_URL = "http://localhost:9333"
CHROME_CDP_URL = "http://localhost:9229"
OTTER_HOME = "https://otter.ai/home"
OTTER_EXE = r"C:\Users\tbaltzakis\AppData\Local\Programs\@otter-aidesktop-app\Otter.exe"
CHROME_EXE = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
CHROME_PROFILE = r"C:\Users\tbaltzakis\chrome-debug-profile"

START_BUTTON = "recording-start-button"
STOP_BUTTON = "test-id-mismatch"  # placeholder
