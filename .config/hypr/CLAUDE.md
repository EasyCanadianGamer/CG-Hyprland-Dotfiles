# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Hyprland Wayland compositor configuration for an Arch Linux system with an NVIDIA GPU and a dual-monitor setup. Running Hyprland 0.56.1.

## Applying changes

Changes to `.lua` files are picked up without a full Hyprland restart via:

```bash
hyprctl reload
```

Changes to scripts take effect immediately on next invocation. After modifying `create-sinks.sh`, re-run it manually:

```bash
~/.config/hypr/scripts/create-sinks.sh
```

## Config structure — Lua (active)

`hyprland.lua` is the entry point. Hyprland 0.56.1's native Lua config support picks it up in place of `hyprland.conf`. It `require()`s two sub-files:

| File | Purpose |
|---|---|
| `monitors.lua` | Monitor layout (HDMI-A-1 primary @60Hz, DVI-D-1 secondary left @120Hz) via `hl.monitor()` |
| `binds.lua` | All keybindings (`mainMod = "SUPER"`) via `hl.bind()`; itself `require()`s `programs.lua` |
| `programs.lua` | Returns a table of program variables (`terminal`, `fileManager`, `browser`, `helium`, `menu`) consumed via `local programs = require("programs")` |

`hyprland.lua` itself holds autostart, environment variables, look-and-feel (`hl.config()`), animation curves/config, dwindle/master layout, misc, and input — all translated from the old keyword syntax into the `hl.*` Lua API. Window rules are present only as commented-out reference translations (`hl.window_rule(...)`) at the bottom of the file — none are currently active.

Two autostart mechanisms are used and are **not interchangeable**:
- `hl.on("hyprland.start", function() ... end)` — fires once, at compositor start (replaces old `exec-once`). All the sink/waybar/wallpaper/session bring-up lives here.
- Bare `hl.exec_cmd(...)` calls at the top level of the file — run on every config load/reload (replaces old plain `exec`). Currently used only for the two `gsettings` calls.

When adding new keybinds or programs, edit `binds.lua` / `programs.lua`, not `hyprland.lua` directly. Reference: https://wiki.hypr.land/Configuring/Start/

The commitment to Lua is intentional and permanent, not a trial — Hyprland itself is deprecating `hyprlang`/`.conf` in favor of Lua, so there's no plan to revert. A full backup of the pre-migration `.conf` setup lives at `~/.config/back-hypr` in case it's ever needed for reference.

### Known gotcha: `hyprctl dispatch` classic syntax is broken under the Lua engine

Once `hyprland.lua` is the loaded config (confirmed via the session log: `Using lua config found at .../hyprland.lua`), Hyprland's IPC socket **no longer accepts the old space-separated dispatch syntax** (`dispatch workspace 2`, `dispatch exit`, etc.) — it now evaluates dispatch commands as Lua expressions against the `hl.dsp.*` API. Verified directly against the raw socket (bypassing `hyprctl` and any client):

```bash
# OLD — fails silently with a Lua parse error, does nothing:
hyprctl dispatch workspace 2

# NEW — required syntax:
hyprctl dispatch 'hl.dsp.focus({workspace=2})'
```

**Practical impact:** any external tool that shells out to `hyprctl dispatch <name> <args>` in the old style will silently fail — no error surfaces to the user, the action just doesn't happen. This currently breaks waybar's `hyprland/workspaces` module's built-in `"on-click": "activate"` handler (the workspace dots) — waybar v0.15.0 hardcodes the old syntax internally and can't be reconfigured around it. The module's `on-scroll-up`/`on-scroll-down` *are* plain config strings, though, so those were repointed at the new syntax in `~/.config/waybar/config` and work fine. Workspace-switch keybinds (`SUPER+1-9` etc.) are unaffected since those go through Hyprland's own `hl.bind()`/dispatcher system, not external IPC calls.

When adding any new script or tool that talks to Hyprland via `hyprctl dispatch`, use the new `hl.dsp.*`-expression syntax from the start.

## Legacy `.conf` files (removed)

`binds.conf`, `programs.conf`, `monitors.conf`, `hyprpaper.conf`, and `workspaces.conf` no longer exist in this directory — they were deleted after the Lua migration was confirmed working. There is no `hyprland.conf`, so if any `.conf` file reappears here it's either a manual copy-back or (rarer) the Lua config failed to load and Hyprland's built-in safety net regenerated a minimal stub `hyprland.conf` to avoid a lockout — check `hyprctl configerrors` and the session log (`$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log`) if that happens.

## Audio routing

`create-sinks.sh` creates four virtual PipeWire null-sinks for OBS multi-track recording, invoked from `hyprland.lua`'s `hl.on("hyprland.start", ...)` block:

- `game_sink` — games
- `chat_sink` — Discord
- `music_sink` — Spotify / music players
- `system_sink` — browsers, misc (set as default sink)

Each sink has a loopback to the hardware output (`alsa_output.pci-0000_00_1f.3.analog-stereo`). **Sinks are not persistent** — this script runs on every Hyprland startup. It is safe to re-run; it skips already-existing sinks and loopbacks, and waits up to 30s for the hardware output sink to be enumerated by WirePlumber before proceeding.

Use `qpwgraph` to route apps to their respective sinks. OBS should capture `*.monitor` sources as separate audio tracks. Firefox/Helium need the `--enable-features=PipeWireAudio` flag to route through PipeWire instead of ALSA directly.

`start-audio.sh` (manual PipeWire/WirePlumber bring-up) is legacy and commented out in `hyprland.lua`'s autostart block — not part of the active startup path.

## Wallpaper / theme system

- Wallpaper daemon: `awww-daemon` (not `swww`)
- Active wallpaper path is cached in `~/.cache/current-wallpaper`
- `set-wallpaper.sh` restores the cached wallpaper on login (falls back to `~/.local/share/themes/Arch/wallpaper.png` if the cache is missing)
- `theme-switcher.sh` (bound to `SUPER+W`) opens a rofi picker over `~/.local/share/themes/*/`. Each theme directory must contain `wallpaper.png` and `theme.sh` (which applies GTK/Qt/color scheme changes). An optional `preview.png` is used as the rofi icon.
- `hyprpaper.conf` is not used by either path — it's dead config, wallpaper is fully handled by the two scripts above via `awww`.

## Screenshots

Bound to `SUPER+SHIFT+S`. `screenshot.sh` opens a rofi menu with three modes:
- **Fullscreen** — `grim`
- **Region** — `grim` + `slurp`
- **Window** — `grim` using `hyprctl activewindow -j` geometry via `jq`

Screenshots are saved to `~/Pictures/Screenshots/` (created if missing) as `YYYY-MM-DD_HH-MM-SS.png`.

## NVIDIA-specific environment variables

Set via `hl.env(...)` in `hyprland.lua` and required for proper rendering:

```
LIBVA_DRIVER_NAME=nvidia
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
NVD_BACKEND=direct
```

Do not remove these — they are needed for hardware video acceleration and XWayland on NVIDIA.

## Key dependencies

`kitty`, `dolphin`, `firefox`, `helium-browser`, `rofi`, `waybar`, `awww`/`awww-daemon`, `grim`, `slurp`, `jq`, `wpctl` (WirePlumber), `playerctl`, `brightnessctl`, `hyprpolkitagent`, `pactl`, `qpwgraph`, `gsettings`, `dbus-update-activation-environment`
