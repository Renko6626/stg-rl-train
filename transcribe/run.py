#!/usr/bin/env python3
"""Run from the locked project environment: uv run --frozen python transcribe/run.py."""
from stgtranscribe.runner import main

if __name__ == "__main__":
    raise SystemExit(main())
