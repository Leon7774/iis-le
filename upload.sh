#!/bin/bash

# Exit on error
set -e

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}       Arduino Upload Assistant        ${NC}"
echo -e "${BLUE}=======================================${NC}"

# 1. Locate arduino-cli
CLI_PATH="/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli"

if [ -f "$CLI_PATH" ]; then
    echo -e "${GREEN}✓ Found bundled arduino-cli in Arduino IDE.app${NC}"
else
    if command -v arduino-cli &> /dev/null; then
        CLI_PATH="arduino-cli"
        echo -e "${GREEN}✓ Found global arduino-cli in PATH${NC}"
    else
        echo -e "${RED}✗ Error: arduino-cli not found.${NC}"
        echo -e "Please ensure that the Arduino IDE is installed in /Applications/Arduino IDE.app"
        echo -e "or install arduino-cli globally (e.g., via 'brew install arduino-cli')."
        exit 1
    fi
fi

# 2. Identify sketch file and folder
if [ -n "$1" ]; then
    SKETCH_FILE="$1"
    if [[ ! "$SKETCH_FILE" == *.ino ]]; then
        if [ -f "${SKETCH_FILE}.ino" ]; then
            SKETCH_FILE="${SKETCH_FILE}.ino"
        fi
    fi
    
    if [ ! -f "$SKETCH_FILE" ]; then
        echo -e "${RED}✗ Error: File '$SKETCH_FILE' not found.${NC}"
        exit 1
    fi
else
    # Find all .ino files in the current directory
    INO_FILES=$(find . -maxdepth 1 -name "*.ino" | sed 's|^\./||' || true)
    INO_COUNT=$(echo "$INO_FILES" | grep -c "\.ino$" || true)
    
    if [ "$INO_COUNT" -eq 1 ] && [ -n "$INO_FILES" ]; then
        SKETCH_FILE="$INO_FILES"
        echo -e "${GREEN}✓ Found single sketch file: $SKETCH_FILE${NC}"
    elif [ "$INO_COUNT" -gt 1 ]; then
        echo -e "${YELLOW}Multiple sketch files found. Please select one:${NC}"
        select FILE in $INO_FILES; do
            if [ -n "$FILE" ]; then
                SKETCH_FILE="$FILE"
                break
            else
                echo "Invalid selection."
            fi
        done
    else
        # No .ino files in root. Check if there are any in subdirectories that are valid sketches.
        SUBOUT=$(find * -maxdepth 2 -name "*.ino" 2>/dev/null | grep -E "^([^/]+)/\1\.ino$" || true)
        SUB_COUNT=$(echo "$SUBOUT" | grep -c "\.ino$" || true)
        if [ "$SUB_COUNT" -eq 1 ] && [ -n "$SUBOUT" ]; then
            SKETCH_FILE="$SUBOUT"
            echo -e "${GREEN}✓ Found sketch in subdirectory: $SKETCH_FILE${NC}"
        elif [ "$SUB_COUNT" -gt 1 ]; then
            echo -e "${YELLOW}Multiple sketches found in subdirectories. Please select one:${NC}"
            select FILE in $SUBOUT; do
                if [ -n "$FILE" ]; then
                    SKETCH_FILE="$FILE"
                    break
                else
                    echo "Invalid selection."
                fi
            done
        else
            echo -e "${RED}✗ Error: No .ino sketch files found in the current directory.${NC}"
            echo -e "Usage: ./upload.sh [sketch_name.ino]"
            exit 1
        fi
    fi
fi

# Extract base name without path and suffix
BASE_NAME=$(basename "$SKETCH_FILE" .ino)
PARENT_DIR=$(dirname "$SKETCH_FILE")

if [ "$PARENT_DIR" = "." ]; then
    # It's at the root. We must ensure it's in a subdirectory of the same name.
    SKETCH_DIR="$BASE_NAME"
    if [ ! -d "$SKETCH_DIR" ]; then
        echo -e "${YELLOW}Creating sketch folder '${SKETCH_DIR}'...${NC}"
        mkdir -p "$SKETCH_DIR"
    fi
    cp "$SKETCH_FILE" "$SKETCH_DIR/${BASE_NAME}.ino"
    SKETCH_PATH="$SKETCH_DIR"
