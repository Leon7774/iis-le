#!/bin/bash
# Script to run the Pico Motor Control Flutter app on macOS desktop.

# Resolve the absolute path of this script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Starting Pico Motor Control App on macOS desktop..."
cd "$SCRIPT_DIR/pico_control_app"

# Execute flutter run targeting macOS
flutter run -d macos
