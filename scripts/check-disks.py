#!/usr/bin/env python3
import psutil

def main():
    # We want to check drives C, D, E as in the original PowerShell script
    # But note: the original script used Get-PSDrive C,D,E which gets the drives that exist.
    # We'll get all disk partitions and filter by device letter C, D, E (case insensitive)
    partitions = psutil.disk_partitions()
    # We'll collect the data for each drive
    data = []
    for part in partitions:
        # Check if the device is a fixed drive and the letter is C, D, or E
        # On Windows, the device looks like 'C:\\'
        if part.device.upper()[0] in ['C', 'D', 'E'] and 'fixed' in part.opts:
            try:
                usage = psutil.disk_usage(part.mountpoint)
            except Exception:
                # If we cannot get usage, skip
                continue
            total_gb = usage.total / (1024**3)
            used_gb = usage.used / (1024**3)
            free_gb = usage.free / (1024**3)
            free_pct = (usage.free / usage.total) * 100
            data.append({
                'Device': part.device.rstrip('\\'),  # Remove trailing backslash for display
                'UsedGB': used_gb,
                'FreeGB': free_gb,
                'TotalGB': total_gb,
                'FreePct': free_pct
            })

    if not data:
        print("No drives C, D, E found.")
        return

    # Prepare for table output
    # We want to match the PowerShell output format:
    # Name Used Free FreeGB UsedGB TotalGB FreePct
    # But note: the original script selected:
    # Name, Used, Free, {Name='FreeGB';Expression={'{0:N1}' -f ($_.Free/1GB)}}, ...
    # So it shows: Name, Used, Free, FreeGB, UsedGB, TotalGB, FreePct
    # We'll output in that order.

    # Determine column widths
    headers = ["Name", "Used", "Free", "FreeGB", "UsedGB", "TotalGB", "FreePct"]
    # We'll format the numbers to one decimal place for GB and percentage as percentage with no decimal?
    # The PowerShell script used '{0:N1}' for GB (one decimal) and '{0:P0}' for percentage (no decimal, multiplied by 100 and with % sign)
    # We'll do the same.

    # Prepare rows
    rows = []
    for d in data:
        # Used and Free in bytes? The original script's Used and Free properties are in bytes.
        # We'll keep them in bytes for the Used and Free columns, but we can format them to GB? 
        # Let's check the original output: it shows Used and Free in bytes? Actually, the original script:
        #   Get-PSDrive C,D,E | Select-Object Name,Used,Free, ...
        # The Used and Free properties of a PSDrive are in bytes.
        # We'll keep them in bytes and let the user see the large numbers, or we can convert to GB? 
        # But the original script also calculated FreeGB, UsedGB, TotalGB separately.
        # We'll output Used and Free in bytes as in the original.
        used_bytes = d['UsedGB'] * (1024**3)
        free_bytes = d['FreeGB'] * (1024**3)
        rows.append([
            d['Device'],
            f"{used_bytes:,}",  # Used in bytes with commas
            f"{free_bytes:,}",  # Free in bytes with commas
            f"{d['FreeGB']:.1f}",
            f"{d['UsedGB']:.1f}",
            f"{d['TotalGB']:.1f}",
            f"{d['FreePct']:.0f}%"
        ])

    # Now calculate column widths based on the formatted strings
    col_widths = [len(h) for h in headers]
    for row in rows:
        for i, val in enumerate(row):
            col_widths[i] = max(col_widths[i], len(val))

    # Create format string
    fmt = "  ".join(["{{:<{}}}".format(w) for w in col_widths])
    # Print header
    print(fmt.format(*headers))
    # Print separator
    print("-" * (sum(col_widths) + 2 * (len(col_widths) - 1)))
    # Print each row
    for row in rows:
        print(fmt.format(*row))

if __name__ == '__main__':
    main()