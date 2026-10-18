#!/usr/bin/env python3
import ctypes
import sys

def is_admin():
    """Check if the current user has administrator privileges."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def main():
    """Main function to check and display admin status."""
    is_admin_result = is_admin()
    print(f"IsAdmin: {is_admin_result}")

if __name__ == '__main__':
    main()