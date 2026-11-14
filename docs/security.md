# Security tradeoffs

A box that boots unattended and runs Claude with your credentials is a juicy target if stolen.
These are the choices eso-box's setup makes, and what to do if the box goes missing.

## The choices

- **No disk encryption (or FileVault off).** A passphrase prompt would block unattended boot
  after every power cut. Tradeoff: a stolen disk is readable, including `.env` files, tokens and
  Claude's transcripts. If that's unacceptable, encrypt and accept unlocking by hand after
  power cuts.
- **Automatic login,** so a desktop (and its keyring, browser and display) exists after every
  reboot. Anyone at the box's keyboard gets a desktop.
- **Blank login keyring password** (Linux, if you use automatic login): `gh`'s token and the
  remote desktop login sit unencrypted on disk.
- **Network: Tailscale only.** No ports opened on the router; with `--firewall`, the box accepts
  connections only from the tailnet. Tailscale SSH in check mode re-asks for a Tailscale sign-in
  about every 12 hours, which is what stops a stolen laptop from getting a shell on the box.
- **Remote Control** goes through Anthropic and needs your claude.ai sign-in on each device.

## If the box is stolen

Revoke, roughly in this order:

1. **Tailscale:** remove the box in the admin console (cuts remote access to everything else).
2. **GitHub:** revoke the GitHub CLI authorization (github.com/settings/applications) and any
   SSH or deploy keys the box had.
3. **Claude:** sign out the box's sessions from your claude.ai account settings.
4. **Every other CLI the box was logged in to** (cloud providers, deploy tools, issue
   trackers): revoke its sessions or tokens, and remove its SSH keys from any server.
5. **Rotate the secrets** in the box's `.env` files and API keys.
6. **Websites logged in** in the box's browser profiles: sign out all sessions or change the
   passwords.

Keep this list current for your own box: write down what you logged it in to as you go.
