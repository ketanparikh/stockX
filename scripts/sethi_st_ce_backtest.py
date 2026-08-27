"""
Sethi + Supertrend + Chandelier Exit — triple-alignment long backtest.

Entry:  Sethi setup BUY + Supertrend BUY + CE BUY on the same bar (enter next open).
Exit:   Supertrend SELL or CE SELL only (default), or any of three (--exit-mode any).

Indicators match StockX / Screener defaults:
  - Sethi: 20D high breakout, 50/200 DMA, volume, RSI 60–80 (sethi_indicator.dart)
  - Supertrend: ATR 10, multiplier 3 (Zerodha)
  - Chandelier Exit: 22/3 close-based (new_combined_strategy.py)
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import yfinance as yf

import config
from fetch_nse_data import NSE_SYMBOLS
from rsi_ce_backtest import chandelier_direction, load_symbols, size_trades_long

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output" / "sethi_st_ce_run"

# Sethi (matches AppConstants / sethi_indicator.dart)
SETHI_HIGH_LB = 20
SETHI_DMA_FAST = 50
SETHI_DMA_SLOW = 200
SETHI_VOL_LB = 20
SETHI_VOL_MULT = 1.5
SETHI_RSI_PERIOD = 14
SETHI_RSI_MIN = 60.0
SETHI_RSI_MAX = 80.0
SETHI_MIN_PRICE = 50.0
SETHI_MIN_AVG_VALUE = 10_000_000.0

ST_PERIOD = 10
ST_MULT = 3.0

INITIAL_CAPITAL = 500_000.0
POSITION_PCT = 0.10
MAX_NEW_POSITIONS_PER_DAY = 10
MIN_BARS = 220


def _sma(values: np.ndarray, period: int) -> np.ndarray:
    n = len(values)
    out = np.full(n, np.nan)
    if n < period:
        return out
    s = values[:period].sum()
    out[period - 1] = s / period
    for i in range(period, n):
        s += values[i] - values[i - period]
        out[i] = s / period
    return out


def _rolling_max_shift(values: np.ndarray, period: int, shift: int = 1) -> np.ndarray:
    n = len(values)
    out = np.full(n, np.nan)
    for i in range(period + shift - 1, n):
        end = i - shift
        if end < period - 1:
            continue
        out[i] = values[end - period + 1 : end + 1].max()
    return out


def _rsi_series(closes: np.ndarray, period: int) -> np.ndarray:
    n = len(closes)
    out = np.full(n, np.nan)
    if n < period + 1:
        return out
    avg_gain = avg_loss = 0.0
    for i in range(1, period + 1):
        d = closes[i] - closes[i - 1]
        if d > 0:
            avg_gain += d
        else:
            avg_loss += -d
    avg_gain /= period
    avg_loss /= period
    out[period] = 100.0 if avg_loss == 0 else 100.0 - 100.0 / (1.0 + avg_gain / avg_loss)
    for i in range(period + 1, n):
        d = closes[i] - closes[i - 1]
        g = d if d > 0 else 0.0
        l = -d if d < 0 else 0.0
        avg_gain = (avg_gain * (period - 1) + g) / period
        avg_loss = (avg_loss * (period - 1) + l) / period
        out[i] = 100.0 if avg_loss == 0 else 100.0 - 100.0 / (1.0 + avg_gain / avg_loss)
    return out


def sethi_buy_series(
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    v: np.ndarray,
) -> np.ndarray:
    """+1 when Sethi setup active, 0 otherwise (no explicit SELL)."""
    n = len(c)
    out = np.zeros(n)
    dma50 = _sma(c, SETHI_DMA_FAST)
    dma200 = _sma(c, SETHI_DMA_SLOW)
    high20 = _rolling_max_shift(h, SETHI_HIGH_LB, shift=1)
    vol20 = _sma(v, SETHI_VOL_LB)
    avg_val = _sma(c * v, SETHI_VOL_LB)
    rsi = _rsi_series(c, SETHI_RSI_PERIOD)

    for i in range(n):
        if (
            np.isnan(dma50[i])
            or np.isnan(dma200[i])
            or np.isnan(high20[i])
            or np.isnan(vol20[i])
            or np.isnan(avg_val[i])
            or np.isnan(rsi[i])
        ):
            continue
        if (
            c[i] > high20[i]
            and c[i] > dma50[i]
            and dma50[i] > dma200[i]
            and v[i] > SETHI_VOL_MULT * vol20[i]
            and SETHI_RSI_MIN <= rsi[i] <= SETHI_RSI_MAX
            and c[i] >= SETHI_MIN_PRICE
            and avg_val[i] >= SETHI_MIN_AVG_VALUE
        ):
            out[i] = 1.0
    return out


def supertrend_direction(h: np.ndarray, l: np.ndarray, c: np.ndarray) -> np.ndarray:
    """+1 BUY / -1 SELL per bar; NaN until warmed up."""
    n = len(c)
    out = np.full(n, np.nan)
    if n < ST_PERIOD + 2:
        return out

    tr = np.zeros(n)
    tr[0] = h[0] - l[0]
    for i in range(1, n):
        tr[i] = max(h[i] - l[i], abs(h[i] - c[i - 1]), abs(l[i] - c[i - 1]))

    atr = np.full(n, np.nan)
    atr[ST_PERIOD - 1] = tr[:ST_PERIOD].mean()
    for i in range(ST_PERIOD, n):
        atr[i] = atr[i - 1] + (tr[i] - atr[i - 1]) / ST_PERIOD

    start = ST_PERIOD - 1
    m = n - start
    upper = np.zeros(m)
    lower = np.zeros(m)
    bull = np.ones(m, dtype=bool)

    i0 = start
    hl2 = (h[i0] + l[i0]) / 2
    upper[0] = hl2 + ST_MULT * atr[i0]
    lower[0] = hl2 - ST_MULT * atr[i0]

    for k in range(1, m):
        ci = start + k
        pc = c[ci - 1]
        hl2 = (h[ci] + l[ci]) / 2
        bu = hl2 + ST_MULT * atr[ci]
        bl = hl2 - ST_MULT * atr[ci]
        lower[k] = bl if (bl > lower[k - 1] or pc < lower[k - 1]) else lower[k - 1]
        upper[k] = bu if (bu < upper[k - 1] or pc > upper[k - 1]) else upper[k - 1]
        if bull[k - 1]:
            bull[k] = c[ci] >= lower[k - 1]
        else:
            bull[k] = c[ci] > upper[k - 1]

    for k in range(m):
        out[start + k] = 1.0 if bull[k] else -1.0
    return out


def triple_buy(sethi: np.ndarray, st: np.ndarray, ce: np.ndarray, i: int) -> bool:
    return sethi[i] == 1.0 and st[i] == 1.0 and ce[i] == 1.0


def exit_reason(
    sethi: np.ndarray,
    st: np.ndarray,
    ce: np.ndarray,
    i: int,
    mode: str = "st_ce",
) -> str | None:
    if mode == "any":
        if sethi[i] != 1.0:
            return "Sethi off"
    if st[i] == -1.0:
        return "Supertrend SELL"
    if ce[i] == -1.0:
        return "CE SELL"
    return None


def simulate_long(
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    v: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
    exit_mode: str = "st_ce",
) -> list[dict]:
    sethi = sethi_buy_series(o, h, l, c, v)
    st = supertrend_direction(h, l, c)
    ce = chandelier_direction(h, l, c)
    n = len(c)
    trades: list[dict] = []
    i = MIN_BARS
    while i < n - 2:
        if not triple_buy(sethi, st, ce, i):
            i += 1
            continue

        entry_i = i + 1
        entry_px = float(o[entry_i])
        if entry_px <= 0 or np.isnan(entry_px):
            i += 1
            continue

        exit_i = None
        exit_px = None
        reason = None
        for j in range(entry_i, n - 1):
            r = exit_reason(sethi, st, ce, j, exit_mode)
            if r is not None:
                exit_i = j + 1
                exit_px = float(o[exit_i])
                reason = r
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


def yf_to_arrays(raw: pd.DataFrame) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray, pd.DatetimeIndex]:
    if isinstance(raw.columns, pd.MultiIndex):
        raw.columns = raw.columns.get_level_values(0)
    o = raw["Open"].values.astype(float)
    h = raw["High"].values.astype(float)
    l = raw["Low"].values.astype(float)
    c = raw["Close"].values.astype(float)
    v = raw["Volume"].values.astype(float)
    return o, h, l, c, v, raw.index


def main() -> None:
    parser = argparse.ArgumentParser(description="Sethi + Supertrend + CE triple BUY backtest")
    parser.add_argument("--symbols-csv", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    parser.add_argument(
        "--exit-mode",
        choices=["st_ce", "any"],
        default="st_ce",
        help="st_ce = exit on Supertrend/CE SELL only; any = also Sethi off",
    )
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
            o, h, l, c, v, dates = yf_to_arrays(raw)
            raw_trades.extend(simulate_long(o, h, l, c, v, sym, dates, args.exit_mode))
            processed += 1
        except Exception:
            continue
        if idx % 200 == 0:
            print(f"[{idx}/{len(symbols)}] trades={len(raw_trades)}")

    sized = size_trades_long(raw_trades, INITIAL_CAPITAL, POSITION_PCT)

    trades_path = out / "sethi_st_ce_trades.csv"
    sum_path = out / "sethi_st_ce_summary.txt"
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
        exit_desc = (
            "Supertrend SELL OR CE SELL only"
            if args.exit_mode == "st_ce"
            else "Sethi off OR Supertrend SELL OR CE SELL"
        )
        summary = (
            f"Sethi + Supertrend({ST_PERIOD}/{ST_MULT}) + CE(22/3) — LONG ONLY\n"
            f"Universe: {len(symbols)} symbols ({processed} with data) | Yahoo period={period}\n"
            f"Entry: all three BUY on signal bar, enter next open\n"
            f"Exit: {exit_desc}, exit next open\n"
            f"Position: {POSITION_PCT * 100:.0f}% rolling equity, max {MAX_NEW_POSITIONS_PER_DAY}/day\n"
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
