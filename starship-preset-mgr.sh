#!/usr/bin/env sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
REVERSE='\033[7m'
RESET='\033[0m'

STARSHIP_CONFIG="$HOME/.config/starship.toml"
BACKUP_DIR="$HOME/.config/starship/backups"
CUSTOM_PRESETS_DIR="$HOME/.config/starship/presets"

mkdir -p "$BACKUP_DIR" "$CUSTOM_PRESETS_DIR"

get_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

install_curl() {
    printf "${YELLOW}--> 'curl' is missing. Detecting distribution to install core utilities...${RESET}\n"
    DISTRO=$(get_distro)

    case "$DISTRO" in
        arch|manjaro|endeavouros)
            sudo pacman -S --noconfirm curl unzip
            ;;
        fedora|rhel|centos)
            sudo dnf install -y curl unzip
            ;;
        ubuntu|debian|pop|mint)
            sudo apt-get update && sudo apt-get install -y curl unzip
            ;;
        alpine)
            sudo apk add curl unzip
            ;;
        void)
            sudo xbps-install -Sy curl unzip
            ;;
        *)
            printf "${RED}❌ Unknown distribution ($DISTRO). Please install 'curl' manually and re-run.${RESET}\n"
            exit 1
            ;;
    esac
}

detect_distro_and_install_starship() {
    printf "${YELLOW}--> Starship CLI not found. Installing...${RESET}\n"
    DISTRO=$(get_distro)

    case "$DISTRO" in
        arch|manjaro|endeavouros)
            sudo pacman -S --noconfirm starship
            ;;
        fedora|rhel|centos)
            sudo dnf copr enable -y atim/starship
            sudo dnf install -y starship
            ;;
        ubuntu|debian|pop|mint)
            curl -sS https://starship.rs/install.sh | sh -s -- -y
            ;;
        alpine)
            sudo apk add starship
            ;;
        void)
            sudo xbps-install -Sy starship
            ;;
        *)
            printf "${YELLOW}--> Unknown distribution ($DISTRO). Falling back to official installer...${RESET}\n"
            curl -sS https://starship.rs/install.sh | sh -s -- -y
            ;;
    esac
}

install_nerd_font() {
    printf "${YELLOW}--> No Nerd Font detected in font cache. Installing JetBrainsMono Nerd Font...${RESET}\n"
    
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    
    TEMP_DIR=$(mktemp -d)
    curl -fLo "$TEMP_DIR/JetBrainsMono.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    
    unzip -o "$TEMP_DIR/JetBrainsMono.zip" -d "$FONT_DIR/" >/dev/null 2>&1
    rm -rf "$TEMP_DIR"
    
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -fv "$FONT_DIR" >/dev/null 2>&1
    fi
    printf "${GREEN}✔ JetBrainsMono Nerd Font installed successfully!${RESET}\n"
}

check_dependencies() {
    if ! command -v curl >/dev/null 2>&1; then
        install_curl
    fi

    if ! command -v starship >/dev/null 2>&1; then
        detect_distro_and_install_starship
    fi

    if command -v fc-list >/dev/null 2>&1; then
        if ! fc-list | grep -i "nerd" >/dev/null 2>&1; then
            install_nerd_font
        fi
    fi
}

backup_current_config() {
    if [ -f "$STARSHIP_CONFIG" ]; then
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        cp "$STARSHIP_CONFIG" "$BACKUP_DIR/starship.toml.bak_$TIMESTAMP"
        printf "${BLUE}--> Backed up current config to $BACKUP_DIR/starship.toml.bak_$TIMESTAMP${RESET}\n"
    fi
}

validate_toml_file() {
    file_to_check="$1"
    
    if head -n 10 "$file_to_check" | grep -qi '<!DOCTYPE html\|<html'; then
        return 1
    fi

    test_output=$(STARSHIP_CONFIG="$file_to_check" starship prompt 2>&1)
    if echo "$test_output" | grep -qi "Unable to parse the config file\|TOML parse error"; then
        return 1
    fi
    return 0
}

