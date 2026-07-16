#!/usr/bin/env bash

# Absolute path (the tmux binding invokes it that way), exported so the
# re-exec'd fzf bindings can see it.
SELF="$0"
export SELF

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
  tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{?session_attached,●,○}' | sort -rn
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
  while IFS='|' read -r epoch name indicator; do
    age=$(relative_time "$epoch")
    agent_col "$name"
    printf "%-${w}s  %-8s %s  %s\n" "$name" "$age" "$indicator" "$AGENT_COL"
  done <<<"$lines"
}

# ── Bindings ────────────────────────────────────────────────────────────────

# ctrl-x: multi-select kill — fzf is re-invoked with --multi for selection,
# then each chosen session name is killed in a loop.
kill_binding="ctrl-x:become(
  selections=\$(tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{?session_attached,●,○}' | sort -rn |
    while IFS='|' read -r epoch name indicator; do
      age=\$(relative_time \"\$epoch\")
      printf '%-30s %-10s %s\n' \"\$name\" \"\$age\" \"\$indicator\"
    done |
    fzf --multi --no-sort \
        --prompt='Kill sessions (TAB to select multiple): ' \
        --header='<TAB>: toggle | <RET>: kill selected | <ESC>: cancel' \
        --border --border-label=' Kill Sessions ' \
        --height=40%)
  if [ -n \"\$selections\" ]; then
    while IFS= read -r line; do
      session=\$(echo \"\$line\" | awk '{print \$1}')
      tmux kill-session -t \"\$session\" 2>/dev/null
    done <<< \"\$selections\"
  fi
  exec \"\$SELF\"
)"

rename_binding="ctrl-r:become(
  new_name=\$(printf '' | fzf --print-query \
    --prompt='Rename {1} to: ' \
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

switch_previous_binding="ctrl-p:become(
  previous=\$(tmux list-sessions -F '#{session_last_attached}|#{session_name}' |
    sort -rn | sed -n '2p' | cut -d'|' -f2)
  [ -n \"\$previous\" ] && tmux switch-client -t \"\$previous\"
)"

preview_cmd='tmux capture-pane -ep -t {1} 2>/dev/null'

# ── Main ─────────────────────────────────────────────────────────────────────

# --with-shell: bindings exec $SELF and call the export -f'd relative_time,
# both of which need bash rather than whatever $SHELL happens to be.
selected=$(get_sessions | format_sessions |
  fzf --reverse \
    --ansi \
    --no-sort \
    --with-shell 'bash -c' \
    --style=full \
    --header=$'<C-x>: Kill | <C-r>: Rename | <C-n>: New | <C-t>: New from cwd | <C-p>: Previous | <C-/>: Toggle preview' \
    --border-label=' Select a tmux session ' \
    --bind="$kill_binding" \
    --bind="$rename_binding" \
    --bind="$create_binding" \
    --bind="$create_cwd_binding" \
    --bind="$switch_previous_binding" \
    --bind='ctrl-/:toggle-preview' \
    --preview="$preview_cmd" \
    --preview-window='right,65%,nowrap,<85(down,45%,nowrap)' |
  awk '{print $1}')

if [ -n "$selected" ]; then
  tmux switch-client -t "$selected"
fi
