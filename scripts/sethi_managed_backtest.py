"""
Sethi breakout + managed exits (2y full universe).

Entry:  Sethi setup on signal bar (20D high, DMA, volume, RSI 60-80).
Exit:   -5% stop | trail after +20% | CE SELL | end of data
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
    chandelier_direction,
    load_symbols,
    size_trades_long,
    yf_to_arrays,
)
from sethi_st_ce_backtest import sethi_buy_series
from st_ce_rsi_managed_backtest import (
    INITIAL_CAPITAL,
    INITIAL_STOP_PCT,
    POSITION_PCT,
    TRAIL_ACTIVATE_PCT,
    TRAIL_OFFSET_PCT,
    simulate_exit_path,
)

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output" / "sethi_managed_run"


def simulate_long(
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    v: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
) -> list[dict]:
    sethi = sethi_buy_series(o, h, l, c, v)
    ce = chandelier_direction(h, l, c)
    n = len(c)
    trades: list[dict] = []
    i = MIN_BARS

    while i < n - 2:
        if sethi[i] != 1.0:
            i += 1
            continue

        entry_i = i + 1
        entry_px = float(o[entry_i])
        if entry_px <= 0 or not np.isfinite(entry_px):
            i += 1
            continue

        result = simulate_exit_path(o, h, l, c, ce, entry_i, entry_px, dates)
        if result is None:
            i += 1
            continue

        exit_i, exit_px, reason = result
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
    parser = argparse.ArgumentParser(description="Sethi breakout with managed exits")
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
            raw = yf.download(sym, period=period, progress=False, auto_adjust=False, threads=False)
            if raw.empty or len(raw) < MIN_BARS:
                continue
            arr, dates = yf_to_arrays(raw)
            o, h, l, c, v = arr[:, 0], arr[:, 1], arr[:, 2], arr[:, 3], arr[:, 4]
            raw_trades.extend(simulate_long(o, h, l, c, v, sym, dates))
            processed += 1
        except Exception:
            continue
        if idx % 200 == 0:
            print(f"[{idx}/{len(symbols)}] trades={len(raw_trades)}")

    sized = size_trades_long(raw_trades, INITIAL_CAPITAL, POSITION_PCT)
    trades_path = out / "sethi_managed_trades.csv"
    sum_path = out / "sethi_managed_summary.txt"
    sized.to_csv(trades_path, index=False)

    if sized.empty:
        summary = "No trades generated.\n"
    else:
        pnl = sized["PnL"].sum()
        n = len(sized)
        wins = (sized["PnL"] > 0).sum()
        reasons = sized["Exit Reason"].value_counts()
        reason_lines = "\n".join(f"    {k}: {v}" for k, v in reasons.items())
        final = INITIAL_CAPITAL + pnl
        summary = (
            f"Sethi breakout + managed exits — LONG\n"
            f"Universe: {len(symbols)} ({processed} with data) | period={period}\n"
            f"Entry: Sethi setup, enter next open\n"
            f"Exit: -{INITIAL_STOP_PCT*100:.0f}% stop | trail +{TRAIL_ACTIVATE_PCT*100:.0f}% "
            f"(offset {TRAIL_OFFSET_PCT*100:.0f}%) | CE SELL\n"
            f"Position: {POSITION_PCT*100:.0f}% equity, max 10/day\n\n"
            f"Trades: {n}\n"
            f"Win rate: {100*wins/n:.1f}%\n"
            f"Total PnL: INR {pnl:,.2f}\n"
            f"Final equity: INR {final:,.2f}\n"
            f"Return: {(final/INITIAL_CAPITAL-1)*100:.2f}%\n"
            f"Avg hold: {sized['Hold Days'].mean():.1f} days\n\n"
            f"Exit reasons:\n{reason_lines}\n\nFile: {trades_path}\n"
        )

    sum_path.write_text(summary, encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()
