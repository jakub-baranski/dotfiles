#!/usr/bin/env bash

# agent-status.sh — AI-agent indicator for the tmux status bar.
#
# Usage:
#   agent-status.sh <window_id>       styled icon for one window   (window-status-format)
#   agent-status.sh --all             per-session summary          (session switcher)
#   agent-status.sh --waiting <sess>  unseen-finish count outside <sess> (status-right)
#
# Finds agent processes (claude, codex, ...) in the panes' process trees,
# then classifies each agent pane by its visible bottom lines:
#
#   󱈸  attention   blocked on a permission / question dialog
#   󰪥  busy        working — rendered as an animated spinner
#   󰂚  waiting     finished / asked something while you were elsewhere
#   󰧞  idle        waiting for a new prompt
#
# "waiting" is sticky: it is raised by agent-waiting.sh (Claude Code hooks)
# dropping a marker file per pane, or by tmux's window bell flag for agents
# that ring the bell when done, and it only drops once the pane is visible
# in an attached client — so a finish you did not see stays flagged.
#
# Output:
#   <window_id>   one #[fg=...]-styled icon; nothing when no agent runs there
#   --all         one line per session with agents:
#                 session<TAB>busy<TAB>attention<TAB>idle<TAB>waiting
#   --waiting     " 󰂚 N" styled, or nothing when N is 0

TARGET="$1"
[ -n "$TARGET" ] || exit 0

WAIT_DIR="$HOME/.cache/tmux-agent/waiting"

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
#     boundary after the "s" keeps "· 2 shells" from matching. A completed
#     subagent keeps its timer ("⏺ Agent "x" finished · 59s"), hence the
#     separate exclusion.
#   - a background subagent row: elapsed timer then a live token counter, e.g.
#       "◯ general-purpose  Running tests.py    1m 17s · ↓ 48.3k tokens"
#     The main agent may already be at its prompt, but it is still waiting
#     on that work, so the pane counts as busy.
BUSY_EXCLUDE_REGEX='finished ·'
BUSY_REGEX='[Ee]sc(ape)? (to )?(interrupt|cancel)|^[^[:alnum:][:space:]].*(…|\.\.\.) \([0-9]+m?[[:space:]]?[0-9]*s|·[[:space:]][0-9]+m?[[:space:]]?[0-9]*s([[:space:]…]|$)|[0-9]+m?[[:space:]]?[0-9]*s · ↓ [0-9.]+k? tokens'

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
WAITING_ICON="󰂚"
WAITING_COLOR="#c099ff"

# One list-panes round-trip per run. Fields 4-8 decide the sticky state:
# a pane is "visible" when its window is the current one of a session with
# a client attached, unless another pane in it is zoomed.
PANE_FMT='#{pane_id}|#{pane_pid}|#{session_name}|#{pane_active}|#{window_active}|#{session_attached}|#{window_bell_flag}|#{window_zoomed_flag}'
VISIBLE_AWK='($5 && $6 > 0 && ($4 || !$8))'

# Prints a pane's fields from $all_panes as "session visible bell".
pane_meta() {
  printf '%s\n' "$all_panes" | awk -F'|' -v p="$1" '
    $1 == p { print $3, ('"$VISIBLE_AWK"' ? 1 : 0), $7; exit }'
}

# Bottom of a pane's screen, blank lines dropped. tail -30, not -15: Claude
# renders the todo checklist BELOW the spinner, so a long checklist can push
# the spinner out of a 15-line window.
pane_bottom() {
  tmux capture-pane -p -t "$1" 2>/dev/null | grep -v '^[[:space:]]*$' | tail -30
}

pane_busy() {
  printf '%s\n' "$1" | grep -vE "$BUSY_EXCLUDE_REGEX" | grep -qE "$BUSY_REGEX"
}

