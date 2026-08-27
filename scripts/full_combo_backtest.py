"""
Full combo long backtest: Sethi + ST + CE + RSI cross with managed exits.

Entry (all on signal bar, enter next open):
  - Sethi breakout filter (20D high, 50/200 DMA, volume, RSI 60-80)
  - Supertrend BUY
  - Chandelier Exit BUY
  - RSI(25) crosses above RSI(100)

Exit (daily high/low path, first hit):
  -5% stop | trail after +20% (5% below peak) | CE SELL | end of data
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
    RSI_FAST,
    RSI_SLOW,
    bull_cross,
    chandelier_direction,
    load_symbols,
    rsi_wilder_series,
    size_trades_long,
    yf_to_arrays,
)
from sethi_st_ce_backtest import sethi_buy_series, supertrend_direction
from st_ce_rsi_managed_backtest import (
    INITIAL_CAPITAL,
    INITIAL_STOP_PCT,
    POSITION_PCT,
    TRAIL_ACTIVATE_PCT,
    TRAIL_OFFSET_PCT,
    simulate_exit_path,
)

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output" / "full_combo_run"


def entry_signal(
    sethi: np.ndarray,
    st: np.ndarray,
    ce: np.ndarray,
    rf: np.ndarray,
    rs: np.ndarray,
    i: int,
) -> bool:
    if np.isnan(st[i]) or np.isnan(ce[i]):
        return False
    return (
        sethi[i] == 1.0
        and st[i] == 1.0
        and ce[i] == 1.0
        and bull_cross(rf, rs, i)
    )


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
    rf = rsi_wilder_series(c, RSI_FAST)
    rs = rsi_wilder_series(c, RSI_SLOW)
    st = supertrend_direction(h, l, c)
    ce = chandelier_direction(h, l, c)
    n = len(c)
    trades: list[dict] = []
    i = max(RSI_SLOW, MIN_BARS)

    while i < n - 2:
        if not entry_signal(sethi, st, ce, rf, rs, i):
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
    parser = argparse.ArgumentParser(description="Sethi+ST+CE+RSI cross managed long backtest")
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
            o, h, l, c, v = arr[:, 0], arr[:, 1], arr[:, 2], arr[:, 3], arr[:, 4]
            raw_trades.extend(simulate_long(o, h, l, c, v, sym, dates))
            processed += 1
        except Exception:
            continue
        if idx % 200 == 0:
            print(f"[{idx}/{len(symbols)}] trades={len(raw_trades)}")

    sized = size_trades_long(raw_trades, INITIAL_CAPITAL, POSITION_PCT)

    trades_path = out / "full_combo_trades.csv"
    sum_path = out / "full_combo_summary.txt"
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
        final_equity = INITIAL_CAPITAL + pnl
        summary = (
            f"Sethi + ST(10/3) + CE(22/3) + RSI({RSI_FAST}/{RSI_SLOW}) — MANAGED LONG\n"
            f"Universe: {len(symbols)} symbols ({processed} with data) | Yahoo period={period}\n"
            f"Entry: Sethi breakout + ST BUY + CE BUY + RSI({RSI_FAST}) cross above "
            f"RSI({RSI_SLOW}), enter next open\n"
            f"Exit: -{INITIAL_STOP_PCT*100:.0f}% stop | trail after +{TRAIL_ACTIVATE_PCT*100:.0f}% "
            f"(offset {TRAIL_OFFSET_PCT*100:.0f}%) | CE SELL | end of data\n"
            f"Position: {POSITION_PCT * 100:.0f}% rolling equity, max 10/day\n"
            f"\n"
            f"Trades: {n}\n"
            f"Win rate: {100 * wins / n:.1f}%\n"
            f"Total PnL: INR {pnl:,.2f}\n"
            f"Final equity: INR {final_equity:,.2f}\n"
            f"Return: {(final_equity / INITIAL_CAPITAL - 1) * 100:.2f}%\n"
            f"Avg hold: {avg_hold:.1f} calendar days\n"
            f"\nExit reasons:\n{reason_lines}\n"
            f"\nFile: {trades_path}\n"
        )

    sum_path.write_text(summary, encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()
