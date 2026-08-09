#!/bin/bash
# DerivedData Instruments/profile launcher only — not for interactive Debug/QA.
# For interactive use and permission-sensitive testing, run scripts/run_debug.sh
# (canonical /Applications/AlTab Dev.app). See docs/building-and-troubleshooting.md.

profileFile="/tmp/profile_$(date +%Y%m%d_%H%M%S)"

xcrun xctrace record \
  --instrument 'Time Profiler' \
  --time-limit 20s \
  --no-prompt --quiet \
  --output "$profileFile".trace \
  --launch -- \
    "DerivedData/Build/Products/Debug/AlTab Dev.app" --benchmark showUi 3

xcrun xctrace export \
  --input "$profileFile".trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' \
  --output "$profileFile".xml
