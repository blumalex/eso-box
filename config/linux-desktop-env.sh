# eso-box, optional, Linux desktops only: give shells started over SSH or in tmux the desktop
# session's display, so windows that Claude opens (a browser, for example) appear on the box's
# screen and over remote desktop. Read from the systemd user environment rather than hardcoded:
# XAUTHORITY's file name changes every boot. Source it at the end of ~/.bashrc.
if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v systemctl >/dev/null 2>&1; then
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  eval "$(systemctl --user show-environment 2>/dev/null | grep -E '^(DISPLAY|WAYLAND_DISPLAY|XAUTHORITY)=' | sed 's/^/export /')"
fi
