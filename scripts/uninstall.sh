#!/bin/bash

set -euo pipefail

APP_NAME="MacNull.app"
INSTALL_DIR="/Applications"

cyan() { printf "\033[36m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m\n" "$1"; }
red() { printf "\033[31m%s\033[0m\n" "$1"; }

if [ -z "${HOME:-}" ]; then
  red "HOME is not set; aborting to avoid removing unintended paths."
  exit 1
fi

SUPPORT_PATHS=(
  "$HOME/Library/Application Support/MacClean"
  "$HOME/Library/Caches/com.macclean.app"
  "$HOME/Library/HTTPStorages/com.macclean.app"
  "$HOME/Library/Logs/MacClean"
  "$HOME/Library/Preferences/com.macclean.app.plist"
  "$HOME/Library/Preferences/com.macclean.shared.plist"
  "$HOME/Library/Saved Application State/com.macclean.app.savedState"
)

cyan "Quitting MacNull if it is running..."
osascript -e 'tell application "MacNull" to quit' >/dev/null 2>&1 || true
pkill -f "MacCleanMenu" >/dev/null 2>&1 || true

if command -v brew >/dev/null 2>&1 && brew list --cask mac-sai >/dev/null 2>&1; then
  cyan "Removing the Homebrew cask (with --zap to clear support files)..."
  brew uninstall --zap --cask mac-sai
  green "✓ MacNull and its support files were removed via Homebrew."
  exit 0
fi

cyan "Removing $INSTALL_DIR/$APP_NAME..."
rm -rf "$INSTALL_DIR/$APP_NAME"

cyan "Removing support files..."
for path in "${SUPPORT_PATHS[@]}"; do
  if [ -e "$path" ]; then
    rm -rf "$path"
    echo "  removed $path"
  fi
done

defaults delete com.macclean.app >/dev/null 2>&1 || true
defaults delete com.macclean.shared >/dev/null 2>&1 || true

green ""
green "✓ MacNull has been uninstalled."
echo ""
echo "If MacNull still appears under System Settings → General → Login Items,"
echo "remove the leftover entry there; macOS clears it once the app is gone."
