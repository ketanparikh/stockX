"""
EMA 10 Cross long backtest (matches lib/indicators/ema_10_cross_indicator.dart).

Entry:  Close > EMA10 > EMA200, close > EMA200, EMA10 > EMA30 and EMA48,
        and the later of the 10/30 and 10/48 up-crosses is within LOOKBACK bars.
        Enter next open.

Exit:   EMA10 < EMA30 and EMA10 < EMA48, later of the two down-crosses
        within LOOKBACK bars. Exit next open.
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
from rsi_ce_backtest import INITIAL_CAPITAL, POSITION_PCT, load_symbols, size_trades_long, yf_to_arrays
from stock_quality_filter import ema

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output" / "ema10_cross_run"

LOOKBACK = 5
FAST = 10
MID_FAST = 30
MID_SLOW = 48
TREND = 200
MIN_BARS = TREND + 2


def _cross_flags(fast: np.ndarray, slow: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Forward-scan last valid up/down cross index (NaN-safe)."""
    n = len(fast)
    last_up = np.full(n, -1, dtype=int)
    last_down = np.full(n, -1, dtype=int)
    up = -1
    down = -1
    for i in range(1, n):
        f, s, pf, ps = fast[i], slow[i], fast[i - 1], slow[i - 1]
        if not (np.isfinite(f) and np.isfinite(s) and np.isfinite(pf) and np.isfinite(ps)):
            up, down = -1, -1
        else:
            if f <= s:
                up = -1
            elif pf <= ps and f > s:
                up = i
            if f >= s:
                down = -1
            elif pf >= ps and f < s:
                down = i
        last_up[i] = up
        last_down[i] = down
    return last_up, last_down


def entry_exit_series(
    close: np.ndarray,
    lookback: int = LOOKBACK,
) -> tuple[np.ndarray, np.ndarray]:
    e10 = ema(close, FAST)
    e30 = ema(close, MID_FAST)
    e48 = ema(close, MID_SLOW)
    e200 = ema(close, TREND)
    up30, down30 = _cross_flags(e10, e30)
    up48, down48 = _cross_flags(e10, e48)

    n = len(close)
    is_entry = np.zeros(n, dtype=bool)
    is_exit = np.zeros(n, dtype=bool)
    for i in range(TREND, n):
        a10, a30, a48, a200, px = e10[i], e30[i], e48[i], e200[i], close[i]
        if not (
            np.isfinite(a10)
            and np.isfinite(a30)
            and np.isfinite(a48)
            and np.isfinite(a200)
            and np.isfinite(px)
        ):
            continue

        above_stack = px > a10 > a200 and px > a200 and a10 > a30 and a10 > a48
        if above_stack and up30[i] >= 0 and up48[i] >= 0:
            completing = min(i - int(up30[i]), i - int(up48[i]))
            if completing <= lookback:
                is_entry[i] = True

        below_both = a10 < a30 and a10 < a48
        if below_both and down30[i] >= 0 and down48[i] >= 0:
            completing = min(i - int(down30[i]), i - int(down48[i]))
            if completing <= lookback:
                is_exit[i] = True

    return is_entry, is_exit


def simulate_long(
    o: np.ndarray,
    c: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
    lookback: int,
) -> list[dict]:
    is_entry, is_exit = entry_exit_series(c, lookback)
    n = len(c)
    trades: list[dict] = []
    i = TREND

    while i < n - 2:
        if not is_entry[i]:
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
            if is_exit[j]:
                nxt = j + 1
                px = float(o[nxt])
                if np.isfinite(px) and px > 0:
                    exit_i, exit_px, reason = nxt, px, "EMA 10 below 30 & 48"
                else:
                    exit_i, exit_px, reason = j, float(c[j]), "EMA 10 below 30 & 48"
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
    parser = argparse.ArgumentParser(description="EMA 10 Cross entry/exit NSE backtest")
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
        f"EMA 10 Cross backtest | symbols={len(symbols)} period={period} lookback={args.lookback}",
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
            o, c = arr[:, 0], arr[:, 3]
            raw_trades.extend(simulate_long(o, c, sym, dates, args.lookback))
            processed += 1
        except Exception:
            continue
        if idx == 1 or idx % 200 == 0:
            print(f"[{idx}/{len(symbols)}] processed={processed} trades={len(raw_trades)}", flush=True)

    sized = size_trades_long(raw_trades, INITIAL_CAPITAL, POSITION_PCT)
    trades_path = out / "ema10_cross_trades.csv"
    sum_path = out / "ema10_cross_summary.txt"
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
            f"EMA 10 Cross — LONG\n"
            f"Universe: {len(symbols)} ({processed} with data) | period={period}\n"
            f"Entry: close > EMA10 > EMA200, 10 above 30 & 48 "
            f"(completing up-cross <= {args.lookback} bars), next open\n"
            f"Exit: EMA10 below 30 & 48 (completing down-cross <= {args.lookback} bars), "
            f"next open | end of data\n"
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
