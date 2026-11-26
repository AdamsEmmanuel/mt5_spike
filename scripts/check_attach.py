"""Runs INSIDE Wine under Windows Python. Attaches to a terminal that was already
started with login arguments. No credentials are passed here."""
import json
import os
import time

import MetaTrader5 as mt5

OUT_DIR = "Z:/tmp/spike"
OUT = os.path.join(OUT_DIR, "login.json")


def write(result: dict) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(result, f, indent=2, default=str)
    print(json.dumps(result, indent=2, default=str), flush=True)


def main() -> None:
    requested = int(os.environ["MT5_LOGIN"])
    path = os.environ["MT5_PATH"]
    result = {"mode": "attach_to_running_terminal", "login_requested": requested}

    t0 = time.time()
    ok = mt5.initialize(path=path, timeout=60000)
    result["initialized"] = bool(ok)
    result["seconds_to_initialize"] = round(time.time() - t0, 1)
    if not ok:
        result["last_error"] = mt5.last_error()
        write(result)
        return

    ai = mt5.account_info()
    ti = mt5.terminal_info()
    result["account_login"] = ai.login if ai else None
    result["logged_in"] = bool(ai and ai.login == requested)
    result["server"] = ai.server if ai else None
    result["terminal_connected"] = bool(ti and ti.connected)
    result["trade_allowed"] = bool(ti and ti.trade_allowed)
    write(result)
    mt5.shutdown()


if __name__ == "__main__":
    main()
