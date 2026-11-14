# Gotchas

What we ran into running a box, and how eso-box handles each one.

## Claude Code and Remote Control

- **The Remote Control server gives up after ~10 minutes without network** and exits
  (interactive sessions keep retrying). eso-rc-loop restarts it.
- **One server per folder.** Starting `claude remote-control` by hand in the same folder while
  the service runs is refused ("already served by a terminal `claude remote-control`").
- **The server waits forever on the workspace trust question** if the folder was never trusted.
  Run `claude` once in the folder first; `install.sh` warns when it looks untrusted.
- **`remoteControlAtStartup` applies to sessions started after it is set.** A session already
  running needs `/remote-control` (`/rc`).
- **Phone-started sessions are hidden from `/resume`'s picker** (their transcripts say entrypoint
  `sdk-cli`, or nothing, and their IDs are UUID version 5). Resuming by ID works: `eso-phone`.
- **Under tmux, Claude Code doesn't animate its terminal title**, so tmux draws the ◐/✳ glyph
  from a hook flag plus pane activity. Esc skips the `Stop` hook, so the 3-second activity check
  is what turns an interrupted tab back to ✳. A permission prompt waiting for you also shows ✳.
- **`←` on an empty prompt moves the session to Claude Code's background service** (agent view)
  and out of tmux. Turn that off with `leftArrowOpensAgents` in `/config` if it surprises you. See
  [background-sessions.md](background-sessions.md).
- **PATH over SSH:** `ssh box <command>` skips your login profile, so `claude`, Homebrew and nvm
  can be missing. eso-session reruns itself under your login shell, and runs Claude in an
  interactive login shell.

## Tailscale

- **Tailscale SSH's default rule is "check" mode:** about once every 12 hours the first SSH
  asks you to sign in to Tailscale in a browser. A longer period needs a paid plan. Changing the
  action to `accept` drops the check, which is what stops a stolen, still-logged-in laptop from
  getting a shell on the box.
- **Disable key expiry** for the box in the admin console, or it drops off after 180 days.
- **The phone doesn't need Tailscale for the Claude app:** Remote Control goes through
  Anthropic. It needs Tailscale only for SSH, remote desktop, or dev servers on the box.

## Dev servers on the box, reached from the phone

- **iOS apps with App Transport Security block plain `http` to the 100.x Tailscale address**
  before connecting ("failed to connect", nothing reaches the box), but allow unqualified names
  and private LAN addresses. Use the box's MagicDNS short name (`http://mybox:8081`), not the
  IP. Safari reaching the IP proves nothing: the rule applies inside apps.
- **Expo's dev-client manifest follows the Host header** the phone dialed, so one Metro server
  serves both Tailscale and the LAN, as long as nothing pins `REACT_NATIVE_PACKAGER_HOSTNAME`.
  Metro's own QR code carries the LAN address, which a tailnet-only firewall blocks.

## Linux box

- **Ubuntu blacklists hardware watchdog drivers,** and systemd-modules-load honors the
  blacklist, so `RuntimeWatchdogSec` alone finds no device. `setup-root.sh` loads Intel's
  `iTCO_wdt` with a small service early in boot. Recent Ubuntu builds the initrd with dracut, so
  `/etc/initramfs-tools/modules` is ignored.
- **`sudo reboot` is refused while a desktop and SSH sessions are logged in.** Use
  `sudo systemctl reboot -i`.
- **With automatic login, the GNOME login keyring stays locked after a reboot.** `gh` (its token
  lives there) then fails, so does `git push` over HTTPS, and the remote desktop login (also kept
  there) disappears. Fix: set the login keyring's password to blank in Passwords and Keys
  (`seahorse`). Tradeoff in [security.md](security.md).
- **Windows Claude opens need the desktop's display.** Shells started over SSH or in tmux lack
  `DISPLAY` / `WAYLAND_DISPLAY` / `XAUTHORITY`; source `~/.config/eso-box/desktop-env.sh` from
  `~/.bashrc` (install.sh offers it on desktops). XAUTHORITY's file name changes every boot, so
  it's read from systemd rather than hardcoded.
- **Chrome profiles copied from another Linux machine keep their logins** when their cookies are
  `v10` (Chrome's fixed Linux key). Profiles from macOS or Windows Chrome don't: those encrypt
  cookies with an OS keychain key.
- **Updates:** Ubuntu installs security updates by itself but doesn't reboot (a reboot ends tmux
  sessions). Check `/var/run/reboot-required` now and then, and reboot when it's convenient.
- **Lid closed:** logind doesn't log lid events when told to ignore them; heat is the real
  caveat, so leave the vents clear.

## macOS box

Untested; these are the things to check first.

- **Keychain over SSH.** On macOS, Claude Code and `gh` keep their logins in the Keychain, which
  SSH sessions often can't read: Claude then asks you to sign in again, and pushes fail. A likely
  fix: start the tmux server from a launchd agent in the logged-in session (as eso-rc does), so
  sessions it runs inherit the Keychain access.
- **FileVault and automatic login don't mix.** With FileVault on, macOS disables automatic login
  and waits at the unlock screen after a power cut, so nothing starts until someone types the
  password.
- **Tailscale SSH needs the open-source `tailscaled`** (`brew install tailscale`); the App Store and
  standalone apps can't act as an SSH server. Otherwise use Remote Login with SSH keys.
- **The built-in firewall works per app,** so there is no simple "only the tailnet gets in"
  rule like ufw's. The options are `pf` rules or relying on the router.
- **Privacy prompts** (Files and Folders, Local Network, Automation) appear on a screen nobody
  watches. Keep projects outside `~/Documents` and `~/Desktop`, and grant prompts once over
  Screen Sharing.
- **A Mac mini has no battery:** a short power cut turns it off. A small UPS fixes that.
