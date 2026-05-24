#!/bin/bash

# Locate arduino-cli
CLI_PATH="/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli"

if [ ! -f "$CLI_PATH" ]; then
    if command -v arduino-cli &> /dev/null; then
        CLI_PATH="arduino-cli"
    else
        echo "Error: arduino-cli not found."
        exit 1
    fi
fi

# Detect port
PORT=$( "$CLI_PATH" board list | grep -E "/dev/cu\.(usbmodem|usbserial|wchusbserial)" | awk '{print $1}' | head -n 1 || true )

if [ -z "$PORT" ]; then
    # Fallback to check raw files if not auto-detected
    PORT=$(ls -1 /dev/cu.usbserial* /dev/cu.usbmodem* /dev/cu.wchusbserial* 2>/dev/null | head -n 1 || true)
fi

if [ -z "$PORT" ]; then
    echo "No Arduino board detected. Please plug in the USB cable!"
    exit 1
fi

echo "Connecting to Serial Monitor on port: $PORT (9600 baud)..."
echo "Press Ctrl+C to exit."
echo "--------------------------------------------------"

"$CLI_PATH" monitor -p "$PORT" -c baudrate=9600
