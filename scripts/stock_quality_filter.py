"""
Stock quality gate — mirrors lib/filters/stock_quality_filter.dart for backtests.
"""

from __future__ import annotations

from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor, as_completed

import numpy as np
import yfinance as yf

# App defaults (lib/utils/constants.dart)
DEFAULT_MIN_MARKET_CAP_CRORE = 15_000.0
DEFAULT_VOLUME_LOOKBACK = 20
DEFAULT_VOLUME_MULTIPLIER = 1.5
DEFAULT_EMA20 = 20
DEFAULT_EMA50 = 50


def crore_to_inr(crore: float) -> float:
    return crore * 1e7


def ema(values: np.ndarray, period: int) -> np.ndarray:
    """SMA-seeded EMA; output[k] aligns with values[period - 1 + k]."""
    n = len(values)
    out = np.full(n, np.nan)
    if n < period:
        return out

    k = 2.0 / (period + 1)
    seed = float(np.mean(values[:period]))
    out[period - 1] = seed
    prev = seed
    for i in range(period, n):
        prev = values[i] * k + prev * (1 - k)
        out[i] = prev
    return out


@dataclass(frozen=True)
class QualityParams:
    min_market_cap_crore: float = DEFAULT_MIN_MARKET_CAP_CRORE
    volume_lookback: int = DEFAULT_VOLUME_LOOKBACK
    volume_multiplier: float = DEFAULT_VOLUME_MULTIPLIER
    ema20_period: int = DEFAULT_EMA20
    ema50_period: int = DEFAULT_EMA50
    require_above_ema20: bool = True
    require_above_ema50: bool = True
    use_market_cap: bool = True

    def label(self) -> str:
        parts: list[str] = []
        if self.use_market_cap and self.min_market_cap_crore > 0:
            parts.append(f"Mcap > {self.min_market_cap_crore:.0f} Cr")
        if self.volume_multiplier > 0:
            parts.append(
                f"Vol > {self.volume_multiplier:.1f}x {self.volume_lookback}D avg"
            )
        if self.require_above_ema20:
            parts.append(f"Close > EMA {self.ema20_period}")
        if self.require_above_ema50:
            parts.append(f"Close > EMA {self.ema50_period}")
        return " · ".join(parts)


def passes_at_bar(
    c: np.ndarray,
    v: np.ndarray,
    bar_i: int,
    params: QualityParams,
    market_cap_inr: float | None = None,
) -> bool:
    """Point-in-time quality check at bar index [bar_i] (inclusive history)."""
    if params.use_market_cap and params.min_market_cap_crore > 0:
        min_inr = crore_to_inr(params.min_market_cap_crore)
        if market_cap_inr is None or market_cap_inr < min_inr:
            return False

    min_len = max(
        params.volume_lookback + 1 if params.volume_multiplier > 0 else 0,
        params.ema20_period if params.require_above_ema20 else 0,
        params.ema50_period if params.require_above_ema50 else 0,
    )
    if bar_i + 1 < min_len:
        return False

    close = float(c[bar_i])
    volume = float(v[bar_i])
    if not np.isfinite(close) or not np.isfinite(volume):
        return False

    if params.volume_multiplier > 0:
        lb = params.volume_lookback
        prior = v[bar_i - lb : bar_i]
        if len(prior) < lb:
            return False
        avg_vol = float(np.nanmean(prior))
        if avg_vol <= 0 or volume < params.volume_multiplier * avg_vol:
            return False

    hist = c[: bar_i + 1]

    if params.require_above_ema20:
        e20 = ema(hist, params.ema20_period)
        e20_last = e20[bar_i]
        if not np.isfinite(e20_last) or close <= e20_last:
            return False

    if params.require_above_ema50:
        e50 = ema(hist, params.ema50_period)
        e50_last = e50[bar_i]
        if not np.isfinite(e50_last) or close <= e50_last:
            return False

    return True


def _fetch_one_market_cap(symbol: str) -> tuple[str, float | None]:
    try:
        t = yf.Ticker(symbol)
        cap = t.fast_info.get("market_cap")
        if cap is None:
            cap = t.info.get("marketCap")
        if cap is not None and cap > 0:
            return symbol, float(cap)
    except Exception:
        pass
    return symbol, None


def fetch_market_caps(symbols: list[str], workers: int = 16) -> dict[str, float]:
    caps: dict[str, float] = {}
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(_fetch_one_market_cap, s): s for s in symbols}
        for fut in as_completed(futures):
            sym, cap = fut.result()
            if cap is not None:
                caps[sym] = cap
    return caps
