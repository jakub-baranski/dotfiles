#!/usr/bin/env bash

# agent-status.sh — AI-agent indicator for the tmux status bar.
#
# Usage:
#   agent-status.sh <window_id>   styled icon for one window   (window-status-format)
#   agent-status.sh --all         per-session summary          (session switcher)
#
# Finds agent processes (claude, codex, ...) in the panes' process trees,
# then classifies each agent pane by its visible bottom lines:
#
#   󱈸  attention   blocked on a permission / question dialog
#   󰪥  busy        working — rendered as an animated spinner
#   󰧞  idle        waiting for a new prompt
#
# Output:
#   <window_id>   one #[fg=...]-styled icon; nothing when no agent runs there
#   --all         one line per session with agents:
#                 session<TAB>busy<TAB>attention<TAB>idle

TARGET="$1"
[ -n "$TARGET" ] || exit 0

# Process names treated as agents (exact basename match, case-insensitive).
AGENTS="claude|codex|opencode|gemini|aider|amp|goose|crush|cursor-agent"

# "busy" markers — three independent signals, any one means "working":
#   - "esc to interrupt/cancel" hints                 (codex, gemini, opencode, older claude)
#   - the thinking/streaming spinner: a glyph-prefixed line ending in an
#     ellipsis followed by an elapsed timer, e.g.
#       "✳ Scoping Phase 2 frontend endpoints… (33m 26s · ↓ 110k tokens)"
#     The status text is a free-form phrase, NOT a single word, so we match
#     "<glyph> … (<n>m <n>s" rather than "<glyph> <Word>… (".
#   - a running tool line carrying a live "· <elapsed>s" timer, e.g.
#       "⏺ Finding file-level failure · 18s"  or  "⏺ Running … · 6s…"
#     The trailing "…" animates in and out, so it is optional; a word
#     boundary after the "s" keeps "· 2 shells" from matching.
BUSY_REGEX='[Ee]sc(ape)? (to )?(interrupt|cancel)|^[^[:alnum:][:space:]].*(…|\.\.\.) \([0-9]+m?[[:space:]]?[0-9]*s|·[[:space:]][0-9]+m?[[:space:]]?[0-9]*s([[:space:]…]|$)'

# "attention" markers: permission prompts, plan approval, question menus.
ATTENTION_REGEX='Do you want|Would you like|Do you trust|❯ 1\.'

# Nerd-font glyphs: busy = circle_slice_1..8, idle = circle_medium,
# attention = exclamation_thick.
BUSY_FRAMES=(󰪞 󰪟 󰪠 󰪡 󰪢 󰪣 󰪤 󰪥)
BUSY_COLOR="#c3e88d"
IDLE_ICON="󰧞"
IDLE_COLOR="#ffc777"
ATTENTION_ICON="󱈸"
ATTENTION_COLOR="#ff757f"

# Flat "pane_id pane_pid ..." list — BSD awk rejects newlines in -v strings.
# --all also needs each pane's session, fetched in the same round-trip.
if [ "$TARGET" = "--all" ]; then
  all_panes=$(tmux list-panes -a -F '#{pane_id}|#{pane_pid}|#{session_name}' 2>/dev/null)
  panes=$(printf '%s\n' "$all_panes" | awk -F'|' '{printf "%s %s ", $1, $2}')
else
  panes=$(tmux list-panes -t "$TARGET" -F '#{pane_id} #{pane_pid}' 2>/dev/null | tr '\n' ' ')
fi
[ -n "$panes" ] || exit 0

# Walk each agent process's parent chain up to a pane root shell — finds
# agents nested arbitrarily deep (nvim terminals) and drops name matches
# living outside tmux (the Claude desktop app).
agent_panes=$(ps -Ao ppid=,pid=,comm= | awk -v panes="$panes" -v agents="$AGENTS" '
  BEGIN {
    n = split(panes, arr, /[ \n]+/)
    for (i = 1; i + 1 <= n; i += 2) pane_of[arr[i + 1]] = arr[i]
  }
  {
    parent[$2] = $1
    comm = $0
    sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+/, "", comm)
    base = tolower(comm)
    sub(/.*\//, "", base)
    if (base ~ ("^(" agents ")$")) agent[$2] = 1
  }
  END {
    for (a in agent) {
      p = a
      for (i = 0; i < 30; i++) {
        if (p in pane_of) { print pane_of[p]; break }
        if (!(p in parent)) break
        p = parent[p]
      }
    }
  }' | sort -u)

[ -n "$agent_panes" ] || exit 0

# Busy is checked before attention per pane: streamed text can quote a
# question, but a real dialog never coexists with the spinner.
pane_state() {
  local bottom
  # tail -30, not -15: Claude renders the todo checklist BELOW the spinner,
  # so a long checklist can push the spinner out of a 15-line window.
  bottom=$(tmux capture-pane -p -t "$1" 2>/dev/null | grep -v '^[[:space:]]*$' | tail -30)
  if printf '%s\n' "$bottom" | grep -qE "$BUSY_REGEX"; then
    printf 'busy'
  elif printf '%s\n' "$bottom" | grep -qE "$ATTENTION_REGEX"; then
    printf 'attention'
  else
    printf 'idle'
  fi
}

if [ "$TARGET" = "--all" ]; then
  # Classify panes in parallel — serial capture-pane round-trips dominate
  # the runtime.
  {
    for pane in $agent_panes; do
      {
        sess=$(printf '%s\n' "$all_panes" | awk -F'|' -v p="$pane" \
          '$1 == p { sub(/^[^|]*\|[^|]*\|/, ""); print; exit }')
        printf '%s\t%s\n' "$sess" "$(pane_state "$pane")"
      } &
    done
    wait
  } | awk -F'\t' '
    $1 != "" {
      if ($2 == "busy") busy[$1]++
      else if ($2 == "attention") attn[$1]++
      else idle[$1]++
      seen[$1] = 1
    }
    END {
      for (s in seen) printf "%s\t%d\t%d\t%d\n", s, busy[s], attn[s], idle[s]
    }'
  exit 0
fi

# Across panes attention wins — a blocked agent needs you more than a busy
# one needs watching.
state="idle"
for pane in $agent_panes; do
  case "$(pane_state "$pane")" in
  busy) [ "$state" = "idle" ] && state="busy" ;;
  attention)
    state="attention"
    break
    ;;
  esac
done

case $state in
attention)
  printf ' #[fg=%s,bold]%s#[default]' "$ATTENTION_COLOR" "$ATTENTION_ICON"
  ;;
busy)
  frame=${BUSY_FRAMES[$(($(date +%s) % ${#BUSY_FRAMES[@]}))]}
  printf ' #[fg=%s]%s#[default]' "$BUSY_COLOR" "$frame"
  ;;
*)
  printf ' #[fg=%s]%s#[default]' "$IDLE_COLOR" "$IDLE_ICON"
  ;;
esac
