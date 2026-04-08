#!/bin/bash
# Build Pucks and install to /Applications/Pucks.app
#
# Permissions persist across rebuilds because:
#   1. The bundle ID (com.pucksapp.pucks) stays the same
#   2. The code signing identity stays the same
#   3. Sandbox is disabled (com.apple.security.app-sandbox = false)
#   4. We sign with --identifier to embed the bundle ID in the signature
#   5. No hardened runtime for dev builds (avoids TCC reset)
#
# If permissions are lost, run:
#   tccutil reset All com.pucksapp.pucks
# then re-grant them once. They will persist from that point.

set -e

SIGNING_IDENTITY="Apple Development: Jason Kneen (E9G8K4TUEW)"
BUNDLE_ID="com.pucksapp.pucks"
APP_PATH="/Applications/Pucks.app"
APP_DIR="$APP_PATH/Contents"
MACOS_DIR="$APP_DIR/MacOS"
RES_DIR="$APP_DIR/Resources"

echo "━━━ Building Pucks ━━━"
cd "$(dirname "$0")"
swift build 2>&1 | tail -5

# Kill existing instance gracefully, then force if needed
if pgrep -f "Pucks.app/Contents/MacOS/Pucks" >/dev/null 2>&1; then
    echo "Stopping existing Pucks instance..."
    pkill -f "Pucks.app/Contents/MacOS/Pucks" 2>/dev/null || true
    sleep 0.5
fi

# Create app bundle structure
mkdir -p "$MACOS_DIR" "$RES_DIR"

# Copy binary
cp .build/debug/Pucks "$MACOS_DIR/Pucks"

# Copy Info.plist
cp Pucks/Info.plist "$APP_DIR/Info.plist"

# Copy entitlements for signing
cp Pucks/Pucks.entitlements /tmp/Pucks.entitlements

# Copy resources (icon, sounds, etc)
cp Pucks/Resources/* "$RES_DIR/" 2>/dev/null || true

# Codesign with stable identity + explicit bundle identifier.
# --identifier ensures TCC database key stays consistent.
# NO --options runtime (hardened runtime) for dev builds — this is
# critical for TCC permissions persisting across rebuilds.
echo "Signing with identity: $SIGNING_IDENTITY"
codesign --force --deep \
    --sign "$SIGNING_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    --entitlements /tmp/Pucks.entitlements \
    "$APP_PATH"

# Verify the signature
if codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    echo "✓ Signature verified: $APP_PATH"
else
    echo "⚠ Signature verification failed — permissions may not persist"
fi

echo "━━━ Installed to $APP_PATH ━━━"
echo "Launching..."
open "$APP_PATH"
