#!/usr/bin/env bash

# Absolute path (the tmux binding invokes it that way), exported so the
# re-exec'd fzf bindings can see it.
SELF="$0"
export SELF

# Keybinding reference, rendered in the preview pane by the f1 toggle.
if [ "$1" = "--help-text" ]; then
  printf '\033[1mSession switcher\033[0m\n\n'
  printf '\033[38;2;130;170;255m%-9s\033[0m %s\n' \
    'enter' 'Switch to session' \
    'ctrl-p' 'Switch to previous session' \
    'ctrl-n' 'New session (prompts for name)' \
    'ctrl-t' 'New session from current directory' \
    'ctrl-r' 'Rename session' \
    'ctrl-o' 'Set session color' \
    'ctrl-x' 'Kill sessions (multi-select)' \
    'ctrl-/' 'Toggle preview' \
    'f1' 'Toggle this help' \
    'esc' 'Close switcher'
  exit 0
fi

# Single timestamp for the whole listing, exported for relative_time calls
# inside re-exec'd bindings.
NOW=$(date +%s)
export NOW

# Convert epoch seconds to a human-readable relative time
relative_time() {
  local epoch=$1
  local now=${NOW:-$(date +%s)}
  local diff=$((now - epoch))

  if ((diff < 60)); then
    echo "just now"
  elif ((diff < 3600)); then
    echo "$((diff / 60))m ago"
  elif ((diff < 86400)); then
    echo "$((diff / 3600))h ago"
  elif ((diff < 604800)); then
    echo "$((diff / 86400))d ago"
  elif ((diff < 2592000)); then
    echo "$((diff / 604800))w ago"
  else
    echo "$((diff / 2592000))mo ago"
  fi
}
export -f relative_time

get_sessions() {
  tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{session_id}|#{@session_color}|#{?session_attached,●,○}' | sort -rn
}

# Per-session agent counts (agent-status.sh --all), computed in the background
# so fzf startup overlaps it; the atomic rename signals completion.
AGENT_SUMMARY_FILE="${TMPDIR:-/tmp}/session-switcher-agents-$USER"
rm -f "$AGENT_SUMMARY_FILE"
{
  "$HOME/.tmux/scripts/agent-status.sh" --all >"$AGENT_SUMMARY_FILE.part" 2>/dev/null
  mv "$AGENT_SUMMARY_FILE.part" "$AGENT_SUMMARY_FILE"
} &

# Sets AGENT_COL to the colored counts for a session; pure bash because it
# runs once per row.
agent_col() {
  AGENT_COL=""
  [ -r "$AGENT_SUMMARY_FILE" ] || return 0
  local name b a i
  while IFS=$'\t' read -r name b a i; do
    [ "$name" = "$1" ] || continue
    [ "${a:-0}" -gt 0 ] && AGENT_COL+=$'\033[1;38;2;255;117;127m󱈸'"$a"$'\033[0m '
    [ "${b:-0}" -gt 0 ] && AGENT_COL+=$'\033[38;2;195;232;141m󰪥'"$b"$'\033[0m '
    [ "${i:-0}" -gt 0 ] && AGENT_COL+=$'\033[38;2;255;199;119m󰧞'"$i"$'\033[0m '
    break
  done <"$AGENT_SUMMARY_FILE"
}

