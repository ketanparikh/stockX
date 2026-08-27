"""
Supertrend + Chandelier Exit + RSI(25/100) long backtest.

Entry:  Supertrend BUY + CE BUY + RSI(25) > RSI(100) on signal bar (enter next open).
Exit:   CE SELL only (exit next open).

Indicators match StockX defaults (ATR 10/3 Supertrend, CE 22/3, Wilder RSI).
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import yfinance as yf

import config
from rsi_ce_backtest import (
    MIN_BARS,
    MIN_PRICE,
    RSI_FAST,
    RSI_SLOW,
    chandelier_direction,
    load_symbols,
    rsi_wilder_series,
    size_trades_long,
    yf_to_arrays,
)
from sethi_st_ce_backtest import supertrend_direction

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output" / "st_ce_rsi_run"

INITIAL_CAPITAL = 500_000.0
POSITION_PCT = 0.10


def entry_signal(st: np.ndarray, ce: np.ndarray, rf: np.ndarray, rs: np.ndarray, i: int) -> bool:
    if np.isnan(st[i]) or np.isnan(ce[i]) or np.isnan(rf[i]) or np.isnan(rs[i]):
        return False
    return st[i] == 1.0 and ce[i] == 1.0 and rf[i] > rs[i]


def simulate_long(
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
) -> list[dict]:
    rf = rsi_wilder_series(c, RSI_FAST)
    rs = rsi_wilder_series(c, RSI_SLOW)
    st = supertrend_direction(h, l, c)
    ce = chandelier_direction(h, l, c)
    n = len(c)
    trades: list[dict] = []
    i = max(RSI_SLOW, MIN_BARS)

    while i < n - 2:
        if c[i] < MIN_PRICE:
            i += 1
            continue
        if not entry_signal(st, ce, rf, rs, i):
            i += 1
            continue

        entry_i = i + 1
        entry_px = float(o[entry_i])
        if entry_px <= 0 or not np.isfinite(entry_px):
            i += 1
            continue

        exit_i = None
        exit_px = None
        reason = None
        for j in range(entry_i, n - 1):
            if ce[j] == -1.0:
                exit_i = j + 1
                exit_px = float(o[exit_i])
                reason = "CE SELL"
                break

        if exit_i is None:
            exit_i = n - 1
            exit_px = float(c[exit_i])
            reason = "End of data"

        if not np.isfinite(exit_px) or exit_px <= 0:
            i = exit_i + 1
            continue

        ret = (exit_px - entry_px) / entry_px * 100
        trades.append(
            {
                "Symbol": symbol,
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

    return trades


def main() -> None:
    parser = argparse.ArgumentParser(description="ST + CE + RSI(25>100) long backtest")
    parser.add_argument("--symbols-csv", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    args = parser.parse_args()

    symbols = load_symbols(args.symbols_csv, args.limit)
    period = config.FETCH_RANGE.get("1d", "2y")
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)

    raw_trades: list[dict] = []
    processed = 0

    for idx, sym in enumerate(symbols, 1):
        try:
            raw = yf.download(
                sym,
                period=period,
                progress=False,
                auto_adjust=False,
                threads=False,
            )
            if raw.empty or len(raw) < MIN_BARS:
                continue
            arr, dates = yf_to_arrays(raw)
            o, h, l, c = arr[:, 0], arr[:, 1], arr[:, 2], arr[:, 3]
            raw_trades.extend(simulate_long(o, h, l, c, sym, dates))
            processed += 1
        except Exception:
            continue
        if idx % 200 == 0:
            print(f"[{idx}/{len(symbols)}] trades={len(raw_trades)}")

    sized = size_trades_long(raw_trades, INITIAL_CAPITAL, POSITION_PCT)

    trades_path = out / "st_ce_rsi_trades.csv"
    sum_path = out / "st_ce_rsi_summary.txt"
    sized.to_csv(trades_path, index=False)

    if sized.empty:
        summary = "No trades generated.\n"
    else:
        pnl = sized["PnL"].sum()
        n = len(sized)
        wins = (sized["PnL"] > 0).sum()
        avg_hold = sized["Hold Days"].mean() if "Hold Days" in sized else 0
        reasons = sized["Exit Reason"].value_counts()
        reason_lines = "\n".join(f"    {k}: {v}" for k, v in reasons.items())
        summary = (
            f"Supertrend(10/3) + CE(22/3) + RSI({RSI_FAST}/{RSI_SLOW}) — LONG ONLY\n"
            f"Universe: {len(symbols)} symbols ({processed} with data) | Yahoo period={period}\n"
            f"Entry: ST BUY + CE BUY + RSI({RSI_FAST}) > RSI({RSI_SLOW}) on signal bar, enter next open\n"
            f"Exit: CE SELL only, exit next open\n"
            f"Position: {POSITION_PCT * 100:.0f}% rolling equity, max 10/day\n"
            f"\n"
            f"Trades: {n}\n"
            f"Win rate: {100 * wins / n:.1f}%\n"
            f"Total PnL: INR {pnl:,.2f}\n"
            f"Avg hold: {avg_hold:.1f} calendar days\n"
            f"\nExit reasons:\n{reason_lines}\n"
            f"\nFile: {trades_path}\n"
        )

    sum_path.write_text(summary, encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()
