#!/usr/bin/env bash

# agent-waiting.sh — Claude Code hook that flags a tmux pane as "waiting
# for you" until the pane is actually looked at.
#
# Usage (from ~/.claude/settings.json hooks):
#   agent-waiting.sh mark    Stop / Notification  — the agent needs input
#   agent-waiting.sh clear   UserPromptSubmit / SessionEnd — it got some
#
# A marker file per pane id lives in $WAIT_DIR; agent-status.sh renders it
# as the sticky 󰂚 state and deletes it once the pane is visible in an
# attached client. Non-Claude agents get the same effect through tmux's
# window bell flag (see bell-action in .tmux.conf).

WAIT_DIR="$HOME/.cache/tmux-agent/waiting"

cat >/dev/null # hook payload on stdin; the pane id from the env is enough
[ -n "${TMUX_PANE:-}" ] || exit 0

case "$1" in
mark)
  mkdir -p "$WAIT_DIR"
  touch "$WAIT_DIR/$TMUX_PANE"
  ;;
clear)
  rm -f "$WAIT_DIR/$TMUX_PANE"
  ;;
*)
  exit 0
  ;;
esac

tmux refresh-client -S 2>/dev/null
exit 0
