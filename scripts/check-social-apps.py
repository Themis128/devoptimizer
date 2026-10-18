#!/usr/bin/env python3
import os
import re
from pathlib import Path

def main():
    # List of app names to check (case-insensitive)
    apps = [
        'Discord', 'Slack', 'Zoom', 'Teams', 'Skype', 'Telegram', 'WhatsApp', 
        'Signal', 'Messenger', 'Facebook', 'Instagram', 'Twitter', 'X', 
        'LinkedIn', 'Reddit', 'TikTok', 'Spotify', 'YouTube', 'Twitch',
        'Bluesky', 'Mastodon', 'Threads'
    ]
    # Create a regex pattern that matches any of the app names (case-insensitive)
    pattern = re.compile(r'(' + '|'.join(apps) + r')', re.IGNORECASE)

    # Function to list and filter items in a directory
    def list_matching_items(directory_path, section_name):
        print(f"=== {section_name} ===")
        path = Path(directory_path)
        if not path.exists() or not path.is_dir():
            print(f"Directory not found: {directory_path}")
            return
        # We'll iterate over the items in the directory
        for item in path.iterdir():
            # We are only interested in directories? The original script listed all items (files and folders) and then filtered by name.
            # We'll do the same: check the item's name against the pattern.
            if pattern.search(item.name):
                print(f"{item.name}\t{item}")
        print()  # Empty line for separation

    # Get environment variables
    local_app_data = os.getenv('LOCALAPPDATA')
    app_data = os.getenv('APPDATA')
    program_files = os.getenv('PROGRAMFILES')
    program_files_x86 = os.getenv('PROGRAMFILES(X86)')

    # Check each section
    if local_app_data:
        list_matching_items(local_app_data, "AppData\\Local")
    else:
        print("LOCALAPPDATA environment variable not found.")

    if app_data:
        list_matching_items(app_data, "AppData\\Roaming")
    else:
        print("APPDATA environment variable not found.")

    if program_files:
        list_matching_items(program_files, "Program Files")
    else:
        print("PROGRAMFILES environment variable not found.")

    if program_files_x86:
        list_matching_items(program_files_x86, "Program Files (x86)")
    else:
        print("PROGRAMFILES(X86) environment variable not found.")

if __name__ == '__main__':
    main()