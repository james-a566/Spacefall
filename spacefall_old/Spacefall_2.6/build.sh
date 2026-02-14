#!/bin/sh
set -eu

ROM_NAME="${ROM_NAME:-game}"
CFG_FILE="nes.cfg"
OUTDIR="build"
ENTRY="${ENTRY:-src/main.s}"

echo "=== Clean build ==="
mkdir -p "$OUTDIR"
rm -f "$OUTDIR"/*.o "$OUTDIR"/*.nes

echo "=== Checking inputs ==="
[ -f "$CFG_FILE" ] || { echo "ERROR: missing $CFG_FILE"; exit 1; }
[ -f "$ENTRY" ] || { echo "ERROR: missing ENTRY file: $ENTRY"; exit 1; }

echo "=== Assembling ==="
ca65 -I . "$ENTRY" -o "$OUTDIR/main.o"

echo "=== Linking ==="
ld65 -C "$CFG_FILE" "$OUTDIR/main.o" -o "$OUTDIR/$ROM_NAME.nes"

echo "=== Success ==="
ls -lh "$OUTDIR/$ROM_NAME.nes"
