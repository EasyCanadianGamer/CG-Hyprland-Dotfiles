#!/usr/bin/env bash

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
CONFIG_SRC="./.config"
CONFIG_DEST="$HOME/.config"
THEMES_SRC="./themes"
THEMES_DEST="$HOME/.local/share/themes"
BACKUP_DIR="$HOME/dotfiles_backup/$(date +%Y%m%d-%H%M%S)"

# ── Colors ─────────────────────────────────────────────────────────────────────
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
RESET="\e[0m"

# ── Helpers ────────────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}  →${RESET} $*"; }
success() { echo -e "${GREEN}  ✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}  ⚠${RESET} $*"; }
error()   { echo -e "${RED}  ✗${RESET} $*"; }
header()  { echo -e "\n${BOLD}${BLUE}── $* ${RESET}"; }

confirm() {
    while true; do
        read -rp "$(echo -e "${YELLOW}  ?${RESET} $1 (y/n): ")" choice
        case "$choice" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
            *)   warn "Please enter y or n." ;;
        esac
    done
}

# Back up only the files under $dest that a copy from $src would overwrite,
# preserving their relative paths under $BACKUP_DIR/$subdir.
backup_changed_files() {
    local src="$1" dest="$2" subdir="$3"
    [ -d "$dest" ] || return 0
    local rel found=0
    while IFS= read -r -d '' rel; do
        rel="${rel#./}"
        if [ -e "$dest/$rel" ]; then
            mkdir -p "$BACKUP_DIR/$subdir/$(dirname "$rel")"
            cp -a "$dest/$rel" "$BACKUP_DIR/$subdir/$rel"
            found=1
        fi
    done < <(cd "$src" && find . -type f -print0)
    [ "$found" -eq 1 ] && info "Backed up existing $subdir files to $BACKUP_DIR/$subdir"
}

# ── Banner ─────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${BLUE}"
echo "  ┌─────────────────────────────────────────┐"
echo "  │    CG Hyprland Dotfiles Installer          │"
echo "  └─────────────────────────────────────────┘"
echo -e "${RESET}"

# ── Backup warning ─────────────────────────────────────────────────────────────
header "Backup Warning"
warn "Existing files that would be overwritten are backed up automatically to:"
info "  $BACKUP_DIR"
confirm "Continue?" || { info "Exiting."; exit 0; }

# ── Checks ─────────────────────────────────────────────────────────────────────
header "System Checks"

if ! command -v pacman &>/dev/null; then
    error "This script only supports Arch Linux (pacman not found)."
    exit 1
fi
success "Arch Linux detected."

if [ -z "${WAYLAND_DISPLAY:-}" ] && ! pgrep -x Hyprland &>/dev/null; then
    warn "Hyprland/Wayland doesn't appear to be running."
    confirm "Continue anyway?" || exit 0
else
    success "Hyprland/Wayland detected."
fi

# ── Packages ───────────────────────────────────────────────────────────────────
header "Package Installation"

PACMAN_PKGS=(awww cava kitty waybar rofi dunst hyprland wayland pavucontrol neovim ttf-jetbrains-mono-nerd ttf-font-awesome hyprpolkitagent )
AUR_PKGS=(wlogout-git termsonic )

if confirm "Install required packages?"; then
    info "Installing pacman packages..."
    sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
    success "Pacman packages installed."

    if ! command -v yay &>/dev/null; then
        info "yay not found — installing from AUR..."
        sudo pacman -S --needed --noconfirm git base-devel
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        (cd /tmp/yay && makepkg -si --noconfirm)
        success "yay installed."
    else
        success "yay already installed."
    fi

    info "Installing AUR packages: ${AUR_PKGS[*]}..."
    yay -S --needed --noconfirm "${AUR_PKGS[@]}"
    success "AUR packages installed."
else
    warn "Skipping package installation."
fi

# ── Dotfiles ───────────────────────────────────────────────────────────────────
header "Copying Configs"
warn "Existing files with the same name will be overwritten."
echo

if confirm "Copy configs to ~/.config/?"; then
    backup_changed_files "$CONFIG_SRC" "$CONFIG_DEST" "config"
    mkdir -p "$CONFIG_DEST"
    if command -v rsync &>/dev/null; then
        rsync -a --info=progress2 "$CONFIG_SRC/" "$CONFIG_DEST/"
    else
        cp -r "$CONFIG_SRC"/. "$CONFIG_DEST/"
    fi
    # Ensure scripts are executable
    find "$CONFIG_DEST/hypr/scripts" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    success "Configs installed."
else
    warn "Skipping configs."
fi

if [ -d "$THEMES_SRC" ] && confirm "Copy themes to ~/.local/share/themes/?"; then
    backup_changed_files "$THEMES_SRC" "$THEMES_DEST" "themes"
    mkdir -p "$THEMES_DEST"
    if command -v rsync &>/dev/null; then
        rsync -a --info=progress2 "$THEMES_SRC/" "$THEMES_DEST/"
    else
        cp -r "$THEMES_SRC"/. "$THEMES_DEST/"
    fi
    success "Themes installed."
elif [ ! -d "$THEMES_SRC" ]; then
    info "No themes directory found, skipping."
else
    warn "Skipping themes."
fi

# ── Default Wallpaper ──────────────────────────────────────────────────────────
header "Default Wallpaper"

DEFAULT_WALLPAPER="$THEMES_DEST/Arch/wallpaper.png"
WALLPAPER_EXEC="exec-once = awww-daemon \& sleep 1 \&\& awww img $DEFAULT_WALLPAPER --transition-type any --transition-fps 60"

if [ -f "$DEFAULT_WALLPAPER" ]; then
    info "Default wallpaper found: $DEFAULT_WALLPAPER"
    # Write a small autostart script so awww sets it on login
    WALL_SCRIPT="$CONFIG_DEST/hypr/scripts/set-wallpaper.sh"
    # Seed the cache with the default wallpaper on first install
    mkdir -p ~/.cache
    echo "$DEFAULT_WALLPAPER" > ~/.cache/current-wallpaper

    cat > "$WALL_SCRIPT" <<'EOF'
#!/usr/bin/env bash
# Restore last used wallpaper on login
CACHE=~/.cache/current-wallpaper
[ -f "$CACHE" ] && wall=$(cat "$CACHE") || wall="$HOME/.local/share/themes/Arch/wallpaper.png"
awww img "$wall" --transition-type any --transition-fps 60 --transition-duration 1
EOF
    chmod +x "$WALL_SCRIPT"
    success "Wallpaper startup script written to $WALL_SCRIPT"
    info "Hyprland uses its native Lua config (hyprland.lua), not hyprland.conf."
    info "set-wallpaper.sh is already invoked there via hl.on(\"hyprland.start\", ...) — no manual step needed."
else
    warn "No wallpaper found at $DEFAULT_WALLPAPER — skipping."
fi

# ── Done ───────────────────────────────────────────────────────────────────────
header "Post-Install Notes"
echo -e "  ${YELLOW}SDDM theme must be installed manually:${RESET}"
echo    "  https://github.com/Keyitdev/sddm-astronaut-theme"
echo
success "Done! Log out and back in (or reboot) to apply everything."
