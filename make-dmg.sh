#!/bin/bash
# Construit l'app en Release et l'empaquette dans un DMG classique
# (app + raccourci Applications). Usage : ./make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Private Mailtemp"
ARCHIVE="build/PrivateMailtemp.xcarchive"
STAGING="build/dmg-staging"
# Nom de fichier figé : les liens « releases/latest/download » du README en
# dépendent. La version voyage dans le nom du volume et dans l'app elle-même.
DMG="build/Private-Mailtemp.dmg"

VERSION=$(xcodebuild -project private_Tempmail.xcodeproj \
                     -scheme private_Tempmail \
                     -configuration Release \
                     -showBuildSettings 2>/dev/null \
          | awk -F' = ' '/ MARKETING_VERSION /{print $2; exit}')
echo "── Version $VERSION"

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
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "✓ DMG prêt : $(pwd)/$DMG ($APP_NAME $VERSION)"
