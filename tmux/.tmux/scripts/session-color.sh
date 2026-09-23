#!/usr/bin/env bash

# Per-session status color: hash the session name into PALETTE
# and store it as the @session_color session option, unless one is already
# set (manual pick). A lightened variant is always (re)derived into
# @session_color_light, which the status bar uses as the prefix indicator.
# Invoked by the session-created hook and once at config load for pre-existing sessions.
#
# Usage: session-color.sh <session-name> | --all | --palette

PALETTE=(
  "#3b82f6" # blue
  "#16a34a" # green
  "#d97706" # amber
  "#dc2626" # red
  "#8b5cf6" # violet
  "#0d9488" # teal
  "#db2777" # pink
  "#0891b2" # cyan
  "#65a30d" # lime
  "#6366f1" # indigo
)

# Blend a #rrggbb color 35% toward white.
lighten() {
  local hex=${1#\#} r g b
  r=$((16#${hex:0:2}))
  g=$((16#${hex:2:2}))
  b=$((16#${hex:4:2}))
  printf '#%02x%02x%02x' \
    $(((r * 65 + 255 * 35) / 100)) \
    $(((g * 65 + 255 * 35) / 100)) \
    $(((b * 65 + 255 * 35) / 100))
}

assign() {
  local name=$1 color
  # window-mute.sh stash sessions never show a status bar.
  case $name in _muted_*) return 0 ;; esac
  color=$(tmux show-options -t "$name" -qv @session_color 2>/dev/null)
  if [ -z "$color" ]; then
    local sum=0 i
    for ((i = 0; i < ${#name}; i++)); do
      sum=$((sum + $(printf '%d' "'${name:i:1}")))
    done
    color=${PALETTE[sum % ${#PALETTE[@]}]}
    tmux set-option -t "$name" @session_color "$color"
  fi
  # Recomputed on every run so a manually picked color stays in sync.
  case "$color" in
  \#??????) tmux set-option -t "$name" @session_color_light "$(lighten "$color")" ;;
  esac
}

case "$1" in
--palette)
  # For pickers (e.g. the session switcher's color binding)
  printf '%s\n' "${PALETTE[@]}"
  ;;
--all)
  while IFS= read -r s; do
    assign "$s"
  done < <(tmux list-sessions -F '#{session_name}')
  ;;
*)
  assign "$1"
  ;;
esac
