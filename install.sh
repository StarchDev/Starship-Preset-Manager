#!/usr/bin/env sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RESET='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="starship-mgr"
RAW_URL="https://raw.githubusercontent.com/StarchDEV/starship-preset-manager/main/starship-preset-mgr.sh"

printf "${BLUE}--> Installing Starship Preset Manager...${RESET}\n"

mkdir -p "$INSTALL_DIR"

if [ -f "./starship-preset-mgr.sh" ]; then
    printf "${BLUE}--> Copying local script to %s/${SCRIPT_NAME}...${RESET}\n" "$INSTALL_DIR"
    cp "./starship-preset-mgr.sh" "$INSTALL_DIR/$SCRIPT_NAME"
else
    printf "${BLUE}--> Downloading script from GitHub...${RESET}\n"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$RAW_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$INSTALL_DIR/$SCRIPT_NAME" "$RAW_URL"
    else
        printf "${RED}❌ Error: Neither 'curl' nor 'wget' is installed.${RESET}\n"
        exit 1
    fi
fi

chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

printf "${GREEN}✔ Installed successfully to %s/%s${RESET}\n\n" "$INSTALL_DIR" "$SCRIPT_NAME"

case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
        printf "${YELLOW}⚠️  Note: %s is not currently in your PATH.${RESET}\n" "$INSTALL_DIR"
        printf "Add it to your shell configuration file (~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish):\n\n"
        printf "  ${BLUE}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}\n\n"
        ;;
esac

printf "${GREEN}Launch the manager anytime by running:${RESET} %s\n" "$SCRIPT_NAME"
