#!/bin/bash
# Construit l'app en Release et l'empaquette dans un DMG classique
# (app + raccourci Applications). Usage : ./make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Private Mailtemp"
ARCHIVE="build/PrivateMailtemp.xcarchive"
STAGING="build/dmg-staging"
DMG="build/Private-Mailtemp.dmg"

echo "── Archive Release…"
# file-prefix-map : sans lui, les assertions C des dépendances (__FILE__)
# embarquent des chemins absolus $HOME/... dans le binaire distribué.
xcodebuild -project private_Tempmail.xcodeproj \
           -scheme private_Tempmail \
           -configuration Release \
           archive -archivePath "$ARCHIVE" \
           OTHER_CFLAGS="\$(inherited) -ffile-prefix-map=$HOME=/redacted" \
           OTHER_SWIFT_FLAGS="\$(inherited) -file-prefix-map $HOME=/redacted" | tail -2

echo "── Préparation du volume…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$ARCHIVE/Products/Applications/$APP_NAME.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "── Création du DMG…"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "✓ DMG prêt : $(pwd)/$DMG"
