"""The only place that names a model."""
import os

MODEL = os.environ.get("SUPPORT_MODEL", "gpt-4o-mini")
FALLBACK_MODEL = "gpt-4o"
MAX_STEPS = 8