apply_builtin_preset() {
    PRESET_NAME="$1"
    TEMP_CONFIG=$(mktemp)

    if starship preset "$PRESET_NAME" -o "$TEMP_CONFIG" -f >/dev/null 2>&1; then
        if validate_toml_file "$TEMP_CONFIG"; then
            backup_current_config
            mv "$TEMP_CONFIG" "$STARSHIP_CONFIG"
            printf "${GREEN}✔ Applied built-in preset: ${BOLD}%s${RESET}\n" "$PRESET_NAME"
        else
            printf "${RED}❌ Built-in preset '${PRESET_NAME}' generated invalid TOML. Aborted.${RESET}\n"
            rm -f "$TEMP_CONFIG"
        fi
    else
        printf "${RED}❌ Failed to generate built-in preset '${PRESET_NAME}'.${RESET}\n"
        rm -f "$TEMP_CONFIG"
    fi
}

apply_custom_preset() {
    FILE_PATH="$1"
    PRESET_NAME="$2"

    if validate_toml_file "$FILE_PATH"; then
        backup_current_config
        cp "$FILE_PATH" "$STARSHIP_CONFIG"
        printf "${GREEN}✔ Applied custom preset: ${BOLD}%s${RESET}\n" "$PRESET_NAME"
    else
        printf "${RED}❌ Selected file '${FILE_PATH}' contains invalid TOML syntax or HTML markup!${RESET}\n"
        printf "${YELLOW}Config was NOT updated.${RESET}\n"
    fi
}

read_key() {
    old_stty=$(stty -g)
    stty raw -echo
    char=$(dd bs=1 count=1 2>/dev/null)
    if [ "$char" = "$(printf '\033')" ]; then
        read -r -t 1 -n 2 rest
        char="$char$rest"
    fi
    stty "$old_stty"
    case "$char" in
        "$(printf '\033[A')"|"k") echo "UP" ;;
        "$(printf '\033[B')"|"j") echo "DOWN" ;;
        ""|"$(printf '\r')"|"$(printf '\n')") echo "ENTER" ;;
        *) echo "OTHER" ;;
    esac
}

draw_menu_list() {
    title="$1"
    selected="$2"
    shift 2

    clear
    printf "${CYAN}==========================================${RESET}\n"
    printf "          ${MAGENTA}${BOLD}%s${RESET}\n" "$title"
    printf "${CYAN}==========================================${RESET}\n"

    i=1
    for item in "$@"; do
        if [ "$i" -eq "$selected" ]; then
            printf "  ${CYAN}${REVERSE} > %s ${RESET}\n" "$item"
        else
            printf "    %s\n" "$item"
        fi
        i=$((i + 1))
    done
    printf "${CYAN}==========================================${RESET}\n"
    printf "${YELLOW}(Use Up/Down Arrow keys or j/k to move, Enter to select)${RESET}\n"
}

select_and_apply_builtin() {
    BUILTIN_LIST=$(starship preset --list-presets 2>/dev/null)
    
    if [ -z "$BUILTIN_LIST" ]; then
        BUILTIN_LIST="bracketed-segments
catppuccin-powerline
gruvbox-rainbow
jetpack
nerd-font-symbols
no-empty-icons
no-nerd-font
no-runtime-versions
pastel-powerline
plain-text-symbols
pure-preset
tokyo-night"
    fi

    set -- $BUILTIN_LIST "Back to Main Menu"
    sub_total=$#
    sub_current=1

    while true; do
        draw_menu_list "BUILT-IN PRESETS" "$sub_current" "$@"
        key=$(read_key)

        case "$key" in
            UP)
                sub_current=$((sub_current - 1))
                [ "$sub_current" -lt 1 ] && sub_current=$sub_total
                ;;
            DOWN)
                sub_current=$((sub_current + 1))
                [ "$sub_current" -gt "$sub_total" ] && sub_current=1
                ;;
            ENTER)
                if [ "$sub_current" -eq "$sub_total" ]; then
                    return
                fi
                eval "SELECTED_PRESET=\${$sub_current}"
                apply_builtin_preset "$SELECTED_PRESET"
                printf "\nPress Enter to continue..."
                read -r _
                return
                ;;
        esac
    done
}