# --waiting skips the ps walk and only captures the flagged panes, because
# it runs every status-interval from status-right. It counts flagged,
# non-busy panes in other sessions (the current one shows them on its
# window tabs) and prunes markers whose pane is gone. The busy check keeps
# it in step with what the tabs and the switcher show.
if [ "$TARGET" = "--waiting" ]; then
  all_panes=$(tmux list-panes -a -F "$PANE_FMT" 2>/dev/null)
  candidates=$(printf '%s\n' "$all_panes" | awk -F'|' -v cur="$2" -v dir="$WAIT_DIR" '
    { visible = '"$VISIBLE_AWK"' }
    $3 != cur && !visible && ($7 || (getline junk < (dir "/" $1)) >= 0) { print $1 }')
  count=0
  for pane in $candidates; do
    pane_busy "$(pane_bottom "$pane")" || count=$((count + 1))
  done
  for marker in "$WAIT_DIR"/%*; do
    [ -e "$marker" ] || continue
    printf '%s\n' "$all_panes" | grep -q "^${marker##*/}|" || rm -f "$marker"
  done
  [ "$count" -gt 0 ] && printf ' #[fg=%s,bold]%s %d#[default]' "$WAITING_COLOR" "$WAITING_ICON" "$count"
  exit 0
fi

# Flat "pane_id pane_pid ..." list — BSD awk rejects newlines in -v strings.
if [ "$TARGET" = "--all" ]; then
  all_panes=$(tmux list-panes -a -F "$PANE_FMT" 2>/dev/null)
else
  all_panes=$(tmux list-panes -t "$TARGET" -F "$PANE_FMT" 2>/dev/null)
fi
panes=$(printf '%s\n' "$all_panes" | awk -F'|' '{printf "%s %s ", $1, $2}')
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
#
# The waiting marker is only dropped by visibility (here) or a new prompt
# (agent-waiting.sh clear) — never because a hidden pane looks busy:
# Claude's Stop hook fires while the spinner is still on screen, so a busy
# tick right after it would eat the flag. A lingering marker under a busy
# pane is simply hidden by precedence.
pane_state() {
  local bottom sess visible bell
  read -r sess visible bell <<<"$(pane_meta "$1")"
  [ "$visible" = 1 ] && rm -f "$WAIT_DIR/$1"
  bottom=$(pane_bottom "$1")
  if pane_busy "$bottom"; then
    printf 'busy'
    return
  fi
  if [ "$visible" != 1 ] && { [ "$bell" = 1 ] || [ -e "$WAIT_DIR/$1" ]; }; then
    # A dialog still outranks the flag: it names what is being waited on.
    printf '%s\n' "$bottom" | grep -qE "$ATTENTION_REGEX" && printf 'attention' || printf 'waiting'
    return
  fi
  if printf '%s\n' "$bottom" | grep -qE "$ATTENTION_REGEX"; then
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
        read -r sess _ <<<"$(pane_meta "$pane")"
        printf '%s\t%s\n' "$sess" "$(pane_state "$pane")"
      } &
    done
    wait
  } | awk -F'\t' '
    $1 != "" {
      if ($2 == "busy") busy[$1]++
      else if ($2 == "attention") attn[$1]++
      else if ($2 == "waiting") wait[$1]++
      else idle[$1]++
      seen[$1] = 1
    }
    END {
      for (s in seen) printf "%s\t%d\t%d\t%d\t%d\n", s, busy[s], attn[s], idle[s], wait[s]
    }'
  exit 0
fi

# Across panes attention > waiting > busy > idle — a blocked agent needs
# you more than a busy one needs watching, and an unseen finish more than
# either.
state="idle"
for pane in $agent_panes; do
  case "$(pane_state "$pane")" in
  busy) [ "$state" = "idle" ] && state="busy" ;;
  waiting) [ "$state" != "attention" ] && state="waiting" ;;
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
waiting)
  printf ' #[fg=%s,bold]%s#[default]' "$WAITING_COLOR" "$WAITING_ICON"
  ;;
busy)
  frame=${BUSY_FRAMES[$(($(date +%s) % ${#BUSY_FRAMES[@]}))]}
  printf ' #[fg=%s]%s#[default]' "$BUSY_COLOR" "$frame"
  ;;
*)
  printf ' #[fg=%s]%s#[default]' "$IDLE_COLOR" "$IDLE_ICON"
  ;;
esac
