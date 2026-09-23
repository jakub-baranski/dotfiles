#!/usr/bin/env bash

# window-mute.sh — temporarily hide a window from its session.
#
# Usage:
#   window-mute.sh mute <window_id> <duration>   hide for 15m / 1h / 2h30m / 90s (bare number = minutes) / tomorrow (8:00)
#   window-mute.sh unmute <window_id> [select]   bring back now; "select" also switches to it
#   window-mute.sh unmute-all <session_id>       bring back every window muted from a session
#   window-mute.sh timer <window_id> <until>     background wait, then unmute unless re-muted or unmuted meanwhile
#   window-mute.sh sweep                         unmute everything past its deadline
#   window-mute.sh picker <client>               fzf popup of the client's session's muted windows
#   window-mute.sh closed <session_name>         session-closed hook: drop that session's stash
#
# Muted windows live in a detached "_muted_<origin>" session, so cycling and
# the status line skip them while their processes keep running.
# Restore data sits in window options (@muted_*) because they move with the window.

STASH_PREFIX="_muted_"
SELF="$HOME/.tmux/scripts/window-mute.sh"

# "1h30m" / "45s" / "20" (minutes) / "tomorrow" -> seconds; empty on bad input.
parse_duration() {
  local input=$1 total=0 num unit
  if [ "$input" = "tomorrow" ]; then
    echo $(($(date -v+1d -v8H -v0M -v0S +%s) - $(date +%s)))
    return
  fi
  [[ $input =~ ^[0-9]+$ ]] && input="${input}m"
  [[ $input =~ ^([0-9]+[smhd])+$ ]] || return 1
  while [[ $input =~ ^([0-9]+)([smhd])(.*)$ ]]; do
    num=${BASH_REMATCH[1]} unit=${BASH_REMATCH[2]} input=${BASH_REMATCH[3]}
    case $unit in
    s) total=$((total + num)) ;;
    m) total=$((total + num * 60)) ;;
    h) total=$((total + num * 3600)) ;;
    d) total=$((total + num * 86400)) ;;
    esac
  done
  ((total > 0)) && echo "$total"
}

human_left() {
  local s=$1
  if ((s <= 0)); then
    echo "now"
  elif ((s < 60)); then
    echo "${s}s"
  elif ((s < 3600)); then
    echo "$(((s + 59) / 60))m"
  else
    printf '%dh%02dm\n' $((s / 3600)) $(((s % 3600) / 60))
  fi
}

# tmux turns '.' and ':' in session names into '_'.
stash_name() {
  local name=${1//[.:]/_}
  echo "${STASH_PREFIX}${name}"
}

find_stash() {
  tmux list-sessions -F '#{session_id}|#{@muted_origin}' 2>/dev/null |
    awk -F'|' -v o="$1" '$2 == o { print $1; exit }'
}

# Falls back to all clients so a restore is never silent.
notify() {
  local session=$1 msg=$2 clients
  clients=$(tmux list-clients -F '#{client_name}|#{session_id}' 2>/dev/null |
    awk -F'|' -v s="$session" '$2 == s { print $1 }')
  [ -n "$clients" ] || clients=$(tmux list-clients -F '#{client_name}' 2>/dev/null)
  for c in $clients; do
    tmux display-message -c "$c" -d 3000 "$msg"
  done
}

refresh_count() {
  local origin=$1 stash count=0
  tmux has-session -t "$origin" 2>/dev/null || return 0
  stash=$(find_stash "$origin")
  [ -n "$stash" ] && count=$(tmux list-windows -t "$stash" 2>/dev/null | wc -l | tr -d ' ')
  if ((count > 0)); then
    tmux set-option -t "$origin" @muted_count "$count"
  else
    tmux set-option -t "$origin" -u @muted_count
  fi
  tmux refresh-client -S 2>/dev/null
}

mute() {
  local win=$1 seconds origin origin_name index name windows stash placeholder until
  seconds=$(parse_duration "$2") || {
    tmux display-message "Mute: bad duration '$2' (try 15m, 1h, 2h30m)"
    return 1
  }
  IFS='|' read -r origin origin_name index windows name < <(
    tmux display-message -p -t "$win" '#{session_id}|#{session_name}|#{window_index}|#{session_windows}|#{window_name}')
  [ -n "$origin" ] || return 1
  case $origin_name in "$STASH_PREFIX"*)
    tmux display-message "Window is already muted"
    return 1
    ;;
  esac
  # Moving the last window out would destroy the session.
  if ((windows <= 1)); then
    tmux display-message "Can't mute the only window of a session"
    return 1
  fi

  stash=$(find_stash "$origin")
  if [ -z "$stash" ]; then
    # new-session always spawns a window; dropped once ours arrives.
    stash=$(tmux new-session -d -P -F '#{session_id}' -s "$(stash_name "$origin_name")")
    placeholder=$(tmux list-windows -t "$stash" -F '#{window_id}')
    tmux set-option -t "$stash" @muted_origin "$origin"
  fi

  until=$(($(date +%s) + seconds))
  tmux set-option -w -t "$win" @muted_from "$origin"
  tmux set-option -w -t "$win" @muted_index "$index"
  tmux set-option -w -t "$win" @muted_until "$until"
  tmux move-window -d -s "$win" -t "$stash:"
  [ -n "$placeholder" ] && tmux kill-window -t "$placeholder"

  tmux run-shell -b "'$SELF' timer '$win' '$until'"
  refresh_count "$origin"
  tmux display-message "Muted $name until $(date -r "$until" '+%a %H:%M')"
}

