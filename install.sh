#!/usr/bin/env bash
# eso-box installer. Run it on the box as your normal user (not root):
#   ./install.sh --dir ~/code/myproject [--no-service]
# --dir         the project folder that sessions started from the phone run in
# --no-service  skip the always-on Remote Control server
# Installs the box tools into ~/.local/bin, the tab titles into ~/.tmux.conf, the hooks into
# ~/.claude/settings.json (with a backup), and the Remote Control server as a systemd user
# service (Linux) or a launchd agent (macOS). Safe to rerun.
# System settings (never sleep, restart after a power cut) are separate, run with sudo:
#   box/linux/setup-root.sh  or  box/macos/setup-root.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dir="" service=1
while [ $# -gt 0 ]; do
  case $1 in
    --dir) dir=${2:?--dir needs a folder}; shift 2 ;;
    --no-service) service=0; shift ;;
    -h | --help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
done
[ "$(id -u)" != 0 ] || { echo "Run it as your normal user, not root." >&2; exit 1; }
[ -n "$dir" ] || { echo "Pass --dir <the project folder Claude works in> (see --help)" >&2; exit 2; }
dir=$(cd "$dir" && pwd -P)
os=$(uname -s)

missing=""
for c in git tmux jq python3 claude; do command -v "$c" >/dev/null || missing="$missing $c"; done
if [ -n "$missing" ]; then
  echo "Missing:$missing"
  case $os in
    Linux) echo "  sudo apt install -y git tmux jq python3   (or run box/linux/setup-root.sh)" ;;
    Darwin) echo "  brew install tmux jq   (git and python3 come with: xcode-select --install)" ;;
  esac
  case $missing in *claude*) echo "  Claude Code: https://code.claude.com/docs/en/setup" ;; esac
  exit 1
fi

echo "== tools into ~/.local/bin"
mkdir -p ~/.local/bin
for f in "$here"/bin/eso-*; do install -m 755 "$f" ~/.local/bin/; done
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "   add ~/.local/bin to PATH in your shell profile" ;; esac

echo "== config: ~/.config/eso-box/config"
mkdir -p ~/.config/eso-box
{
  echo "# eso-box settings, read by eso-session, eso-rc-loop and eso-phone"
  printf 'ESO_BOX_DIR=%q\n' "$dir"
  echo "# Sessions started from the phone: same-dir (all in ESO_BOX_DIR) or worktree (each in its own git worktree)"
  echo "ESO_RC_SPAWN=same-dir"
} > ~/.config/eso-box/config

echo "== tab titles: ~/.tmux.conf"
if grep -qF '# eso-box: tab titles' ~/.tmux.conf 2>/dev/null; then
  echo "   already there"
else
  [ -f ~/.tmux.conf ] && cp ~/.tmux.conf ~/.tmux.conf.pre-eso-box
  cat "$here/config/tmux.conf" >> ~/.tmux.conf
  tmux source-file ~/.tmux.conf 2>/dev/null || true
fi

echo "== hooks and Remote Control for every session: ~/.claude/settings.json"
settings=~/.claude/settings.json
mkdir -p ~/.claude
[ -f "$settings" ] || echo '{}' > "$settings"
if grep -qF 'eso-rc-title' "$settings"; then
  echo "   already there"
else
  cp "$settings" "$settings.pre-eso-box"
  jq --slurpfile add "$here/config/hooks.json" '
    .remoteControlAtStartup = true
    | reduce ($add[0].hooks | to_entries[]) as $e (.; .hooks[$e.key] = ((.hooks[$e.key] // []) + $e.value))
  ' "$settings.pre-eso-box" > "$settings"
  echo "   backup: $settings.pre-eso-box"
fi

if [ "$os" = Linux ] && { [ -S "/run/user/$(id -u)/wayland-0" ] || [ -S /tmp/.X11-unix/X0 ]; }; then
  install -m 644 "$here/config/linux-desktop-env.sh" ~/.config/eso-box/desktop-env.sh
  grep -qF 'eso-box/desktop-env.sh' ~/.bashrc 2>/dev/null ||
    echo "   optional, so windows Claude opens show on this desktop: add to ~/.bashrc:  . ~/.config/eso-box/desktop-env.sh"
fi

if [ "$service" = 1 ]; then
  # The server can't answer the workspace trust question in the background: it would wait forever.
  if ! jq -e --arg d "$dir" '.projects[$d].hasTrustDialogAccepted == true' ~/.claude.json >/dev/null 2>&1; then
    echo "   note: run 'claude' once in $dir and accept the trust question, or the server waits on it"
  fi
  tmux_bin=$(command -v tmux)
  login_shell=${SHELL:-/bin/bash}
  case $os in
    Linux)
      echo "== Remote Control server: systemd user service eso-rc"
      unit=~/.config/systemd/user/eso-rc.service
      mkdir -p "$(dirname "$unit")"
      cat > "$unit" <<EOF
[Unit]
Description=eso-box: Claude Code Remote Control server for $dir

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$tmux_bin -L eso-rc new-session -d -s rc -c "$dir" "$login_shell -lic 'exec %h/.local/bin/eso-rc-loop'"
ExecStop=$tmux_bin -L eso-rc kill-server

[Install]
WantedBy=default.target
EOF
      systemctl --user daemon-reload
      systemctl --user enable eso-rc.service
      systemctl --user restart eso-rc.service
      [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" = yes ] ||
        echo "   note: it starts at boot only after you log in; box/linux/setup-root.sh fixes that (enable-linger)"
      ;;
    Darwin)
      echo "== Remote Control server: launchd agent com.eso-box.rc"
      plist=~/Library/LaunchAgents/com.eso-box.rc.plist
      mkdir -p ~/Library/LaunchAgents
      cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.eso-box.rc</string>
  <key>ProgramArguments</key>
  <array>
    <string>$tmux_bin</string><string>-L</string><string>eso-rc</string>
    <string>new-session</string><string>-d</string><string>-s</string><string>rc</string>
    <string>-c</string><string>$dir</string>
    <string>$login_shell -lic 'exec ~/.local/bin/eso-rc-loop'</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>AbandonProcessGroup</key><true/>
</dict>
</plist>
EOF
      "$tmux_bin" -L eso-rc kill-server 2>/dev/null || true
      launchctl bootout "gui/$(id -u)/com.eso-box.rc" 2>/dev/null || true
      launchctl bootstrap "gui/$(id -u)" "$plist"
      ;;
  esac
  echo "   watch it: tmux -L eso-rc attach -t rc   (detach: Ctrl+b d)"
fi

name=$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | cut -d. -f1) || true
host=${name:-"<this box's Tailscale name>"}
cat <<EOF

Done. On each laptop or desktop (see README, "Set up each device"):
  bash/zsh:    export ESO_BOX_HOST=$host; . <eso-box>/client/box.sh
  PowerShell:  \$env:ESO_BOX_HOST = '$host'; . <eso-box>\\client\\box.ps1
Then: box (new session), box <name> (back into one), boxls (list them).
Phone: the Claude app shows every session on this box; sessions you start there run in $dir.
EOF
