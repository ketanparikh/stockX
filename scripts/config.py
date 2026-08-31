# ── Supabase credentials ──────────────────────────────────────────────────────
# 1. Go to https://supabase.com → sign in → your project
# 2. Settings (gear icon) → API
# 3. Copy "Project URL" and "anon / public" key below
# GitHub Actions may override these via SUPABASE_URL / SUPABASE_ANON_KEY secrets.

import os

SUPABASE_URL = os.environ.get("SUPABASE_URL") or "https://cwwrjhjzrgrhkcgvxbof.supabase.co"
SUPABASE_ANON_KEY = (
    os.environ.get("SUPABASE_ANON_KEY") or "sb_publishable_qSkk1HaV4vOantlzM79wmQ_g_U6y5hi"
)

# ── Fetch settings ────────────────────────────────────────────────────────────
# How far back to pull candles for each timeframe.
FETCH_RANGE = {
    "1d":  "2y",   # ~500 daily bars (Sethi / 200 DMA needs 201+)
    "1wk": "2y",   # ~104 weekly bars
    "1mo": "5y",   # ~60  monthly bars
}

# Number of symbols fetched concurrently per batch.
# Lower if Yahoo Finance starts rate-limiting (HTTP 429).
BATCH_SIZE = 25

# Seconds to wait between batches.
BATCH_DELAY = 1.5

# Minimum candle bars needed before a row is written to Supabase.
# Sethi indicator needs 201+ daily bars for 200 DMA.
MIN_BARS = 201
