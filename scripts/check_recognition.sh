#!/bin/bash
set -euo pipefail
# Required local recognition gate. Never opens an app, Simulator, or device UI.
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
bash "$repo_root/scripts/test_surface_core.sh"
if [ "$#" -gt 0 ]; then
    python3 "$repo_root/scripts/check_pickup_recognition.py" --output "$1"
else
    python3 "$repo_root/scripts/check_pickup_recognition.py"
fi
