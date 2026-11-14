# eso-box client for bash and zsh: Linux, macOS, WSL on Windows, Termux on Android.
# Add to ~/.bashrc or ~/.zshrc:
#   export ESO_BOX_HOST=mybox        # the box's Tailscale name (user@mybox if your user differs)
#   . ~/eso-box/client/box.sh
#
#   box          a new Claude session on the box
#   box <name>   back into that one, or a new one by that name
#   boxls        list the box's sessions
# Close the window to leave a session running. Quitting Claude (Ctrl+C) ends that session.

# shellcheck disable=SC2088  # the ~ is expanded on the box, not here
box() { ssh -t "${ESO_BOX_HOST:?set ESO_BOX_HOST to the box Tailscale name}" '~/.local/bin/eso-session' "$@"; }
# shellcheck disable=SC2088
boxls() { ssh "${ESO_BOX_HOST:?set ESO_BOX_HOST to the box Tailscale name}" '~/.local/bin/eso-session --ls'; }
