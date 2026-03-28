#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$SCRIPT_DIR/Mbanimator.app"

if [ ! -d "$APP" ]; then
    osascript -e 'display alert "Mbanimator.app nicht gefunden" message "Stelle sicher, dass Mbanimator.app im selben Ordner wie dieses Skript liegt."'
    exit 1
fi

xattr -cr "$APP"
open "$APP"
