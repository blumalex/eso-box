#!/usr/bin/env bash
# eso-box: system settings for an always-on Linux box (systemd; packages via apt).
# Run once on the box, from your normal user:  sudo box/linux/setup-root.sh [--firewall]
#   --firewall   let only the tailnet in (ufw). Run it after `tailscale up` works, and not
#                from a LAN SSH connection: that connection is cut.
# Every step is safe to rerun. Reboot afterwards: sudo systemctl reboot -i
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run it with sudo: sudo $0" >&2; exit 1; }
user=${SUDO_USER:?run it with sudo from your normal user, not as root}
firewall=0
[ "${1:-}" = --firewall ] && firewall=1

if command -v apt-get >/dev/null; then
  echo "== packages"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y git tmux jq python3 curl
else
  echo "== not apt-based: install git, tmux, jq, python3 and curl yourself"
fi

echo "== keep running with the lid closed (no effect on desktops)"
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/90-eso-box-lid.conf <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

echo "== never sleep (this also overrides the desktop's automatic suspend)"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

if [ -f /etc/default/grub ]; then
  echo "== after a power cut: don't wait at the boot menu, repair the disk check by itself"
  grep -q 'fsck.repair=yes' /etc/default/grub ||
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 fsck.repair=yes"/' /etc/default/grub
  grep -q '^GRUB_RECORDFAIL_TIMEOUT=' /etc/default/grub || echo 'GRUB_RECORDFAIL_TIMEOUT=5' >> /etc/default/grub
  if command -v update-grub >/dev/null; then update-grub; else echo "   regenerate your GRUB config to apply"; fi
fi

echo "== reboot by itself after a kernel crash or a hard freeze"
echo 'kernel.panic=10' > /etc/sysctl.d/90-eso-box-panic.conf
mkdir -p /etc/systemd/system.conf.d
printf '[Manager]\nRuntimeWatchdogSec=60\n' > /etc/systemd/system.conf.d/90-eso-box-watchdog.conf
# Ubuntu blacklists hardware watchdog drivers and systemd-modules-load honors that, so systemd
# finds no watchdog. Load Intel's by name early in boot, when this machine has it.
if modinfo iTCO_wdt >/dev/null 2>&1; then
  cat > /etc/systemd/system/eso-box-watchdog.service <<'EOF'
[Unit]
Description=eso-box: load the Intel hardware watchdog for systemd's RuntimeWatchdog
DefaultDependencies=no
Before=sysinit.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/modprobe iTCO_wdt
[Install]
WantedBy=sysinit.target
EOF
  systemctl daemon-reload
  systemctl enable eso-box-watchdog.service
fi

bat=/sys/class/power_supply/BAT0
if [ -w "$bat/charge_control_end_threshold" ]; then
  echo "== battery: stop charging at 80%, start again at 75%, reapplied at every boot"
  cat > /etc/systemd/system/eso-box-battery.service <<EOF
[Unit]
Description=eso-box: battery charge thresholds 75-80%
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'echo 75 > $bat/charge_control_start_threshold; echo 80 > $bat/charge_control_end_threshold'
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now eso-box-battery.service
fi

echo "== start $user's services at boot, without anyone logging in (the Remote Control server)"
loginctl enable-linger "$user"

if [ "$firewall" = 1 ]; then
  echo "== firewall: only the tailnet gets in"
  ip link show tailscale0 >/dev/null 2>&1 || { echo "tailscale0 isn't up: run 'sudo tailscale up --ssh' first" >&2; exit 1; }
  command -v ufw >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y ufw
  ufw default deny incoming
  ufw allow in on tailscale0
  ufw --force enable
fi

echo
echo "Done. Reboot to apply: sudo systemctl reboot -i"
echo "(-i: a plain reboot is refused while a desktop and SSH sessions are logged in.)"
