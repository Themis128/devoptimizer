#!/usr/bin/env python3
"""
Build-App.py - Python version of Build-App.ps1
Builds the DevOptimizer Windows 11 application artifacts:
a multi-resolution icon, the single-file launcher EXE, and the
C# WPF shell (DevOptimizer.App) published framework-dependent with ReadyToRun.
"""

import argparse
import os
import sys
import subprocess
import struct
import tempfile
import shutil
from pathlib import Path
from PIL import Image, ImageDraw


def new_brand_bitmap(size):
    """Create a brand bitmap with blue->teal gradient and white 'D'"""
    # Create image with gradient background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Create rounded rectangle path
    radius = max(2, int(size * 0.18))
    diameter = radius * 2
    
    # Draw rounded rectangle
    draw.rounded_rectangle(
        [(0, 0), (size-1, size-1)],
        radius=radius,
        fill=None
    )
    
    # Create gradient
    for y in range(size):
        # Interpolate between blue and teal
        ratio = y / size
        r = int(15 + (78 - 15) * ratio)
        g = int(108 + (201 - 108) * ratio)
        b = int(189 + (176 - 189) * ratio)
        draw.line([(0, y), (size-1, y)], fill=(r, g, b, 255))
    
    # Apply rounded rectangle mask
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        [(0, 0), (size-1, size-1)],
        radius=radius,
        fill=255
    )
    img.putalpha(mask)
    
    # Draw white 'D' in center
    font_size = int(size * 0.62)
    # Try to use a system font, fallback to default
    try:
        # On Windows, we might use a truetype font
        from PIL import ImageFont
        font = ImageFont.truetype("segoeui.ttf", font_size)
    except IOError:
        # Fallback to default font
        font = ImageFont.load_default()
        
    # Get text size
    bbox = draw.textbbox((0, 0), 'D', font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    # Center the text
    x = (size - text_width) // 2
    y = (size - text_height) // 2 - int(font_size * 0.1)
    
    draw.text((x, y), 'D', font=font, fill=(255, 255, 255, 255))
    
    return img


def new_multi_res_icon(out_path, sizes=(256, 48, 32, 16)):
    """Create a multi-resolution ICO file"""
    # Create temporary directory within the project to avoid path traversal issues
    tmp_dir = Path(__file__).resolve().parent.parent / 'tmp' / f"devopt-icon-{os.getpid()}"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    
    try:
        images = []
        for size in sizes:
            # Generate bitmap
            bmp = new_brand_bitmap(size)
            
            # Save as temporary PNG
            png_file = tmp_dir / f"{size}.png"
            bmp.save(png_file, format='PNG')
            
            images.append({
                'size': size,
                'png_file': png_file
            })
        
        # Use PIL to save directly as ICO with multiple sizes
        base_image = Image.open(images[0]['png_file'])
        base_image.save(
            out_path,
            format='ICO',
            sizes=[(img['size'], img['size']) for img in images],
            append_images=[Image.open(img['png_file']) for img in images[1:]]
        )
            
    finally:
        # Cleanup temporary directory
        shutil.rmtree(tmp_dir, ignore_errors=True)
    
    # Validate: parse the directory count back out
    with open(out_path, 'rb') as f:
        data = f.read()
        count = struct.unpack('<H', data[4:6])[0]  # count is at offset 4
        if count != len(sizes):
            raise Exception(f"ICO merge failed: {count} entries (expected {len(sizes)})")
    
    return len(sizes)


def main():
    parser = argparse.ArgumentParser(description='Build DevOptimizer application artifacts')
    parser.add_argument('--skip-icon', action='store_true', help='Skip icon generation')
    parser.add_argument('--skip-exe', action='store_true', help='Skip EXE generation')
    args = parser.parse_args()

    # Set error handling
    script_path = Path(__file__).resolve()
    root = script_path.parent.parent
    ico_path = root / 'app' / 'DevOptimizer.ico'
    bin_dir = root / 'app' / 'bin'

    if not args.skip_icon:
        entries = new_multi_res_icon(str(ico_path))
        print(f"[icon]  {ico_path} ({entries} sizes)")

    if not args.skip_exe:
        csproj = root / 'app' / 'launcher' / 'DevOptimizer.Launcher.csproj'
        if not csproj.exists():
            raise Exception(f"Launcher project not found: {csproj}")
        
        bin_dir.mkdir(parents=True, exist_ok=True)
        
        # Build launcher
        result = subprocess.run(
            ['dotnet', 'publish', str(csproj), '-c', 'Release', '-o', str(bin_dir), '--nologo', '-v', 'm'],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            raise Exception(f"dotnet publish failed with exit code {result.returncode}\n{result.stderr}")
        
        exe_path = bin_dir / 'DevOptimizer.exe'
        if not exe_path.exists():
            raise Exception(f"Launcher exe missing after publish: {exe_path}")
        
        mb = round(exe_path.stat().st_size / (1024 * 1024), 2)
        print(f"[exe]   {exe_path} ({mb} MB)")

        # Build C# WPF shell
        app_project = root / 'app' / 'DevOptimizer.App' / 'DevOptimizer.App.csproj'
        if not app_project.exists():
            raise Exception(f"App project not found: {app_project}")
        
        result = subprocess.run(
            ['dotnet', 'publish', str(app_project), '-c', 'Release', '-r', 'win-x64', 
             '--self-contained', 'false', '-p:PublishReadyToRun=true', '-o', str(bin_dir), 
             '--nologo', '-v', 'm'],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            raise Exception(f"App publish failed with exit code {result.returncode}\n{result.stderr}")
        
        app_exe = bin_dir / 'DevOptimizer.App.exe'
        if not app_exe.exists():
            raise Exception(f"App exe missing after publish: {app_exe}")
        
        app_mb = round(app_exe.stat().st_size / (1024 * 1024), 2)
        print(f"[app]   {app_exe} ({app_mb} MB)")

    print('Build-App: OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())