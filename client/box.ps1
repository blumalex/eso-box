# eso-box client for Windows PowerShell. Windows 10 and 11 include the OpenSSH client.
# Add to your PowerShell profile (open it with: notepad $PROFILE):
#   $env:ESO_BOX_HOST = 'mybox'      # the box's Tailscale name (user@mybox if your user differs)
#   . "$HOME\eso-box\client\box.ps1"
#
#   box          a new Claude session on the box
#   box <name>   back into that one, or a new one by that name
#   boxls        list the box's sessions
# Close the window to leave a session running. Quitting Claude (Ctrl+C) ends that session.

function box {
    param([string]$Name)
    if (-not $env:ESO_BOX_HOST) { throw 'Set $env:ESO_BOX_HOST to the box Tailscale name' }
    ssh -t $env:ESO_BOX_HOST "~/.local/bin/eso-session $Name"
}

function boxls {
    if (-not $env:ESO_BOX_HOST) { throw 'Set $env:ESO_BOX_HOST to the box Tailscale name' }
    ssh $env:ESO_BOX_HOST '~/.local/bin/eso-session --ls'
}
