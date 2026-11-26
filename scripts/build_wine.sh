#!/bin/bash
# Runs during `docker build`. Stages 1-3 stop on any error.
# Stage 4 downloads the MT5 terminal folder (zipped from a PC install) and unpacks it.
set -euo pipefail
export WINEPREFIX=/opt/wineprefix WINEARCH=win64 WINEDEBUG=-all \
       WINEDLLOVERRIDES="mscoree,mshtml=" DISPLAY=:99
PY_DIR="$WINEPREFIX/drive_c/Python311"
PY_WIN='C:\Python311\python.exe'

for tool in wine wineserver Xvfb python3 wget unzip; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool not on PATH"; exit 1; }
done

Xvfb :99 -screen 0 1024x768x16 -nolisten tcp >/dev/null 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null || true' EXIT
sleep 2

echo "== 1. init Wine prefix"
wine wineboot -i >/dev/null 2>&1 || true
wineserver -w

echo "== 2. unpack embeddable Python 3.11 to C:\\Python311"
mkdir -p "$PY_DIR"
python3 -m zipfile -e /opt/python-embed.zip "$PY_DIR"
[ -f "$PY_DIR/python.exe" ] || { echo "ERROR: python.exe missing after unzip"; exit 1; }
sed -i 's/^#import site/import site/' "$PY_DIR/python311._pth"
grep -q '^import site' "$PY_DIR/python311._pth" || { echo "ERROR: could not enable site"; exit 1; }
echo "python.exe unpacked and site enabled"

echo "== 3. install pip, then MetaTrader5 with numpy pinned for Wine 8"
wget -q -O "$PY_DIR/get-pip.py" https://bootstrap.pypa.io/get-pip.py
timeout 600 wine "$PY_WIN" 'C:\Python311\get-pip.py' --no-warn-script-location || true
wineserver -w
timeout 120 wine "$PY_WIN" -m pip --version || { echo "ERROR: pip not working under Wine"; exit 1; }
timeout 900 wine "$PY_WIN" -m pip install --no-cache-dir --no-warn-script-location \
  "numpy==1.26.4" MetaTrader5 || true
wineserver -w
timeout 90 wine "$PY_WIN" -c "import MetaTrader5; print('MetaTrader5 import ok')" \
  || { echo "ERROR: MetaTrader5 did not import under Wine"; exit 1; }

echo "== 4. download and unpack the MT5 terminal folder"
MT5_URL="$(tr -d '[:space:]' < /opt/mt5_url.txt)"
case "$MT5_URL" in
  https://*) ;;
  *) echo "ERROR: mt5_url.txt does not contain an https link"; exit 1 ;;
esac
wget -q -O /opt/mt5.zip "$MT5_URL" || { echo "ERROR: download failed"; exit 1; }
echo "downloaded $(stat -c %s /opt/mt5.zip) bytes"
mkdir -p "$WINEPREFIX/drive_c/MetaTrader5"
unzip -q /opt/mt5.zip -d "$WINEPREFIX/drive_c/MetaTrader5" || { echo "ERROR: unzip failed"; exit 1; }
rm -f /opt/mt5.zip
TERM_UNIX="$(find "$WINEPREFIX/drive_c" -iname terminal64.exe | head -1)"
if [ -z "$TERM_UNIX" ]; then
  echo "ERROR: terminal64.exe not found inside the zip. Top-level contents:"
  ls "$WINEPREFIX/drive_c/MetaTrader5" | head -20
  exit 1
fi
echo "terminal found at: $TERM_UNIX"
echo "== build stages complete"
