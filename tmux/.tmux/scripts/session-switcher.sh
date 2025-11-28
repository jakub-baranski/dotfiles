#!/usr/bin/env bash

# Get session list with metadata
get_sessions() {
  tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{?session_attached,●,○}' | sort -r
}

# Format sessions for display
format_sessions() {
  awk -F'|' '{printf "%s %s\n", $2, $3}'
}

# Reload command for fzf (after kill/rename)
reload_cmd='tmux list-sessions -F "#{session_last_attached}|#{session_name}|#{?session_attached,●,○}" | sort -r | awk -F"|" "{printf \"%s %s\\n\", \$2, \$3}"'

# Kill session binding
kill_binding="ctrl-x:execute-silent(tmux kill-session -t {1})+reload($reload_cmd)"

# Rename session binding
rename_binding='ctrl-r:execute(bash -c "read -p \"Rename {1} to: \" new_name </dev/tty && tmux rename-session -t {1} $new_name")+reload('"$reload_cmd"')'

# Preview command
preview_cmd='tmux capture-pane -ep -t {1}:'

# Run fzf with all options and capture selection
selected=$(get_sessions | format_sessions |
  fzf --reverse \
    --header='Select session | C-x: kill session | C-r: rename session' \
    --bind="$kill_binding" \
    --bind="$rename_binding" \
    --preview="$preview_cmd" \
    --preview-window='right:65%:wrap' |
  awk '{print $1}')

# Switch to selected session if one was chosen
if [ -n "$selected" ]; then
  tmux switch-client -t "$selected"
fi
