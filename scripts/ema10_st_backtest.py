"""
EMA 10 Cross + Supertrend long backtest.

Entry:  EMA 10 Cross BUY (close > 10/200, 10 above 30 & 48, completing
        up-cross within lookback) AND Supertrend BUY. Enter next open.

Exit:   first of Supertrend SELL OR EMA 10 below 30 & 48 (completing
        down-cross within lookback). Exit next open.
        Open trades at end of data close at last close.

Position: 10% rolling equity, max 10 new entries per day.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import yfinance as yf

import config
from ema10_cross_backtest import LOOKBACK, MIN_BARS, TREND, entry_exit_series
from rsi_ce_backtest import INITIAL_CAPITAL, POSITION_PCT, load_symbols, size_trades_long, yf_to_arrays
from sethi_st_ce_backtest import supertrend_direction

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output" / "ema10_st_run"


def simulate_long(
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
    lookback: int,
) -> list[dict]:
    ema_entry, ema_exit = entry_exit_series(c, lookback)
    st = supertrend_direction(h, l, c)
    n = len(c)
    trades: list[dict] = []
    i = TREND

    while i < n - 2:
        st_buy = st[i] == 1.0
        if not (ema_entry[i] and st_buy):
            i += 1
            continue

        entry_i = i + 1
        entry_px = float(o[entry_i])
        if entry_px <= 0 or not np.isfinite(entry_px):
            i += 1
            continue

        exit_i = n - 1
        exit_px = float(c[exit_i])
        reason = "End of data"
        for j in range(entry_i, n - 1):
            st_sell = st[j] == -1.0
            ema_sell = bool(ema_exit[j])
            if not (st_sell or ema_sell):
                continue
            if st_sell and ema_sell:
                why = "ST SELL + EMA 10 below 30 & 48"
            elif st_sell:
                why = "Supertrend SELL"
            else:
                why = "EMA 10 below 30 & 48"
            nxt = j + 1
            px = float(o[nxt])
            if np.isfinite(px) and px > 0:
                exit_i, exit_px, reason = nxt, px, why
            else:
                exit_i, exit_px, reason = j, float(c[j]), why
            break

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
    parser = argparse.ArgumentParser(description="EMA 10 Cross + Supertrend NSE backtest")
    parser.add_argument("--symbols-csv", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--lookback", type=int, default=LOOKBACK)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    args = parser.parse_args()

    symbols = load_symbols(args.symbols_csv, args.limit)
    period = config.FETCH_RANGE.get("1d", "2y")
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)

    print(
        f"EMA 10 Cross + Supertrend backtest | symbols={len(symbols)} "
        f"period={period} lookback={args.lookback}",
        flush=True,
    )

    raw_trades: list[dict] = []
    processed = 0

    for idx, sym in enumerate(symbols, 1):
        try:
            raw = yf.download(
                sym, period=period, progress=False, auto_adjust=False, threads=False
            )
            if raw.empty or len(raw) < MIN_BARS:
                continue
            arr, dates = yf_to_arrays(raw)
            o, h, l, c = arr[:, 0], arr[:, 1], arr[:, 2], arr[:, 3]
            raw_trades.extend(simulate_long(o, h, l, c, sym, dates, args.lookback))
            processed += 1
        except Exception:
            continue
        if idx == 1 or idx % 200 == 0:
            print(
                f"[{idx}/{len(symbols)}] processed={processed} trades={len(raw_trades)}",
                flush=True,
            )

    sized = size_trades_long(raw_trades, INITIAL_CAPITAL, POSITION_PCT)
    trades_path = out / "ema10_st_trades.csv"
    sum_path = out / "ema10_st_summary.txt"
    sized.to_csv(trades_path, index=False)

    if sized.empty:
        summary = "No trades generated.\n"
    else:
        pnl = float(sized["PnL"].sum())
        n = len(sized)
        wins = int((sized["PnL"] > 0).sum())
        losses = int((sized["PnL"] < 0).sum())
        win_pnl = float(sized.loc[sized["PnL"] > 0, "PnL"].sum())
        loss_pnl = float(sized.loc[sized["PnL"] < 0, "PnL"].sum())
        pf = abs(win_pnl / loss_pnl) if loss_pnl != 0 else float("inf")
        reasons = sized["Exit Reason"].value_counts()
        reason_lines = "\n".join(f"    {k}: {v}" for k, v in reasons.items())
        final = INITIAL_CAPITAL + pnl
        avg_win = f"INR {win_pnl / wins:,.2f}" if wins else "n/a"
        avg_loss = f"INR {loss_pnl / losses:,.2f}" if losses else "n/a"
        summary = (
            f"EMA 10 Cross + Supertrend — LONG\n"
            f"Universe: {len(symbols)} ({processed} with data) | period={period}\n"
            f"Entry: EMA 10 Cross BUY AND Supertrend BUY, next open\n"
            f"Exit: Supertrend SELL OR EMA10 below 30 & 48 "
            f"(lookback {args.lookback}), next open | end of data\n"
            f"Position: {POSITION_PCT * 100:.0f}% equity, max 10/day\n\n"
            f"Trades: {n}\n"
            f"Win rate: {100 * wins / n:.1f}% ({wins}W / {losses}L)\n"
            f"Avg win: {avg_win}\n"
            f"Avg loss: {avg_loss}\n"
            f"Profit factor: {pf:.2f}\n"
            f"Total PnL: INR {pnl:,.2f}\n"
            f"Final equity: INR {final:,.2f}\n"
            f"Return: {(final / INITIAL_CAPITAL - 1) * 100:.2f}%\n"
            f"Avg hold: {sized['Hold Days'].mean():.1f} days\n\n"
            f"Exit reasons:\n{reason_lines}\n\nFile: {trades_path}\n"
        )

    sum_path.write_text(summary, encoding="utf-8")
    print(summary, flush=True)


if __name__ == "__main__":
    main()
