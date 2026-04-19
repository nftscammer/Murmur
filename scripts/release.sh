#!/bin/bash
# Usage: ./scripts/release.sh 1.1 "Fixed hotkey bug; improved accuracy"
# Requires: Sparkle bin tools, a GitHub Pages site for hosting

set -e

VERSION="${1:?Usage: release.sh <version> '<notes>'}"
NOTES="${2:?Provide release notes}"
SPARKLE_BIN="/Users/kyandelegat/Downloads/Sparkle-for-Swift-Package-Manager/bin"
PRIVATE_KEY_FILE="$HOME/Developer/murmur-keys/private_key.txt"
RELEASES_DIR="$HOME/Developer/murmur-releases"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$RELEASES_DIR"

echo "→ Building Murmur $VERSION..."
# Bump version in project.yml
sed -i '' "s/CFBundleShortVersionString: .*/CFBundleShortVersionString: \"$VERSION\"/" "$PROJECT_DIR/project.yml"
# Increment build number
BUILD=$(date +%s)
sed -i '' "s/CFBundleVersion: .*/CFBundleVersion: \"$BUILD\"/" "$PROJECT_DIR/project.yml"

xcodegen generate --quiet
xcodebuild -project "$PROJECT_DIR/Murmur.xcodeproj" \
           -scheme Murmur \
           -configuration Release \
           -archivePath /tmp/Murmur.xcarchive \
           archive 2>&1 | grep -E "error:|BUILD"

APP_PATH="/tmp/Murmur.xcarchive/Products/Applications/Murmur.app"
DMG_PATH="$RELEASES_DIR/Murmur-$VERSION.dmg"

echo "→ Creating DMG..."
hdiutil create -volname "Murmur $VERSION" \
               -srcfolder "$APP_PATH" \
               -ov -format UDZO \
               "$DMG_PATH"

echo "→ Signing update..."
PRIVATE_KEY=$(cat "$PRIVATE_KEY_FILE")
SIG_OUTPUT=$("$SPARKLE_BIN/sign_update" --ed-key-file <(echo "$PRIVATE_KEY") "$DMG_PATH" 2>&1)
echo "$SIG_OUTPUT"

FILE_SIZE=$(wc -c < "$DMG_PATH" | tr -d ' ')
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Done! DMG: $DMG_PATH"
echo "  File size: $FILE_SIZE bytes"
echo ""
echo "Next steps:"
echo "  1. Upload $DMG_PATH to your GitHub release"
echo "  2. Update appcast.xml with the signature, size, and URL above"
echo "  3. Push appcast.xml to your GitHub Pages branch"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
