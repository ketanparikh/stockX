"""
Validate EMA 10 Cross rules against Dart (same SMA-seeded EMA).

BUY when:
  close > EMA10 > EMA200 and close > EMA200
  EMA10 > EMA30 and EMA10 > EMA48
  min(bars since 10×30 cross, bars since 10×48 cross) <= lookback
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
import yfinance as yf

from stock_quality_filter import ema

LOOKBACK = 5
SAMPLE = [
    "RELIANCE.NS",
    "TCS.NS",
    "HDFCBANK.NS",
    "INFY.NS",
    "ICICIBANK.NS",
    "SBIN.NS",
    "BHARTIARTL.NS",
    "ITC.NS",
    "LT.NS",
    "AXISBANK.NS",
    "KOTAKBANK.NS",
    "HINDUNILVR.NS",
    "BAJFINANCE.NS",
    "MARUTI.NS",
    "SUNPHARMA.NS",
    "TITAN.NS",
    "ULTRACEMCO.NS",
    "ASIANPAINT.NS",
    "NESTLEIND.NS",
    "POWERGRID.NS",
    "NTPC.NS",
    "ONGC.NS",
    "COALINDIA.NS",
    "TATAMOTORS.NS",
    "TATASTEEL.NS",
    "JSWSTEEL.NS",
    "ADANIENT.NS",
    "ADANIPORTS.NS",
    "WIPRO.NS",
    "HCLTECH.NS",
    "TECHM.NS",
    "BEL.NS",
    "HAL.NS",
    "POLYCAB.NS",
    "DIXON.NS",
    "SOLARINDS.NS",
    "CGPOWER.NS",
    "BSE.NS",
    "MCX.NS",
    "MAXHEALTH.NS",
]


@dataclass
class Check:
    symbol: str
    close: float
    e10: float
    e30: float
    e48: float
    e200: float
    above_10_200: bool
    above_30: bool
    above_48: bool
    age30: int | None
    age48: int | None
    buy: bool


def bars_since_cross_above(fast: np.ndarray, slow: np.ndarray, end: int) -> int | None:
    f_now, s_now = fast[end], slow[end]
    if not np.isfinite(f_now) or not np.isfinite(s_now) or f_now <= s_now:
        return None
    for i in range(end, 0, -1):
        f, s, pf, ps = fast[i], slow[i], fast[i - 1], slow[i - 1]
        if not all(np.isfinite(x) for x in (f, s, pf, ps)):
            return None
        if pf <= ps and f > s:
            return end - i
        if f <= s:
            return None
    return None


def evaluate(closes: np.ndarray, lookback: int = LOOKBACK) -> dict | None:
    n = len(closes)
    if n < 201:
        return None
    e10 = ema(closes, 10)
    e30 = ema(closes, 30)
    e48 = ema(closes, 48)
    e200 = ema(closes, 200)
    i = n - 1
    vals = (closes[i], e10[i], e30[i], e48[i], e200[i])
    if any(not np.isfinite(v) for v in vals):
        return None
    close, a10, a30, a48, a200 = (float(v) for v in vals)
    above_10200 = close > a10 and close > a200 and a10 > a200
    above_30 = a10 > a30
    above_48 = a10 > a48
    age30 = bars_since_cross_above(e10, e30, i)
    age48 = bars_since_cross_above(e10, e48, i)
    completing = None
    if age30 is not None and age48 is not None:
        completing = min(age30, age48)
    buy = (
        above_10200
        and above_30
        and above_48
        and completing is not None
        and completing <= lookback
    )
    return {
        "close": close,
        "e10": a10,
        "e30": a30,
        "e48": a48,
        "e200": a200,
        "above_10_200": above_10200,
        "above_30": above_30,
        "above_48": above_48,
        "age30": age30,
        "age48": age48,
        "completing": completing,
        "buy": buy,
    }


def synthetic_closes(extra_hold: int = 0) -> np.ndarray:
    closes = [50.0] * 220
    closes += [50 + i * 1.4 for i in range(1, 81)]
    closes += [162 - i * 3.2 for i in range(1, 19)]
    last_dip = 162 - 18 * 3.2
    closes += [last_dip + i * 8 for i in range(1, 5)]
    bounce_end = last_dip + 4 * 8
    closes += [bounce_end + i * 0.2 for i in range(extra_hold)]
    return np.array(closes, dtype=float)


def main() -> None:
    syn = evaluate(synthetic_closes(extra_hold=6))
    stale = evaluate(synthetic_closes(extra_hold=20))
    print("=== Synthetic (same series as Dart test) ===")
    print(f"  recross lookback=5: buy={syn['buy']} age30={syn['age30']} age48={syn['age48']}")
    print(
        f"    close={syn['close']:.2f} 10={syn['e10']:.2f} 30={syn['e30']:.2f} "
        f"48={syn['e48']:.2f} 200={syn['e200']:.2f}"
    )
    print(
        f"    above10/200={syn['above_10_200']} 10>30={syn['above_30']} 10>48={syn['above_48']}"
    )
    print(f"  +20 hold bars:    buy={stale['buy']} age30={stale['age30']} age48={stale['age48']}")

    print(f"\n=== Live NSE sample ({len(SAMPLE)} names, 2y daily, lookback={LOOKBACK}) ===")
    passes: list[tuple[str, dict]] = []
    near: list[tuple[str, dict]] = []
    loaded = 0
    for idx, sym in enumerate(SAMPLE, 1):
        try:
            raw = yf.download(sym, period="2y", progress=False, auto_adjust=False, threads=False)
            if raw.empty:
                continue
            if isinstance(raw.columns, pd.MultiIndex):
                raw.columns = raw.columns.get_level_values(0)
            c = raw["Close"].astype(float).to_numpy()
            row = evaluate(c)
            if row is None:
                continue
            loaded += 1
            if row["buy"]:
                passes.append((sym, row))
            elif row["above_10_200"] and row["above_30"] and row["above_48"]:
                near.append((sym, row))
        except Exception:
            continue
        if idx % 15 == 0:
            print(f"  scanned {idx}/{len(SAMPLE)}")

    print(f"Loaded {loaded}. BUY matches: {len(passes)}. Above 10/200+30+48 but stale: {len(near)}")
    if passes:
        print("\nMatches:")
        for sym, r in passes:
            print(
                f"  {sym:<14} close={r['close']:.2f}  "
                f"10={r['e10']:.2f} 30={r['e30']:.2f} 48={r['e48']:.2f} 200={r['e200']:.2f}  "
                f"10x30={r['age30']}d 10x48={r['age48']}d"
            )
            assert r["close"] > r["e10"] > r["e200"]
            assert r["close"] > r["e200"]
            assert r["e10"] > r["e30"] and r["e10"] > r["e48"]
            assert min(r["age30"], r["age48"]) <= LOOKBACK
        print("  Independent condition checks: OK")
    else:
        print("No live BUY matches in this sample (filter is strict).")

    if near[:5]:
        print("\nAligned but completing cross older than lookback (first 5):")
        for sym, r in near[:5]:
            print(
                f"  {sym:<14} completing={r['completing']}d  "
                f"10x30={r['age30']}d 10x48={r['age48']}d"
            )


if __name__ == "__main__":
    main()