format_sessions() {
  # Wait for the background summary (normally <100ms); after 0.5s render the
  # rows without an agent column rather than hold up the list.
  for _ in {1..50}; do
    [ -e "$AGENT_SUMMARY_FILE" ] && break
    sleep 0.01
  done
  # Name column sized to the longest session name so rows stay narrow enough
  # for small screens.
  local lines w
  lines=$(cat)
  w=$(printf '%s\n' "$lines" | awk -F'|' '{ if (length($2) > w) w = length($2) } END { print w }')
  # Rows are "<id>\t<name>\t<display>" (--with-nth hides the key fields):
  # bindings target {1} because ids are exact and space-free, names aren't.
  local padded
  while IFS='|' read -r epoch name id color indicator; do
    age=$(relative_time "$epoch")
    agent_col "$name"
    # Pad before colorizing: escape codes would count toward %-Ns width.
    printf -v padded "%-${w}s" "$name"
    if [[ $color =~ ^#[0-9a-fA-F]{6}$ ]]; then
      padded=$'\033[38;2;'"$((16#${color:1:2}));$((16#${color:3:2}));$((16#${color:5:2}))m$padded"$'\033[0m'
    fi
    printf "%s\t%s\t%s  \033[2m%-4s\033[0m %-8s %s  %s\n" \
      "$id" "$name" "$padded" "$id" "$age" "$indicator" "$AGENT_COL"
  done <<<"$lines"
}

# ── Bindings ────────────────────────────────────────────────────────────────

# ctrl-x: multi-select kill via a second fzf with --multi.
kill_binding="ctrl-x:become(
  selections=\$(tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{session_id}|#{?session_attached,●,○}' | sort -rn |
    while IFS='|' read -r epoch name id indicator; do
      age=\$(relative_time \"\$epoch\")
      printf '%s\t%-30s %-10s %s\n' \"\$id\" \"\$name\" \"\$age\" \"\$indicator\"
    done |
    fzf --multi --no-sort \
        --delimiter='\t' --with-nth=2.. \
        --prompt='Kill sessions (TAB to select multiple): ' \
        --header='<TAB>: toggle | <RET>: kill selected | <ESC>: cancel' \
        --border --border-label=' Kill Sessions ' \
        --height=40%)
  if [ -n \"\$selections\" ]; then
    while IFS= read -r line; do
      session=\$(printf '%s' \"\$line\" | cut -f1)
      tmux kill-session -t \"\$session\" 2>/dev/null
    done <<< \"\$selections\"
  fi
  exec \"\$SELF\"
)"

rename_binding="ctrl-r:become(
  new_name=\$(printf '' | fzf --print-query \
    --prompt='Rename {2} to: ' \
    --height=3 --border --border-label=' Rename Session ' | head -1)
  [ -n \"\$new_name\" ] && tmux rename-session -t '{1}' \"\$new_name\"
  exec \"\$SELF\"
)"

# ctrl-n: prompt for name, create, and switch to new session
create_binding="ctrl-n:become(
  name=\$(printf '' | fzf --print-query \
    --prompt='New session name: ' \
    --height=3 --border --border-label=' Create Session ' --no-info | head -1)
  [ -n \"\$name\" ] && tmux new-session -d -s \"\$name\" && tmux switch-client -t \"\$name\"
  exec \"\$SELF\"
)"

# ctrl-o: pick a status-bar color for the highlighted session; the palette
# comes from session-color.sh
color_binding="ctrl-o:become(
  color=\$(\"\$HOME/.tmux/scripts/session-color.sh\" --palette |
    while IFS= read -r c; do
      r=\$((16#\${c:1:2})); g=\$((16#\${c:3:2})); b=\$((16#\${c:5:2}))
      printf '\033[48;2;%d;%d;%dm      \033[0m %s\n' \"\$r\" \"\$g\" \"\$b\" \"\$c\"
    done |
    fzf --ansi --no-sort \
        --prompt='Color for {2}: ' \
        --height=12 --border --border-label=' Session Color ' |
    awk '{print \$NF}')
  [ -n \"\$color\" ] && tmux set-option -t '{1}' @session_color \"\$color\"
  exec \"\$SELF\"
)"

# ctrl-t: new session named after cwd basename, starting in cwd
create_cwd_binding="ctrl-t:become(
  name=\$(basename \"\$PWD\")
  # Append a counter if the name already exists
  base=\$name; i=1
  while tmux has-session -t \"\$name\" 2>/dev/null; do
    name=\"\${base}-\${i}\"; i=\$(( i + 1 ))
  done
  tmux new-session -d -s \"\$name\" -c \"\$PWD\" && tmux switch-client -t \"\$name\"
  exec \"\$SELF\"
)"

# f1: toggle help in the preview pane. The HELP_STATE flag exists while help
# is shown;
# Colon-form transform because the parens in the echoed actions would confuse fzf's bind parser.
HELP_STATE="${TMPDIR:-/tmp}/session-switcher-help-$USER"
export HELP_STATE
rm -f "$HELP_STATE"
help_binding="f1:transform:
  if [ -e \"\$HELP_STATE\" ]; then
    rm -f \"\$HELP_STATE\"
    echo 'refresh-preview'
  else
    touch \"\$HELP_STATE\"
    echo 'show-preview+preview(\"\$SELF\" --help-text)'
  fi"

switch_previous_binding="ctrl-p:become(
  previous=\$(tmux list-sessions -F '#{session_last_attached}|#{session_id}' |
    sort -rn | sed -n '2p' | cut -d'|' -f2)
  [ -n \"\$previous\" ] && tmux switch-client -t \"\$previous\"
)"

# rm: leaving help mode by moving the cursor must clear the f1 toggle flag.
preview_cmd='rm -f "$HELP_STATE"; tmux capture-pane -ep -t {1} 2>/dev/null'

# ── Main ─────────────────────────────────────────────────────────────────────

# --with-shell: bindings exec $SELF and call the export -f'd relative_time,
# both of which need bash rather than whatever $SHELL happens to be.
selected=$(get_sessions | format_sessions |
  fzf --reverse \
    --ansi \
    --no-sort \
    --delimiter='\t' --with-nth=3.. \
    --with-shell 'bash -c' \
    --style=full \
    --header=$'<F1>: Help' \
    --border-label=' Select a tmux session ' \
    --bind="$kill_binding" \
    --bind="$rename_binding" \
    --bind="$create_binding" \
    --bind="$create_cwd_binding" \
    --bind="$color_binding" \
    --bind="$switch_previous_binding" \
    --bind="$help_binding" \
    --bind='ctrl-/:toggle-preview' \
    --preview="$preview_cmd" \
    --preview-window='right,65%,nowrap,<85(down,45%,nowrap)' |
  cut -f1)

if [ -n "$selected" ]; then
  tmux switch-client -t "$selected"
fi
