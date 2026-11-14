#!/usr/bin/env bash
# eso-box: system settings for an always-on Mac (a Mac mini, for example).
# UNTESTED: written from Apple's documented pmset/systemsetup settings, not yet run on a Mac.
# Please report what works and what doesn't.
# Run once on the Mac, from your normal user:  sudo box/macos/setup-root.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run it with sudo: sudo $0" >&2; exit 1; }

echo "== never sleep (the display still turns off after 10 minutes)"
pmset -a sleep 0 disksleep 0 displaysleep 10 powernap 0
echo "== wake for network access"
pmset -a womp 1
echo "== start up by itself after a power failure"
pmset -a autorestart 1
echo "== restart by itself after a freeze"
# systemsetup can need Full Disk Access for the terminal on recent macOS.
systemsetup -setrestartfreeze on || echo "   failed: give your terminal Full Disk Access, or skip it"
echo "== macOS updates: download, but don't install by themselves (a restart ends running sessions)"
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false

cat <<'EOF'

Done. Still to do by hand, in System Settings:
- Users & Groups > Automatically log in as: your user. Needed so the Remote Control server
  (a launchd agent) starts after a power cut. macOS only offers it with FileVault off: with
  FileVault on, the Mac waits at the unlock screen after every restart. See docs/security.md.
- General > Sharing > Screen Sharing on, if you want to see the Mac's screen from elsewhere.
- SSH: either Tailscale SSH (needs the open-source tailscaled, `brew install tailscale`; the
  App Store and standalone Tailscale apps can't run an SSH server), or General > Sharing >
  Remote Login on, with SSH keys.
EOF
