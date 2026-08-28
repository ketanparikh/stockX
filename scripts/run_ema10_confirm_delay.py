"""Wait 1–2 bars after EMA10 signal; enter only if the stack is still intact."""
from __future__ import annotations

import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
from supabase import create_client

import config
from ema10_cross_backtest import FAST, LOOKBACK, MID_FAST, MID_SLOW, MIN_BARS, TREND, _cross_flags
from rsi_ce_backtest import INITIAL_CAPITAL, POSITION_PCT, size_trades_long
from sethi_st_ce_backtest import supertrend_direction
from stock_quality_filter import ema

SCRIPT_DIR = Path(__file__).resolve().parent
OUT = SCRIPT_DIR / "backtest_output" / "ema10_confirm_delay_run"
PAGE = 25


def _arrays(row: dict):
    t, o, h, l, c = row["t"], row["o"], row["h"], row["l"], row["c"]
    n = min(len(t), len(o), len(h), len(l), len(c))
    if n < MIN_BARS:
        return None
    dates = pd.to_datetime(
        [datetime.fromtimestamp(x / 1000, tz=timezone.utc) for x in t[:n]]
    ).tz_localize(None)
    return (
        np.array(o[:n], dtype=float),
        np.array(h[:n], dtype=float),
        np.array(l[:n], dtype=float),
        np.array(c[:n], dtype=float),
        pd.DatetimeIndex(dates),
    )


def _series(close: np.ndarray, lookback: int = LOOKBACK):
    """App rule: close > 10 and 200, 10 > 30 and 48, fresh cross. No 10 > 200."""
    e10 = ema(close, FAST)
    e30 = ema(close, MID_FAST)
    e48 = ema(close, MID_SLOW)
    e200 = ema(close, TREND)
    up30, down30 = _cross_flags(e10, e30)
    up48, down48 = _cross_flags(e10, e48)
    n = len(close)
    is_entry = np.zeros(n, dtype=bool)
    is_exit = np.zeros(n, dtype=bool)
    intact = np.zeros(n, dtype=bool)
    below = np.zeros(n, dtype=bool)
    for i in range(TREND, n):
        a10, a30, a48, a200, px = e10[i], e30[i], e48[i], e200[i], close[i]
        if not all(np.isfinite(x) for x in (a10, a30, a48, a200, px)):
            continue
        stack = px > a10 and px > a200 and a10 > a30 and a10 > a48
        intact[i] = stack
        below[i] = a10 < a30 and a10 < a48
        if stack and up30[i] >= 0 and up48[i] >= 0:
            completing = min(i - int(up30[i]), i - int(up48[i]))
            if completing <= lookback:
                is_entry[i] = True
        if below[i] and down30[i] >= 0 and down48[i] >= 0:
            completing = min(i - int(down30[i]), i - int(down48[i]))
            if completing <= lookback:
                is_exit[i] = True
    return is_entry, is_exit, intact, below


def simulate(o, c, dates, is_entry, is_exit, intact, below, st, delay, exit_mode):
    n = len(c)
    trades: list[dict] = []
    signals = 0
    skipped = 0
    i = TREND
    while i < n - 2 - delay:
        if not is_entry[i]:
            i += 1
            continue
        signals += 1
        confirm = i + delay
        if confirm >= n - 2:
            i += 1
            continue
        ok = bool(intact[confirm]) and not bool(below[confirm])
        if exit_mode == "st":
            # Original ST-exit book does not require ST BUY to enter.
            # After a wait, skip if Supertrend has already flipped to SELL.
            if delay > 0:
                ok = ok and st[confirm] != -1.0
        else:
            ok = ok and not bool(is_exit[confirm])
        if not ok:
            skipped += 1
            i = confirm + 1
            continue

        entry_i = confirm + 1
        entry_px = float(o[entry_i])
        if entry_px <= 0 or not np.isfinite(entry_px):
            i = confirm + 1
            continue

        exit_i = n - 1
        exit_px = float(c[exit_i])
        reason = "End of data"
        for j in range(entry_i, n - 1):
            if exit_mode == "st":
                hit = st[j] == -1.0
                label = "Supertrend SELL"
            else:
                hit = bool(is_exit[j])
                label = "EMA 10 below 30 & 48"
            if not hit:
                continue
            nxt = j + 1
            px = float(o[nxt])
            if np.isfinite(px) and px > 0:
                exit_i, exit_px, reason = nxt, px, label
            else:
                exit_i, exit_px, reason = j, float(c[j]), label
            break

        if not np.isfinite(exit_px) or exit_px <= 0:
            i = exit_i + 1
            continue

        ret = (exit_px - entry_px) / entry_px * 100
        trades.append(
            {
                "Symbol": "X",
                "Signal Date": dates[i].strftime("%Y-%m-%d"),
                "Entry Date": dates[entry_i].strftime("%Y-%m-%d"),
                "Entry Price": round(entry_px, 4),
                "Exit Date": dates[exit_i].strftime("%Y-%m-%d"),
                "Exit Price": round(exit_px, 4),
                "Exit Reason": reason,
                "Return %": round(ret, 2),
                "Hold Days": (dates[exit_i] - dates[entry_i]).days,
            }
        )
        i = exit_i + 1
    return trades, signals, skipped


