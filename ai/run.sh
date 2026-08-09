#!/bin/bash
# DerivedData benchmark launcher only — not for interactive Debug/QA.
# For interactive use and permission-sensitive testing, run scripts/run_debug.sh
# (canonical /Applications/AlTab Dev.app). See docs/building-and-troubleshooting.md.

"DerivedData/Build/Products/Debug/AlTab Dev.app/Contents/MacOS/AlTab Dev" --logs=debug --benchmark showUi 3
