# eso-box client for bash and zsh: Linux, macOS, WSL on Windows, Termux on Android.
# Add to ~/.bashrc or ~/.zshrc:
#   export ESO_BOX_HOST=mybox        # the box's Tailscale name (user@mybox if your user differs)
#   . ~/eso-box/client/box.sh
#
#   box          a new Claude session on the box
#   box <name>   back into that one, or a new one by that name
#   boxls        list the box's sessions
# Close the window to leave a session running. Quitting Claude (Ctrl+C) ends that session.

box() {
  # shellcheck disable=SC2088  # the ~ is expanded on the box, not here
  ssh -t "${ESO_BOX_HOST:?set ESO_BOX_HOST to the box Tailscale name}" '~/.local/bin/eso-session' "$@"
  local rc=$? tty
  # 255: the connection broke (the laptop slept, the network changed) or never opened. tmux on
  # the box never got to switch off the mouse tracking Claude Code's fullscreen mode turns on, so
  # each mouse move would type its coordinates here. Switch it and paste mode off, show the
  # cursor, throw away what the mouse already typed, and say what happened.
  if [ $rc = 255 ]; then
    printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l\033[?2004l\033[?25h'
    tty=$(stty -g); stty -echo -icanon min 0 time 1
    while [ -n "$(dd bs=4096 count=1 2>/dev/null)" ]; do :; done
    stty "$tty"
    echo "box: no connection to $ESO_BOX_HOST (the laptop slept or the network changed)."
    echo "     Sessions keep running on the box: box <n> reattaches, boxls lists them."
  fi
  return $rc
}
# shellcheck disable=SC2088
boxls() { ssh "${ESO_BOX_HOST:?set ESO_BOX_HOST to the box Tailscale name}" '~/.local/bin/eso-session --ls'; }
