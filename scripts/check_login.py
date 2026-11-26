"""Runs INSIDE Wine under Windows Python. Logs into the Headway MT5 terminal and records
what the bot needs: login, connection, trading permission, symbol names, a live tick and
M15 bars. The password is read from the environment and never written out."""
import json
import os
import time

import MetaTrader5 as mt5

OUT_DIR = "Z:/tmp/spike"  # Z: maps to the Linux root, so report_server.py can read it
OUT = os.path.join(OUT_DIR, "login.json")


def write(result: dict) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(result, f, indent=2, default=str)
    print(json.dumps(result, indent=2, default=str), flush=True)


def main() -> None:
    login = int(os.environ["MT5_LOGIN"])
    password = os.environ["MT5_PASSWORD"]
    server = os.environ["MT5_SERVER"]
    path = os.environ["MT5_PATH"]

    result = {"login_requested": login, "server_requested": server}
    t0 = time.time()
    ok = mt5.initialize(path=path, login=login, password=password, server=server,
                        timeout=300000)
    result["initialized"] = bool(ok)
    result["seconds_to_initialize"] = round(time.time() - t0, 1)
    if not ok:
        result["last_error"] = mt5.last_error()
        write(result)
        mt5.shutdown()
        return

    ai = mt5.account_info()
    ti = mt5.terminal_info()
    result["logged_in_login"] = ai.login if ai else None
    result["login_matches"] = bool(ai and ai.login == login)
    result["server"] = ai.server if ai else None
    result["trade_allowed"] = bool(ti and ti.trade_allowed)
    result["terminal_connected"] = bool(ti and ti.connected)

    # Symbol names differ by broker suffix. Record which candidates exist and have ticks.
    candidates = [os.environ.get("MT5_SYMBOL", "EURUSD"), "EURUSD", "EURUSD.r", "EURUSDm"]
    symbols = {}
    for name in dict.fromkeys(candidates):
        info = mt5.symbol_info(name)
        if info is None:
            symbols[name] = "not found"
            continue
        mt5.symbol_select(name, True)
        tick = mt5.symbol_info_tick(name)
        symbols[name] = {"found": True, "tick_received": tick is not None,
                         "digits": info.digits, "stops_level": info.trade_stops_level}
    result["symbols"] = symbols

    chosen = next((n for n, v in symbols.items()
                   if isinstance(v, dict) and v.get("tick_received")), None)
    result["symbol_with_tick"] = chosen
    if chosen:
        rates = mt5.copy_rates_from_pos(chosen, mt5.TIMEFRAME_M15, 0, 210)
        result["m15_bars_received"] = len(rates) if rates is not None else 0

    write(result)
    mt5.shutdown()


if __name__ == "__main__":
    main()
