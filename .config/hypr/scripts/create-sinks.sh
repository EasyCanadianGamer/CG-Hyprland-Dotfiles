#!/usr/bin/env bash
# Creates virtual null sinks + loopbacks for audio routing via PipeWire/PulseAudio.
# Sinks are lost on reboot — re-run this script to recreate them.
# Safe to re-run — skips already existing sinks AND loopbacks.
#
# Sink layout:
#   game_sink   → games
#   chat_sink   → Discord
#   music_sink  → Spotify / music players
#   system_sink → browsers (Firefox, Helium), misc
#
# Each sink has a loopback to OUTPUT_SINK so you can hear everything.
# OBS captures each sink's .monitor source as a separate track.

set -euo pipefail

# ── Output device — where you actually hear audio ────────────────────────────
OUTPUT_SINK="alsa_output.pci-0000_00_1f.3.analog-stereo"
# ─────────────────────────────────────────────────────────────────────────────

declare -A SINKS=(
    ["game_sink"]="Game"
    ["chat_sink"]="Chat"
    ["music_sink"]="Music"
    ["system_sink"]="System"
)

# Wait for PipeWire AND the hardware output sink to be enumerated (up to 30s).
# PipeWire's socket opens before WirePlumber finishes enumerating hardware sinks,
# so we must wait for OUTPUT_SINK specifically — not just for pactl to respond.
TIMEOUT=30
echo "Waiting for audio hardware to be ready..."
for i in $(seq 1 $TIMEOUT); do
    pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -qx "$OUTPUT_SINK" && break
    if [ "$i" -eq "$TIMEOUT" ]; then
        echo "WARNING: '$OUTPUT_SINK' not found after ${TIMEOUT}s, falling back to default"
        OUTPUT_SINK=$(pactl info 2>/dev/null | grep "Default Sink" | awk '{print $3}')
        echo "  Using: $OUTPUT_SINK"
    fi
    sleep 1
done
echo "Audio ready (took ${i}s)"

create_sink() {
    local name="$1"
    local desc="$2"
    if pactl list sinks short | awk '{print $2}' | grep -qx "$name"; then
        echo "  [skip] '$name' already exists"
    else
        pactl load-module module-null-sink \
            sink_name="$name" \
            sink_properties="device.description='$desc'" > /dev/null
        echo "  [ok]   '$name' created ($desc)"
    fi
}

create_loopback() {
    local name="$1"
    local existing
    existing=$(pactl list modules short | grep "module-loopback" | grep "source=${name}.monitor" || true)
    if echo "$existing" | grep -q "sink=${OUTPUT_SINK}"; then
        echo "  [skip] loopback for '${name}' already exists"
    else
        # Remove stale loopback if it exists but points to the wrong sink
        if [ -n "$existing" ]; then
            local mod_id
            mod_id=$(echo "$existing" | awk '{print $1}')
            echo "  [fix]  removing stale loopback for '${name}' (wrong sink)"
            pactl unload-module "$mod_id"
        fi
        pactl load-module module-loopback \
            source="${name}.monitor" \
            sink="$OUTPUT_SINK" \
            latency_msec=50 > /dev/null
        echo "  [ok]   loopback: ${name}.monitor → $OUTPUT_SINK"
    fi
}

echo "Creating virtual audio sinks..."
for name in game_sink chat_sink music_sink system_sink; do
    create_sink "$name" "${SINKS[$name]}"
done

echo ""
echo "Creating loopbacks to '$OUTPUT_SINK'..."
for name in game_sink chat_sink music_sink system_sink; do
    create_loopback "$name"
done

echo ""
echo "Setting system_sink as default (catches misc apps automatically)..."
pactl set-default-sink system_sink
echo "  [ok]   default sink → system_sink"

echo ""
echo "Done."
echo ""
echo "Next steps:"
echo "  1. Use qpwgraph to route apps to their sinks"
echo "  2. In OBS, add Audio Input Capture for each:"
echo "     - Monitor of Game   → game_sink.monitor"
echo "     - Monitor of Chat   → chat_sink.monitor"
echo "     - Monitor of Music  → music_sink.monitor"
echo "     - Monitor of System → system_sink.monitor"
echo "  3. Firefox/Helium needs --enable-features=PipeWireAudio flag"
echo "     to route through PipeWire instead of ALSA directly"
