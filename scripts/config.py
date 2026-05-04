# ── Supabase credentials ──────────────────────────────────────────────────────
# 1. Go to https://supabase.com → sign in → your project
# 2. Settings (gear icon) → API
# 3. Copy "Project URL" and "anon / public" key below

SUPABASE_URL = "https://cwwrjhjzrgrhkcgvxbof.supabase.co"
SUPABASE_ANON_KEY = "sb_publishable_qSkk1HaV4vOantlzM79wmQ_g_U6y5hi"

# ── Fetch settings ────────────────────────────────────────────────────────────
# How far back to pull candles for each timeframe.
FETCH_RANGE = {
    "1d":  "1y",   # ~252 daily bars
    "1wk": "2y",   # ~104 weekly bars
    "1mo": "5y",   # ~60  monthly bars
}

# Number of symbols fetched concurrently per batch.
# Lower if Yahoo Finance starts rate-limiting (HTTP 429).
BATCH_SIZE = 25

# Seconds to wait between batches.
BATCH_DELAY = 1.5

# Minimum candle bars needed before a row is written to Supabase.
MIN_BARS = 50