unmute() {
  local win=$1 select=$2 origin index session name stash_session placeholder
  IFS='|' read -r origin index session name < <(
    tmux display-message -p -t "$win" '#{@muted_from}|#{@muted_index}|#{session_name}|#{window_name}' 2>/dev/null)
  case $session in "$STASH_PREFIX"*) ;; *) return 0 ;; esac
  stash_session=$session

  # Resurrect renumbers session ids and drops options, so fall back to the stash name.
  if [ -z "$origin" ] || ! tmux has-session -t "$origin" 2>/dev/null; then
    local origin_name=${stash_session#"$STASH_PREFIX"}
    origin=$(tmux list-sessions -F '#{session_id}|#{session_name}' |
      awk -F'|' -v n="$origin_name" '$2 == n { print $1; exit }')
    if [ -z "$origin" ]; then
      origin=$(tmux new-session -d -P -F '#{session_id}' -s "$origin_name")
      placeholder=$(tmux list-windows -t "$origin" -F '#{window_id}')
      index=""
    fi
  fi
  [ -n "$origin" ] || return 1

  tmux set-option -w -t "$win" -u @muted_from
  tmux set-option -w -t "$win" -u @muted_index
  tmux set-option -w -t "$win" -u @muted_until
  if [ -z "$index" ] || ! tmux move-window -d -s "$win" -t "$origin:$index" 2>/dev/null; then
    tmux move-window -d -s "$win" -t "$origin:"
  fi
  [ -n "$placeholder" ] && tmux kill-window -t "$placeholder"

  refresh_count "$origin"
  if [ "$select" = "select" ]; then
    tmux select-window -t "$win"
  else
    notify "$origin" "Unmuted $name"
  fi
}

# Polls the wall clock because macOS sleep(1) pauses while the machine sleeps.
timer() {
  local win=$1 until=$2 now
  while now=$(date +%s) && ((now < until)); do
    sleep $((until - now < 30 ? until - now : 30))
    # Gone, unmuted or re-muted with a new deadline: another timer owns it.
    [ "$(tmux display-message -p -t "$win" '#{@muted_until}' 2>/dev/null)" = "$until" ] || return 0
  done
  expire "$win"
}

expire() {
  local until
  until=$(tmux display-message -p -t "$1" '#{@muted_until}' 2>/dev/null) || return 0
  # A re-mute moves the deadline, so a stale timer must not fire early.
  [ -n "$until" ] && (($(date +%s) < until)) && return 0
  unmute "$1"
}

sweep() {
  local win
  for win in $(tmux list-windows -a -F '#{session_name}|#{window_id}' 2>/dev/null |
    awk -F'|' -v p="$STASH_PREFIX" 'index($1, p) == 1 { print $2 }'); do
    expire "$win"
  done
}

unmute_all() {
  local stash win
  stash=$(find_stash "$1")
  [ -n "$stash" ] || return 0
  for win in $(tmux list-windows -t "$stash" -F '#{window_id}' 2>/dev/null); do
    unmute "$win"
  done
}

# Rows: "<window_id>\t<display>"; the id column is hidden by fzf.
picker_rows() {
  local stash=$1 now
  now=$(date +%s)
  tmux list-windows -t "$stash" -F '#{window_id}|#{@muted_index}|#{window_name}|#{@muted_until}' 2>/dev/null |
    while IFS='|' read -r id index name until; do
      printf '%s\t%3s: %-30s \033[2mback in %s\033[0m\n' \
        "$id" "$index" "$name" "$(human_left $((${until:-now} - now)))"
    done
}

picker() {
  local client=$1 origin stash
  origin=$(tmux display-message -p -c "$client" '#{session_id}')
  stash=$(find_stash "$origin")
  if [ -z "$stash" ]; then
    tmux display-message -c "$client" "No muted windows"
    return 0
  fi
  tmux display-popup -c "$client" -E -w 80% -h 60% "'$SELF' picker-ui '$stash' '$origin'"
}

picker_ui() {
  local stash=$1 origin=$2 out key id
  out=$(picker_rows "$stash" |
    fzf --ansi --reverse --no-sort \
      --delimiter='\t' --with-nth=2.. \
      --expect=ctrl-u \
      --style=full \
      --border-label=' Muted windows ' \
      --header='<RET>: unmute & go | <C-u>: unmute all | <ESC>: close' \
      --preview='tmux capture-pane -ep -t {1} 2>/dev/null' \
      --preview-window='right,60%,nowrap,<85(down,50%,nowrap)')
  key=$(head -1 <<<"$out")
  id=$(sed -n 2p <<<"$out" | cut -f1)
  if [ "$key" = "ctrl-u" ]; then
    unmute_all "$origin"
  elif [ -n "$id" ]; then
    unmute "$id" select
  fi
}

# Otherwise the expiry timers would recreate the killed session.
closed() {
  local name=$1 stash
  case $name in "$STASH_PREFIX"*) return 0 ;; esac
  stash=$(tmux list-sessions -F '#{session_id}|#{@muted_origin}|#{session_name}' 2>/dev/null |
    awk -F'|' -v n="$(stash_name "$name")" '$3 == n { print $1; exit }')
  # A live session may have taken the name, so only drop a stash whose origin is gone.
  [ -n "$stash" ] || return 0
  local origin
  origin=$(tmux display-message -p -t "$stash" '#{@muted_origin}')
  tmux has-session -t "$origin" 2>/dev/null || tmux kill-session -t "$stash"
}

cmd=$1
shift
case $cmd in
mute) mute "$@" ;;
unmute) unmute "$@" ;;
unmute-all) unmute_all "$@" ;;
timer) timer "$@" ;;
sweep) sweep ;;
picker) picker "$@" ;;
picker-ui) picker_ui "$@" ;;
closed) closed "$@" ;;
*)
  sed -n '3,12p' "$0" >&2
  exit 1
  ;;
esac
