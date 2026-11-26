#!/bin/bash
# Login test. Step 1: start the terminal with login arguments.
# Step 2: wait for it to log in. Step 3: attach Python to the running terminal.
set -uo pipefail
export WINEPREFIX=/opt/wineprefix WINEARCH=win64 WINEDEBUG=-all \
       WINEDLLOVERRIDES="mscoree,mshtml=" DISPLAY=:99
export PORT="${PORT:-8080}"
mkdir -p /tmp/spike
rm -f /tmp/spike/windows.txt /tmp/spike/login.out

echo "== virtual display"
Xvfb :99 -screen 0 1024x768x16 -nolisten tcp >/tmp/spike/xvfb.log 2>&1 &
sleep 2

echo "== report server on port $PORT"
python3 /opt/spike/report_server.py >/tmp/spike/server.log 2>&1 &

echo "== memory sampler"
/opt/spike/mem_report.sh &

# Window watcher: logs open windows every 10 seconds. Presses Enter only on
# setup-type windows, never on the login form.
(
  for i in $(seq 1 30); do
    sleep 10
    W=$(xwininfo -root -children 2>/dev/null | sed -n 's/^ *0x[0-9a-f]* "\([^"]*\)".*/\1/p' | grep -v '^$' | sort -u | tr '\n' '|')
    echo "t+$((i*10))s windows=[$W]" >> /tmp/spike/windows.txt
    for w in $(xdotool search --name 'Setup|License|Wizard|Language' 2>/dev/null | head -5); do
      xdotool windowactivate --sync "$w" 2>/dev/null
      xdotool key --clearmodifiers Return 2>/dev/null
    done
  done
) &

TERM_UNIX="$(find "$WINEPREFIX/drive_c" -iname terminal64.exe | head -1)"
if [ -z "$TERM_UNIX" ]; then
  echo "terminal64.exe not found" | tee /tmp/spike/login.out
  wait
fi
REL="${TERM_UNIX#$WINEPREFIX/drive_c/}"
export MT5_PATH="C:\\$(echo "$REL" | tr '/' '\\')"

echo "== step 1: start terminal with login arguments (terminal: $MT5_PATH)"
wine "$MT5_PATH" /login:"$MT5_LOGIN" /password:"$MT5_PASSWORD" /server:"$MT5_SERVER" \
  >/tmp/spike/terminal.out 2>&1 &

echo "== step 2: wait 120s for the terminal to log in"
sleep 120

echo "== step 3: attach Python to the running terminal (no credentials)"
timeout 240 wine cmd /c "C:\Python311\python.exe -u Z:\opt\spike\check_attach.py > C:\login.out 2>&1 < NUL"
cp "$WINEPREFIX/drive_c/login.out" /tmp/spike/login.out 2>/dev/null \
  || echo "login.out was not written; the attach script never started" > /tmp/spike/login.out
echo "attach check exit code: $?" | tee -a /tmp/spike/login.out

echo "== spike running; keep container alive and sample memory"
wait
