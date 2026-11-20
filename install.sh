#!/usr/bin/env bash
# eso-box installer. Run it on the box as your normal user (not root):
#   ./install.sh --dir ~/code/myproject [--no-service]
# --dir         the project folder that sessions started from the phone run in (a rerun
#               without it keeps the last one)
# --no-service  skip the always-on Remote Control server
# Installs the box tools into ~/.local/bin, the tab titles into ~/.tmux.conf, the hooks into
# ~/.claude/settings.json (with a backup), and the Remote Control server as a systemd user
# service (Linux) or a launchd agent (macOS). Safe to rerun: after a git pull, a rerun upgrades
# eso-box's own tab titles and hooks in place and keeps your settings. Update:
#   git pull && ./install.sh --no-service
# System settings (never sleep, restart after a power cut) are separate, run with sudo:
#   box/linux/setup-root.sh  or  box/macos/setup-root.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dir="" service=1
while [ $# -gt 0 ]; do
  case $1 in
    --dir) dir=${2:?--dir needs a folder}; shift 2 ;;
    --no-service) service=0; shift ;;
    -h | --help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
done
[ "$(id -u)" != 0 ] || { echo "Run it as your normal user, not root." >&2; exit 1; }
# A rerun keeps the settings of the last install.
# shellcheck source=/dev/null
[ -f ~/.config/eso-box/config ] && . ~/.config/eso-box/config
[ -n "$dir" ] || dir=${ESO_BOX_DIR:-}
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
  echo "# eso-box settings, read by eso-session, eso-rc-loop, eso-phone and eso-update-check"
  printf 'ESO_BOX_DIR=%q\n' "$dir"
  echo "# Sessions started from the phone: same-dir (all in ESO_BOX_DIR) or worktree (each in its own git worktree)"
  printf 'ESO_RC_SPAWN=%q\n' "${ESO_RC_SPAWN:-same-dir}"
  echo "# Once a day, ask GitHub whether a newer eso-box is out: on or off (see docs/security.md)"
  printf 'ESO_BOX_UPDATE_CHECK=%q\n' "${ESO_BOX_UPDATE_CHECK:-on}"
  echo "# The clone and commit this install came from, for eso-update-check"
  printf 'ESO_BOX_REPO=%q\n' "$here"
  printf 'ESO_BOX_VERSION=%q\n' "$(git -C "$here" rev-parse HEAD 2>/dev/null || true)"
} > ~/.config/eso-box/config
rm -f ~/.cache/eso-box/update-available

# Each file gets the first backup when eso-box first changes it, and one more before each upgrade.
# The files are written in place (cat >), so a symlinked dotfile stays a symlink.
echo "== tab titles: ~/.tmux.conf"
tmux_conf=~/.tmux.conf
[ -f "$tmux_conf" ] && src=$tmux_conf || src=/dev/null
# eso-box's block, in every version: its marker line, then only comments and `set -g` lines,
# ending with set-titles-string. Replaced where it is; a block edited past that is left alone.
block=$(awk '
  /^# eso-box: tab titles$/ { m = 1; next }
  m && /^set -g set-titles-string / { r = "ok"; exit }
  m && !/^(#|set -g (set-titles|status-interval) )/ { r = "edited"; exit }
  END { print (m ? (r ? r : "ok") : "none") }
' "$src")
case $block in
  edited) echo "   eso-box's block was edited by hand: left alone (the current one: config/tmux.conf)" ;;
  *)
    new=$(mktemp)
    awk -v f="$here/config/tmux.conf" '
      !done && /^# eso-box: tab titles$/ { b = 0; while ((getline l < f) > 0) print l; skip = done = 1; next }
      skip { if (/^set -g set-titles-string /) skip = 0; next }
      /^$/ { b++; next }
      { for (; b > 0; b--) print ""; print }
      END { for (; b > 0; b--) print ""; if (!done) while ((getline l < f) > 0) print l }
    ' "$src" > "$new"
    if cmp -s "$new" "$src"; then
      echo "   already current"
    else
      if [ "$block" = ok ]; then bak=$tmux_conf.pre-eso-box-upgrade; else bak=$tmux_conf.pre-eso-box; fi
      [ -f "$tmux_conf" ] && cp "$tmux_conf" "$bak" && echo "   backup: $bak"
      cat "$new" > "$tmux_conf"
      tmux source-file "$tmux_conf" 2>/dev/null || true
    fi
    rm -f "$new"
    ;;
esac

echo "== hooks and Remote Control for every session: ~/.claude/settings.json"
settings=~/.claude/settings.json
mkdir -p ~/.claude
[ -f "$settings" ] || echo '{}' > "$settings"
if grep -qF 'eso-rc-title' "$settings"; then first=false; else first=true; fi
# Takes out every hook command of any eso-box version, then adds the current ones. Yours stay.
new=$(mktemp)
jq --slurpfile add "$here/config/hooks.json" --argjson first "$first" '
  def ours: test("eso-(rc-title|phone-sync|tab-stop|update-check)|@claude_busy");
  (if $first then .remoteControlAtStartup = true else . end)
  | .hooks = ((.hooks // {})
      | map_values(map(.hooks = [(.hooks // [])[] | select((.command // "") | ours | not)])
          | map(select(.hooks | length > 0)))
      | with_entries(select(.value | length > 0)))
  | reduce ($add[0].hooks | to_entries[]) as $e (.; .hooks[$e.key] = ((.hooks[$e.key] // []) + $e.value))
' "$settings" > "$new"
if cmp -s <(jq -S . "$settings") <(jq -S . "$new"); then
  echo "   already current"
else
  if $first; then bak=$settings.pre-eso-box; else bak=$settings.pre-eso-box-upgrade; fi
  cp "$settings" "$bak"
  cat "$new" > "$settings"
  echo "   backup: $bak"
fi
rm -f "$new"

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