else
    # It's already in a subdirectory
    if [ "$(basename "$PARENT_DIR")" = "$BASE_NAME" ]; then
        # Check if they are in sync if the root file exists
        if [ -f "${BASE_NAME}.ino" ] && [ "$PARENT_DIR" = "$BASE_NAME" ]; then
            cp "${BASE_NAME}.ino" "$PARENT_DIR/${BASE_NAME}.ino"
        fi
        SKETCH_PATH="$PARENT_DIR"
    else
        SKETCH_DIR="$BASE_NAME"
        if [ ! -d "$SKETCH_DIR" ]; then
            echo -e "${YELLOW}Creating sketch folder '${SKETCH_DIR}'...${NC}"
            mkdir -p "$SKETCH_DIR"
        fi
        cp "$SKETCH_FILE" "$SKETCH_DIR/${BASE_NAME}.ino"
        SKETCH_PATH="$SKETCH_DIR"
    fi
fi

# 3. Detect ports
echo -e "\n${BLUE}Searching for connected Arduino boards...${NC}"
PORTS=$("$CLI_PATH" board list | grep -E "/dev/cu\.(usbmodem|usbserial|wchusbserial)" || true)

if [ -z "$PORTS" ]; then
    echo -e "${YELLOW}No active USB serial ports automatically identified as Arduino boards.${NC}"
    echo -e "Listing all available serial ports:"
    ALL_PORTS=$(ls -1 /dev/cu.usbserial* /dev/cu.usbmodem* /dev/cu.wchusbserial* 2>/dev/null || true)
    
    if [ -z "$ALL_PORTS" ]; then
        echo -e "${RED}✗ No USB serial devices detected. Please check if your board is plugged in!${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Available ports:${NC}"
    select PORT in $ALL_PORTS; do
        if [ -n "$PORT" ]; then
            break
        else
            echo "Invalid selection."
        fi
    done
else
    echo -e "${GREEN}Detected ports:${NC}"
    echo "$PORTS"
    # Extract the port from the first column
    PORT=$(echo "$PORTS" | awk '{print $1}' | head -n 1)
    echo -e "Auto-selected port: ${GREEN}$PORT${NC}"
fi

# 4. Set FQBN (Default to Arduino Nano)
FQBN="arduino:avr:nano:cpu=atmega328"
ALT_FQBN="arduino:avr:nano:cpu=atmega328old"

echo -e "Selected Board: ${GREEN}Arduino Nano${NC}"

# 5. Compile and Upload
echo -e "\n${BLUE}Compiling the sketch...${NC}"
if ! "$CLI_PATH" compile --fqbn "$FQBN" "$SKETCH_PATH"; then
    echo -e "${RED}✗ Compilation failed.${NC}"
    exit 1
fi

echo -e "\n${BLUE}Uploading the sketch to $PORT...${NC}"
if ! "$CLI_PATH" upload -p "$PORT" --fqbn "$FQBN" "$SKETCH_PATH"; then
    echo -e "${YELLOW}⚠️ Upload failed with New Bootloader. Retrying with Old Bootloader...${NC}"
    
    # Re-compile and upload using the alternative FQBN
    if "$CLI_PATH" compile --fqbn "$ALT_FQBN" "$SKETCH_PATH" && \
       "$CLI_PATH" upload -p "$PORT" --fqbn "$ALT_FQBN" "$SKETCH_PATH"; then
        echo -e "\n${GREEN}✓ Upload complete using Arduino Nano (Old Bootloader)!${NC}"
    else
        echo -e "${RED}✗ Upload failed for both Nano bootloaders. Please check your connections!${NC}"
        exit 1
    fi
else
    echo -e "\n${GREEN}✓ Upload complete!${NC}"
fi