def stats(sized: pd.DataFrame) -> dict:
    if sized.empty:
        return {
            "n": 0,
            "wr": 0.0,
            "pf": 0.0,
            "pnl": 0.0,
            "ret": 0.0,
            "hold": 0.0,
            "short_n": 0,
            "short_pnl": 0.0,
            "short_wr": 0.0,
        }
    pnl = float(sized["PnL"].sum())
    n = len(sized)
    wins = int((sized["PnL"] > 0).sum())
    win_pnl = float(sized.loc[sized["PnL"] > 0, "PnL"].sum())
    loss_pnl = float(sized.loc[sized["PnL"] < 0, "PnL"].sum())
    pf = abs(win_pnl / loss_pnl) if loss_pnl != 0 else 99.0
    short = sized[sized["Hold Days"] < 15]
    return {
        "n": n,
        "wr": 100 * wins / n,
        "pf": pf,
        "pnl": pnl,
        "ret": (INITIAL_CAPITAL + pnl) / INITIAL_CAPITAL * 100 - 100,
        "hold": float(sized["Hold Days"].mean()),
        "mean_tr": float(sized["Return %"].mean()),
        "med_tr": float(sized["Return %"].median()),
        "short_n": len(short),
        "short_pnl": float(short["PnL"].sum()) if len(short) else 0.0,
        "short_wr": 100 * float((short["PnL"] > 0).mean()) if len(short) else 0.0,
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    client = create_client(config.SUPABASE_URL, config.SUPABASE_ANON_KEY)
    rows: list[dict] = []
    start = 0
    while True:
        r = (
            client.table("stock_candles")
            .select("symbol,t,o,h,l,c")
            .eq("timeframe", "1d")
            .range(start, start + PAGE - 1)
            .execute()
        )
        batch = r.data or []
        if not batch:
            break
        rows.extend(batch)
        print(f"  loaded {len(rows)}", flush=True)
        start += PAGE
        time.sleep(0.08)

    prepared = []
    for i, row in enumerate(rows, 1):
        data = _arrays(row)
        if data is None:
            continue
        o, h, l, c, dates = data
        is_entry, is_exit, intact, below = _series(c, LOOKBACK)
        st = supertrend_direction(h, l, c)
        prepared.append((f"{row['symbol']}.NS", o, c, dates, is_entry, is_exit, intact, below, st))
        if i % 400 == 0:
            print(f"  indicators {i}/{len(rows)}", flush=True)
    print(f"ready {len(prepared)} symbols", flush=True)

    variants = []
    for exit_mode in ("st", "ema"):
        for delay in (0, 1, 2):
            raw: list[dict] = []
            sig_n = 0
            skip_n = 0
            for sym, o, c, dates, is_entry, is_exit, intact, below, st in prepared:
                t, s, sk = simulate(
                    o, c, dates, is_entry, is_exit, intact, below, st, delay, exit_mode
                )
                for tr in t:
                    tr["Symbol"] = sym
                raw.extend(t)
                sig_n += s
                skip_n += sk
            sized = size_trades_long(raw, INITIAL_CAPITAL, POSITION_PCT)
            sized.to_csv(OUT / f"{exit_mode}_delay{delay}_trades.csv", index=False)
            stt = stats(sized)
            stt.update(exit=exit_mode, delay=delay, signals=sig_n, skipped=skip_n)
            variants.append(stt)
            print(
                f"{exit_mode} delay={delay}: n={stt['n']} wr={stt['wr']:.1f}% "
                f"pf={stt['pf']:.2f} pnl={stt['pnl']:.0f} mean%={stt.get('mean_tr', 0):.2f} "
                f"skip={skip_n}/{sig_n}",
                flush=True,
            )

    OUT.mkdir(parents=True, exist_ok=True)
    lines = [
        "EMA10 confirm delay (wait 0/1/2 bars after signal, enter only if stack intact)",
        "Entry: close > EMA10 & EMA200, 10 > 30 & 48, cross within 5 (NO EMA10>EMA200)",
        f"Universe: {len(prepared)} | 2y daily Supabase | 10% equity, max 10/day, capital 5L",
        "",
    ]
    for v in variants:
        lines.append(
            f"exit={v['exit']:3s} delay={v['delay']}  trades={v['n']:5d}  "
            f"WR={v['wr']:5.1f}%  PF={v['pf']:.2f}  PnL={v['pnl']:12,.0f}  "
            f"ret={v['ret']:7.2f}%  hold={v['hold']:.1f}d  "
            f"skip={v['skipped']}/{v['signals']}  "
            f"<15d n={v.get('short_n', 0)} pnl={v.get('short_pnl', 0):,.0f}  "
            f"mean ret={v.get('mean_tr', 0):.2f}% med={v.get('med_tr', 0):.2f}%"
        )
    text = "\n".join(lines) + "\n"
    (OUT / "confirm_delay_summary.txt").write_text(text, encoding="utf-8")
    print(text, flush=True)


if __name__ == "__main__":
    main()
