"""
RSI(25) vs RSI(100) + Chandelier Exit — dual backtest.

Aligns with StockX: Wilder RSI (same seed as rsi_indicator.dart) and
Chandelier Exit (TradingView-style, matching chandelier_exit_indicator.dart).

Separate output files:
  - rsi25_100_ce_buy_trades.csv   — longs: RSI fast crosses above slow while CE=BUY
  - rsi25_100_ce_sell_trades.csv  — shorts: RSI fast crosses below slow while CE=SELL
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import yfinance as yf

import config
from fetch_nse_data import NSE_SYMBOLS

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output"

# ── Strategy (match app defaults) ───────────────────────────────────────────
RSI_FAST = 25
RSI_SLOW = 100
CE_PERIOD = 22
CE_MULTIPLIER = 3.0

INITIAL_CAPITAL = 500_000.0
POSITION_PCT = 0.10
MAX_NEW_POSITIONS_PER_DAY = 10

MIN_PRICE = 10.0
MIN_BARS = 220


def load_symbols(csv_path: Path | None, limit: int | None) -> list[str]:
    from fetch_symbol_registry import filter_symbols

    if csv_path is not None and csv_path.is_file():
        base = (
            pd.read_csv(csv_path)["Symbol"]
            .dropna()
            .astype(str)
            .str.strip()
            .unique()
            .tolist()
        )
    else:
        base = filter_symbols(list(NSE_SYMBOLS))
    if limit is not None:
        base = base[:limit]
    return [f"{s}.NS" for s in base]


def rsi_wilder_series(closes: np.ndarray, period: int) -> np.ndarray:
    """Same as Dart RsiIndicator._rsiSeries — first RSI at bar index [period]."""
    n = len(closes)
    rsi = np.full(n, np.nan)
    if n < period + 1:
        return rsi

    avg_gain = 0.0
    avg_loss = 0.0
    for i in range(1, period + 1):
        d = closes[i] - closes[i - 1]
        if d > 0:
            avg_gain += d
        else:
            avg_loss += -d
    avg_gain /= period
    avg_loss /= period

    rsi[period] = 100.0 if avg_loss == 0 else 100.0 - 100.0 / (1.0 + avg_gain / avg_loss)

    for i in range(period + 1, n):
        d = closes[i] - closes[i - 1]
        g = d if d > 0 else 0.0
        l = -d if d < 0 else 0.0
        avg_gain = (avg_gain * (period - 1) + g) / period
        avg_loss = (avg_loss * (period - 1) + l) / period
        rsi[i] = 100.0 if avg_loss == 0 else 100.0 - 100.0 / (1.0 + avg_gain / avg_loss)

    return rsi


def wilder_atr_from_tr(tr: np.ndarray, period: int) -> np.ndarray:
    """Wilder-smoothed ATR from TR series — matches IndicatorUtils.atr path."""
    if len(tr) < period:
        return np.array([])
    nout = len(tr) - period + 1
    out = np.zeros(nout)
    out[0] = tr[:period].mean()
    for i in range(1, nout):
        out[i] = (out[i - 1] * (period - 1) + tr[period + i - 1]) / period
    return out


def chandelier_direction(high: np.ndarray, low: np.ndarray, close: np.ndarray) -> np.ndarray:
    """
    Returns +1 BUY / -1 SELL per bar (Chandelier Exit), NaN until first CE bar.
    Matches Screener/new_combined_strategy.py calculate_ce_signals().
    """
    n = len(close)
    p = CE_PERIOD if n >= 100 else 14

    tr = np.zeros(n)
    tr[0] = high[0] - low[0]
    tr[1:] = np.maximum(
        high[1:] - low[1:],
        np.maximum(
            np.abs(high[1:] - close[:-1]),
            np.abs(low[1:] - close[:-1]),
        ),
    )

    atr = np.full(n, np.nan)
    atr[p - 1] = tr[:p].mean()
    for i in range(p, n):
        atr[i] = atr[i - 1] + (tr[i] - atr[i - 1]) / p

    highest_close = pd.Series(close).rolling(window=p).max().values
    lowest_close = pd.Series(close).rolling(window=p).min().values
    raw_long = highest_close - CE_MULTIPLIER * atr
    raw_short = lowest_close + CE_MULTIPLIER * atr

    trail_long = np.full(n, np.nan)
    trail_short = np.full(n, np.nan)
    dir_out = np.full(n, np.nan)
    dir_list = [1]

    trail_long[0] = raw_long[0]
    trail_short[0] = raw_short[0]
    dir_out[0] = 1.0

    for i in range(1, n):
        prev_close = close[i - 1]
        if not np.isnan(trail_long[i - 1]) and not np.isnan(raw_long[i]):
            trail_long[i] = max(raw_long[i], trail_long[i - 1]) if prev_close > trail_long[i - 1] else raw_long[i]
        else:
            trail_long[i] = raw_long[i] if not np.isnan(raw_long[i]) else trail_long[i - 1]

        if not np.isnan(trail_short[i - 1]) and not np.isnan(raw_short[i]):
            trail_short[i] = min(raw_short[i], trail_short[i - 1]) if prev_close < trail_short[i - 1] else raw_short[i]
        else:
            trail_short[i] = raw_short[i] if not np.isnan(raw_short[i]) else trail_short[i - 1]

        c = close[i]
        prev_short = trail_short[i - 1]
        prev_long = trail_long[i - 1]
        if not np.isnan(prev_short) and c > prev_short:
            dir_list.append(1)
        elif not np.isnan(prev_long) and c < prev_long:
            dir_list.append(-1)
        else:
            dir_list.append(dir_list[-1])
        dir_out[i] = float(dir_list[-1])

    return dir_out


def bull_cross(rf: np.ndarray, rs: np.ndarray, i: int) -> bool:
    if i < 1 or np.isnan(rf[i]) or np.isnan(rs[i]):
        return False
    return (not np.isnan(rf[i - 1]) and not np.isnan(rs[i - 1]) and rf[i - 1] <= rs[i - 1] and rf[i] > rs[i])


def bear_cross(rf: np.ndarray, rs: np.ndarray, i: int) -> bool:
    if i < 1 or np.isnan(rf[i]) or np.isnan(rs[i]):
        return False
    return (not np.isnan(rf[i - 1]) and not np.isnan(rs[i - 1]) and rf[i - 1] >= rs[i - 1] and rf[i] < rs[i])


def simulate_long(df: np.ndarray, symbol: str, dates: pd.DatetimeIndex) -> list[dict]:
    o, h, l, c = (df[:, 0], df[:, 1], df[:, 2], df[:, 3])
    rf = rsi_wilder_series(c, RSI_FAST)
    rs = rsi_wilder_series(c, RSI_SLOW)
    ce = chandelier_direction(h, l, c)
    n = len(c)
    trades = []
    i = RSI_SLOW
    while i < n - 2:
        if c[i] < MIN_PRICE:
            i += 1
            continue
        if bull_cross(rf, rs, i) and ce[i] == 1.0:
            entry_i = i + 1
            entry_px = float(o[entry_i])
            entry_dt = dates[entry_i]
            if entry_px <= 0 or np.isnan(entry_px):
                i += 1
                continue
            exit_i = None
            exit_px = None
            reason = None
            for j in range(entry_i, n):
                if j < n - 1 and bear_cross(rf, rs, j):
                    exit_i = j + 1
                    exit_px = float(o[exit_i])
                    reason = "RSI cross down"
                    break
                if ce[j] == -1.0:
                    exit_i = min(j + 1, n - 1)
                    exit_px = float(o[exit_i])
                    reason = "CE SELL"
                    break
            if exit_i is None:
                exit_i = n - 1
                exit_px = float(c[exit_i])
                reason = "End of data"
            ret = (exit_px - entry_px) / entry_px * 100
            trades.append(
                {
                    "Symbol": symbol,
                    "Signal Date": dates[i].strftime("%Y-%m-%d"),
                    "Entry Date": entry_dt.strftime("%Y-%m-%d"),
                    "Entry Price": round(entry_px, 4),
                    "Exit Date": dates[exit_i].strftime("%Y-%m-%d"),
                    "Exit Price": round(exit_px, 4),
                    "Exit Reason": reason,
                    "Return %": round(ret, 2),
                }
            )
            i = exit_i + 1
        else:
            i += 1
    return trades


def simulate_short(df: np.ndarray, symbol: str, dates: pd.DatetimeIndex) -> list[dict]:
    o, h, l, c = (df[:, 0], df[:, 1], df[:, 2], df[:, 3])
    rf = rsi_wilder_series(c, RSI_FAST)
    rs = rsi_wilder_series(c, RSI_SLOW)
    ce = chandelier_direction(h, l, c)
    n = len(c)
    trades = []
    i = RSI_SLOW
    while i < n - 2:
        if c[i] < MIN_PRICE:
            i += 1
            continue
        if bear_cross(rf, rs, i) and ce[i] == -1.0:
            entry_i = i + 1
            entry_px = float(o[entry_i])
            entry_dt = dates[entry_i]
            if entry_px <= 0 or np.isnan(entry_px):
                i += 1
                continue
            exit_i = None
            exit_px = None
            reason = None
            for j in range(entry_i, n):
                if j < n - 1 and bull_cross(rf, rs, j):
                    exit_i = j + 1
                    exit_px = float(o[exit_i])
                    reason = "RSI cross up"
                    break
                if ce[j] == 1.0:
                    exit_i = min(j + 1, n - 1)
                    exit_px = float(o[exit_i])
                    reason = "CE BUY"
                    break
            if exit_i is None:
                exit_i = n - 1
                exit_px = float(c[exit_i])
                reason = "End of data"
            ret = (entry_px - exit_px) / entry_px * 100
            trades.append(
                {
                    "Symbol": symbol,
                    "Signal Date": dates[i].strftime("%Y-%m-%d"),
                    "Entry Date": entry_dt.strftime("%Y-%m-%d"),
                    "Entry Price": round(entry_px, 4),
                    "Exit Date": dates[exit_i].strftime("%Y-%m-%d"),
                    "Exit Price": round(exit_px, 4),
                    "Exit Reason": reason,
                    "Return %": round(ret, 2),
                }
            )
            i = exit_i + 1
        else:
            i += 1
    return trades


def size_trades_long(raw: list[dict], initial: float, position_pct: float) -> pd.DataFrame:
    if not raw:
        return pd.DataFrame()
    df = pd.DataFrame(raw)
    df["Entry Date"] = pd.to_datetime(df["Entry Date"])
    df = df.sort_values("Entry Date")
    equity = initial
    rows = []
    per_day: dict = {}
    for _, r in df.iterrows():
        d = r["Entry Date"].date()
        if per_day.get(d, 0) >= MAX_NEW_POSITIONS_PER_DAY:
            continue
        alloc = equity * position_pct
        entry = float(r["Entry Price"])
        exit_px = float(r["Exit Price"])
        if not np.isfinite(entry) or not np.isfinite(exit_px) or entry <= 0:
            continue
        shares = int(alloc // entry)
        if shares < 1:
            continue
        invested = shares * entry
        pnl = (exit_px - entry) * shares
        ret_pct = pnl / invested * 100 if invested else 0
        equity = equity + pnl
        per_day[d] = per_day.get(d, 0) + 1
        rows.append(
            {
                **r.to_dict(),
                "Equity at Entry": float(equity - pnl),
                "Shares": shares,
                "PnL": round(pnl, 2),
                "Return on position %": round(ret_pct, 2),
            }
        )
    return pd.DataFrame(rows)


def size_trades_short(raw: list[dict], initial: float, position_pct: float) -> pd.DataFrame:
    if not raw:
        return pd.DataFrame()
    df = pd.DataFrame(raw)
    df["Entry Date"] = pd.to_datetime(df["Entry Date"])
    df = df.sort_values("Entry Date")
    equity = initial
    rows = []
    per_day: dict = {}
    for _, r in df.iterrows():
        d = r["Entry Date"].date()
        if per_day.get(d, 0) >= MAX_NEW_POSITIONS_PER_DAY:
            continue
        alloc = equity * position_pct
        entry = float(r["Entry Price"])
        exit_px = float(r["Exit Price"])
        shares = int(alloc // entry)
        if shares < 1:
            continue
        invested = shares * entry
        pnl = (entry - exit_px) * shares
        ret_pct = pnl / invested * 100 if invested else 0
        equity = equity + pnl
        per_day[d] = per_day.get(d, 0) + 1
        rows.append(
            {
                **r.to_dict(),
                "Equity at Entry": float(equity - pnl),
                "Shares": shares,
                "PnL": round(pnl, 2),
                "Return on position %": round(ret_pct, 2),
            }
        )
    return pd.DataFrame(rows)


def yf_to_arrays(raw: pd.DataFrame):
    if isinstance(raw.columns, pd.MultiIndex):
        raw.columns = raw.columns.get_level_values(0)
    o = raw["Open"].values.astype(float)
    h = raw["High"].values.astype(float)
    l = raw["Low"].values.astype(float)
    c = raw["Close"].values.astype(float)
    v = raw["Volume"].values.astype(float)
    arr = np.column_stack([o, h, l, c, v])
    return arr, raw.index


def main() -> None:
    parser = argparse.ArgumentParser(description="RSI 25/100 + Chandelier Exit backtest")
    parser.add_argument("--symbols-csv", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    args = parser.parse_args()

    symbols = load_symbols(args.symbols_csv, args.limit)
    period = config.FETCH_RANGE.get("1d", "2y")
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)

    buy_raw: list[dict] = []
    sell_raw: list[dict] = []

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
            buy_raw.extend(simulate_long(arr, sym, dates))
            sell_raw.extend(simulate_short(arr, sym, dates))
        except Exception:
            continue
        if idx % 200 == 0:
            print(f"[{idx}/{len(symbols)}] ... buy_signals={len(buy_raw)} sell_signals={len(sell_raw)}")

    buy_sized = size_trades_long(buy_raw, INITIAL_CAPITAL, POSITION_PCT)
    sell_sized = size_trades_short(sell_raw, INITIAL_CAPITAL, POSITION_PCT)

    buy_path = out / "rsi25_100_ce_buy_trades.csv"
    sell_path = out / "rsi25_100_ce_sell_trades.csv"
    sum_path = out / "rsi25_100_ce_summary.txt"

    buy_sized.to_csv(buy_path, index=False)
    sell_sized.to_csv(sell_path, index=False)

    def summarize(name: str, df: pd.DataFrame) -> str:
        if df.empty:
            return f"{name}: no trades\n"
        pnl = df["PnL"].sum()
        n = len(df)
        w = (df["PnL"] > 0).sum()
        return (
            f"{name}\n"
            f"  Trades: {n}  Win rate: {100 * w / n:.1f}%\n"
            f"  Total PnL: INR {pnl:,.2f}\n"
        )

    summary = (
        f"RSI({RSI_FAST}) vs RSI({RSI_SLOW}) + Chandelier Exit ({CE_PERIOD}/{CE_MULTIPLIER})\n"
        f"Universe: {len(symbols)} symbols | Yahoo period={period}\n"
        f"Long: RSI fast crosses above slow on signal bar, CE=BUY; exit bearish cross or CE SELL\n"
        f"Short: RSI fast crosses below slow, CE=SELL; exit bullish cross or CE BUY\n"
        f"Position: {POSITION_PCT * 100:.0f}% of rolling equity, max {MAX_NEW_POSITIONS_PER_DAY}/day\n"
        f"\n"
        f"{summarize('CE BUY (long)', buy_sized)}"
        f"{summarize('CE SELL (short)', sell_sized)}"
        f"\nFiles:\n  {buy_path}\n  {sell_path}\n"
    )
    sum_path.write_text(summary, encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()
