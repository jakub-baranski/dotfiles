#!/usr/bin/env bash

# Per-session status color: hash the session name into PALETTE
# and store it as the @session_color session option, unless one is already
# set (manual pick).
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

assign() {
  local name=$1
  [ -n "$(tmux show-options -t "$name" -qv @session_color 2>/dev/null)" ] && return 0
  local sum=0 i
  for ((i = 0; i < ${#name}; i++)); do
    sum=$((sum + $(printf '%d' "'${name:i:1}")))
  done
  tmux set-option -t "$name" @session_color "${PALETTE[sum % ${#PALETTE[@]}]}"
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
