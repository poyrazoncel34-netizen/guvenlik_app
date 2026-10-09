#!/usr/bin/env python3
"""Exit 0 when the panic countdown PIN pad is on screen (1080x2400): the '0' key
circle is drawn (not the plain background) and the upper area has the
countdown's red tint (the app-lock keypad has neither tint)."""
import subprocess, sys, io, os
from PIL import Image
ADB = os.path.expanduser('~/Library/Android/sdk/platform-tools/adb')
png = subprocess.run([ADB, 'exec-out', 'screencap', '-p'], capture_output=True).stdout
im = Image.open(io.BytesIO(png)).convert('RGB')
key = im.getpixel((540, 1930)); tint = im.getpixel((540, 1100))
sys.exit(0 if key != (10, 27, 42) and tint[0] > tint[1] + 4 else 1)