select_and_apply_custom() {
    set --
    for file in "$CUSTOM_PRESETS_DIR"/*.toml; do
        if [ -f "$file" ]; then
            fname=$(basename "$file" .toml)
            set -- "$@" "$fname"
        fi
    done

    if [ $# -eq 0 ]; then
        clear
        printf "${RED}No custom .toml presets found in:${RESET}\n"
        printf "  %s\n\n" "$CUSTOM_PRESETS_DIR"
        printf "Place your custom preset files (.toml) there to select them!\n"
        printf "Press Enter to return..."
        read -r _
        return
    fi

    set -- "$@" "Back to Main Menu"
    sub_total=$#
    sub_current=1

    while true; do
        draw_menu_list "USER CUSTOM PRESETS" "$sub_current" "$@"
        key=$(read_key)

        case "$key" in
            UP)
                sub_current=$((sub_current - 1))
                [ "$sub_current" -lt 1 ] && sub_current=$sub_total
                ;;
            DOWN)
                sub_current=$((sub_current + 1))
                [ "$sub_current" -gt "$sub_total" ] && sub_current=1
                ;;
            ENTER)
                if [ "$sub_current" -eq "$sub_total" ]; then
                    return
                fi
                eval "SELECTED_NAME=\${$sub_current}"
                SELECTED_FILE="$CUSTOM_PRESETS_DIR/$SELECTED_NAME.toml"
                apply_custom_preset "$SELECTED_FILE" "$SELECTED_NAME"
                printf "\nPress Enter to continue..."
                read -r _
                return
                ;;
        esac
    done
}

render_live_preview() {
    config_file="$1"
    preset_name="$2"

    printf "\n${CYAN}--- Live Output Preview for '${BOLD}%s${RESET}${CYAN}' ---${RESET}\n\n" "$preset_name"
    STARSHIP_CONFIG="$config_file" starship prompt | sed -e 's/\\\[//g' -e 's/\\\]//g'
    printf "\n${CYAN}---------------------------------------------${RESET}\n\n"
}

preview_builtin_menu() {
    BUILTIN_LIST=$(starship preset --list-presets 2>/dev/null)
    if [ -z "$BUILTIN_LIST" ]; then
        BUILTIN_LIST="bracketed-segments
catppuccin-powerline
gruvbox-rainbow
jetpack
nerd-font-symbols
no-empty-icons
no-nerd-font
no-runtime-versions
pastel-powerline
plain-text-symbols
pure-preset
tokyo-night"
    fi

    set -- $BUILTIN_LIST "Back to Preview Options"
    sub_total=$#
    sub_current=1

    while true; do
        draw_menu_list "PREVIEW BUILT-IN PRESET" "$sub_current" "$@"
        key=$(read_key)

        case "$key" in
            UP)
                sub_current=$((sub_current - 1))
                [ "$sub_current" -lt 1 ] && sub_current=$sub_total
                ;;
            DOWN)
                sub_current=$((sub_current + 1))
                [ "$sub_current" -gt "$sub_total" ] && sub_current=1
                ;;
            ENTER)
                if [ "$sub_current" -eq "$sub_total" ]; then
                    return
                fi
                eval "PRESET_KEY=\${$sub_current}"
                TEMP_PRESET=$(mktemp)
                starship preset "$PRESET_KEY" > "$TEMP_PRESET" 2>/dev/null
                render_live_preview "$TEMP_PRESET" "$PRESET_KEY"
                rm -f "$TEMP_PRESET"
                
                printf "Press Enter to return..."
                read -r _
                return
                ;;
        esac
    done
}

preview_custom_menu() {
    set --
    for file in "$CUSTOM_PRESETS_DIR"/*.toml; do
        if [ -f "$file" ]; then
            fname=$(basename "$file" .toml)
            set -- "$@" "$fname"
        fi
    done

    if [ $# -eq 0 ]; then
        clear
        printf "${RED}No custom .toml presets found in:${RESET}\n"
        printf "  %s\n\n" "$CUSTOM_PRESETS_DIR"
        printf "Press Enter to return..."
        read -r _
        return
    fi

    set -- "$@" "Back to Preview Options"
    sub_total=$#
    sub_current=1

    while true; do
        draw_menu_list "PREVIEW CUSTOM PRESET" "$sub_current" "$@"
        key=$(read_key)

        case "$key" in
            UP)
                sub_current=$((sub_current - 1))
                [ "$sub_current" -lt 1 ] && sub_current=$sub_total
                ;;
            DOWN)
                sub_current=$((sub_current + 1))
                [ "$sub_current" -gt "$sub_total" ] && sub_current=1
                ;;
            ENTER)
                if [ "$sub_current" -eq "$sub_total" ]; then
                    return
                fi
                eval "SELECTED_NAME=\${$sub_current}"
                SELECTED_FILE="$CUSTOM_PRESETS_DIR/$SELECTED_NAME.toml"
                
                if validate_toml_file "$SELECTED_FILE"; then
                    render_live_preview "$SELECTED_FILE" "$SELECTED_NAME"
                else
                    printf "${RED}❌ Selected file contains invalid TOML syntax or HTML markup!${RESET}\n"
                fi
                
                printf "Press Enter to return..."
                read -r _
                return
                ;;
        esac
    done
}

preview_url_menu() {
    clear
    printf "${CYAN}==========================================${RESET}\n"
    printf "        ${MAGENTA}${BOLD}PREVIEW REMOTE URL PRESET${RESET}\n"
    printf "${CYAN}==========================================${RESET}\n"
    printf "${YELLOW}Paste URL to a raw .toml preset file:${RESET}\n"
    printf "> "
    read -r url

    if [ -z "$url" ]; then
        printf "${RED}URL cannot be empty.${RESET}\n"
        printf "Press Enter to return..."
        read -r _
        return
    fi

    case "$url" in
        *github.com/*/blob/*)
            url=$(echo "$url" | sed -e 's|github.com|raw.githubusercontent.com|' -e 's|/blob/|/|')
            printf "${BLUE}--> Converted GitHub web URL to Raw file URL...${RESET}\n"
            ;;
        *gist.github.com/*)
            case "$url" in
                */raw*) ;;
                *) url="$url/raw" ;;
            esac
            printf "${BLUE}--> Converted GitHub Gist URL to Raw URL...${RESET}\n"
            ;;
        *gitlab.com/*/blob/*)
            url=$(echo "$url" | sed 's|/blob/|/raw/|')
            printf "${BLUE}--> Converted GitLab web URL to Raw URL...${RESET}\n"
            ;;
    esac

    temp_download=$(mktemp)
    printf "${BLUE}--> Fetching remote configuration...${RESET}\n"
    if curl -fsSL -L "$url" -o "$temp_download"; then
        if validate_toml_file "$temp_download"; then
            render_live_preview "$temp_download" "Remote Preset"
        else
            printf "${RED}❌ Download failed! File contains HTML markup or invalid TOML syntax.${RESET}\n"
        fi
    else
        printf "${RED}❌ Download failed! Check the URL and network connection.${RESET}\n"
    fi
    rm -f "$temp_download"

    printf "Press Enter to return..."
    read -r _
}

preview_preset_main() {
    set -- "Built-in Presets" "Custom Saved Presets" "Remote Preset (from URL)" "Back to Main Menu"
    sub_total=$#
    sub_current=1

    while true; do
        draw_menu_list "PREVIEW PRESETS" "$sub_current" "$@"
        key=$(read_key)

        case "$key" in
            UP)
                sub_current=$((sub_current - 1))
                [ "$sub_current" -lt 1 ] && sub_current=$sub_total
                ;;
            DOWN)
                sub_current=$((sub_current + 1))
                [ "$sub_current" -gt "$sub_total" ] && sub_current=1
                ;;
            ENTER)
                case "$sub_current" in
                    1) preview_builtin_menu ;;
                    2) preview_custom_menu ;;
                    3) preview_url_menu ;;
                    4) return ;;
                esac
                ;;
        esac
    done
}

download_remote_preset() {
    clear
    printf "${CYAN}==========================================${RESET}\n"
    printf "      ${MAGENTA}${BOLD}DOWNLOAD REMOTE PRESET${RESET}\n"
    printf "${CYAN}==========================================${RESET}\n"
    printf "${YELLOW}Paste URL to a raw .toml preset file:${RESET}\n"
    printf "> "
    read -r url

    if [ -z "$url" ]; then
        printf "${RED}URL cannot be empty.${RESET}\n"
        printf "Press Enter to return..."
        read -r _
        return
    fi

    case "$url" in
        *github.com/*/blob/*)
            url=$(echo "$url" | sed -e 's|github.com|raw.githubusercontent.com|' -e 's|/blob/|/|')
            printf "${BLUE}--> Converted GitHub web URL to Raw file URL...${RESET}\n"
            ;;
        *gist.github.com/*)
            case "$url" in
                */raw*) ;;
                *) url="$url/raw" ;;
            esac
            printf "${BLUE}--> Converted GitHub Gist URL to Raw URL...${RESET}\n"
            ;;
        *gitlab.com/*/blob/*)
            url=$(echo "$url" | sed 's|/blob/|/raw/|')
            printf "${BLUE}--> Converted GitLab web URL to Raw URL...${RESET}\n"
            ;;
    esac

    preset_name=$(basename "$url" | sed -e 's/\.toml$//' -e 's/raw$//' -e 's/[^a-zA-Z0-9_-]/_/g')
    [ -z "$preset_name" ] && preset_name="custom_preset"

    printf "${BOLD}Save preset as name [default: %s]: ${RESET}" "$preset_name"
    read -r custom_name

    if [ -n "$custom_name" ]; then
        preset_name="$custom_name"
    fi

    target_file="$CUSTOM_PRESETS_DIR/$preset_name.toml"
    temp_download=$(mktemp)

    printf "${BLUE}--> Downloading %s ...${RESET}\n" "$url"
    if curl -fsSL -L "$url" -o "$temp_download"; then
        if ! validate_toml_file "$temp_download"; then
            printf "${RED}❌ Download failed! File contains HTML markup or invalid TOML syntax.${RESET}\n"
            printf "${YELLOW}Tip: Ensure the URL links directly to plain text/raw TOML code.${RESET}\n"
            rm -f "$temp_download"
        else
            render_live_preview "$temp_download" "$preset_name"
            mv "$temp_download" "$target_file"
            printf "${GREEN}✔ Successfully saved to %s${RESET}\n\n" "$target_file"
            printf "${BOLD}Do you want to apply this preset right now? [y/N]: ${RESET}"
            read -r apply_now
            case "$apply_now" in
                [yY][eE][sS]|[yY])
                    apply_custom_preset "$target_file" "$preset_name"
                    ;;
                *)
                    printf "${BLUE}Saved to custom presets list.${RESET}\n"
                    ;;
            esac
        fi
    else
        printf "${RED}❌ Download failed! Check the URL and network connection.${RESET}\n"
        rm -f "$temp_download"
    fi

    printf "\nPress Enter to return..."
    read -r _
}

delete_custom_preset() {
    set --
    for file in "$CUSTOM_PRESETS_DIR"/*.toml; do
        if [ -f "$file" ]; then
            fname=$(basename "$file" .toml)
            set -- "$@" "$fname"
        fi
    done

    if [ $# -eq 0 ]; then
        clear
        printf "${RED}No custom presets found to delete.${RESET}\n\n"
        printf "Press Enter to return..."
        read -r _
        return
    fi

    set -- "$@" "Back to Main Menu"
    sub_total=$#
    sub_current=1

    while true; do
        draw_menu_list "DELETE CUSTOM PRESET" "$sub_current" "$@"
        key=$(read_key)

        case "$key" in
            UP)
                sub_current=$((sub_current - 1))
                [ "$sub_current" -lt 1 ] && sub_current=$sub_total
                ;;
            DOWN)
                sub_current=$((sub_current + 1))
                [ "$sub_current" -gt "$sub_total" ] && sub_current=1
                ;;
            ENTER)
                if [ "$sub_current" -eq "$sub_total" ]; then
                    return
                fi
                eval "SELECTED_NAME=\${$sub_current}"
                SELECTED_FILE="$CUSTOM_PRESETS_DIR/$SELECTED_NAME.toml"
                rm -f "$SELECTED_FILE"
                printf "${GREEN}✔ Deleted custom preset: %s${RESET}\n" "$SELECTED_NAME"
                printf "\nPress Enter to continue..."
                read -r _
                return
                ;;
        esac
    done
}

delete_backups() {
    clear
    printf "${CYAN}==========================================${RESET}\n"
    printf "          ${MAGENTA}${BOLD}DELETE BACKUP FILES${RESET}\n"
    printf "${CYAN}==========================================${RESET}\n"
    
    count=$(ls -1 "$BACKUP_DIR"/starship.toml.bak_* 2>/dev/null | wc -l)
    
    if [ "$count" -eq 0 ]; then
        printf "${RED}No backup files found in $BACKUP_DIR${RESET}\n"
    else
        printf "${YELLOW}Found %d backup file(s) in $BACKUP_DIR${RESET}\n" "$count"
        printf "${BOLD}Are you sure you want to delete all backup files? [y/N]: ${RESET}"
        read -r confirm
        case "$confirm" in
            [yY][eE][sS]|[yY])
                rm -f "$BACKUP_DIR"/starship.toml.bak_*
                printf "${GREEN}✔ All backup files deleted successfully!${RESET}\n"
                ;;
            *)
                printf "${BLUE}Operation canceled.${RESET}\n"
                ;;
        esac
    fi
    printf "\nPress Enter to return..."
    read -r _
}

show_menu() {
    main_opts="Apply Built-in Starship Presets
Apply Custom User Presets
Preview Presets (Built-in, Custom, URL)
Download Remote Preset (URL)
Delete Custom User Preset
Restore Most Recent Backup
Delete All Backup Files
Exit"

    set --
    IFS='
'
    for item in $main_opts; do
        set -- "$@" "$item"
    done
    unset IFS

    total=$#
    current=1

    while true; do
        draw_menu_list "STARSHIP PRESET MANAGER" "$current" "$@"
        key=$(read_key)

        case "$key" in
            UP)
                current=$((current - 1))
                [ "$current" -lt 1 ] && current=$total
                ;;
            DOWN)
                current=$((current + 1))
                [ "$current" -gt "$total" ] && current=1
                ;;
            ENTER)
                case "$current" in
                    1) select_and_apply_builtin; current=1 ;;
                    2) select_and_apply_custom; current=1 ;;
                    3) preview_preset_main; current=1 ;;
                    4) download_remote_preset; current=1 ;;
                    5) delete_custom_preset; current=1 ;;
                    6) 
                        LATEST_BAK=$(ls -t "$BACKUP_DIR"/starship.toml.bak_* 2>/dev/null | head -n 1)
                        if [ -n "$LATEST_BAK" ]; then
                            if validate_toml_file "$LATEST_BAK"; then
                                cp "$LATEST_BAK" "$STARSHIP_CONFIG"
                                printf "${GREEN}✔ Restored from $LATEST_BAK${RESET}\n"
                            else
                                printf "${RED}❌ Backup file is corrupt or invalid!${RESET}\n"
                            fi
                        else
                            printf "${RED}❌ No backup found!${RESET}\n"
                        fi
                        printf "Press Enter to continue..."
                        read -r _
                        current=1
                        ;;
                    7) delete_backups; current=1 ;;
                    8) 
                        clear
                        exit 0 
                        ;;
                esac
                ;;
        esac
    done
}

check_dependencies
show_menu
