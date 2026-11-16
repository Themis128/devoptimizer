"""Port of scripts/check-host-memory.ps1: free/total RAM one-liner."""
import ctypes
import sys


class MEMORYSTATUSEX(ctypes.Structure):
    _fields_ = [("dwLength", ctypes.c_ulong),
                ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong),
                ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong),
                ("ullAvailVirtual", ctypes.c_ulonglong),
                ("ullAvailExtendedVirtual", ctypes.c_ulonglong)]


def main():
    ms = MEMORYSTATUSEX()
    ms.dwLength = ctypes.sizeof(ms)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(ms))
    print(f"Host Memory: Free="
          f"{round(ms.ullAvailPhys / 2**30, 1)} GB / Total="
          f"{round(ms.ullTotalPhys / 2**30, 1)} GB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
