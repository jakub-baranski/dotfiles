#!/usr/bin/env bash

get_sessions() {
  tmux list-sessions -F '#{session_last_attached}|#{session_name}|#{?session_attached,●,○}' | sort -r
}

format_sessions() {
  awk -F'|' '{printf "%s %s\n", $2, $3}'
}

kill_binding="ctrl-x:become(confirm=\$(printf 'No\nYes' | fzf --prompt='Kill session {1}? ' --height=6 --border --border-label=' Confirm Kill '); [ \"\$confirm\" = 'Yes' ] && tmux kill-session -t '{1}'; exec $0)"

rename_binding="ctrl-r:become(new_name=\$(printf '' | fzf --print-query --prompt='Rename {1} to: ' --height=3 --border --border-label=' Rename Session ' | head -1); [ -n \"\$new_name\" ] && tmux rename-session -t '{1}' \"\$new_name\"; exec $0)"

create_binding="ctrl-n:become(name=\$(printf '' | fzf --print-query --prompt='New session name: ' --height=3 --border --border-label=' Create Session ' --no-info | head -1); [ -n \"\$name\" ] && tmux new-session -d -s \"\$name\"; exec $0)"

# Preview command
preview_cmd='tmux capture-pane -ep -t {1}:'

selected=$(get_sessions | format_sessions |
  fzf --reverse \
    --style=full \
    --color=fg:#CAD3F5,header:#ED8796,info:#C6A0F6,pointer:#F4DBD6 \
    --header='<C-x>: Kill | <C-r>: Rename | <C-n>: New' \
    --border-label=' Select a tmux session ' \
    --bind="$kill_binding" \
    --bind="$rename_binding" \
    --bind="$create_binding" \
    --preview="$preview_cmd" \
    --preview-window='right:65%:nowrap' |
  awk '{print $1}')

if [ -n "$selected" ]; then
  tmux switch-client -t "$selected"
fi
