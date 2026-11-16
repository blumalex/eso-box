# Using eso-box

## Started on the laptop: switch freely

1. Laptop: `box` starts a session (say tmux numbers it `3`). Work as usual.
2. Walk away: close the terminal window. The session keeps running on the box.
3. Phone: open the Claude app. The session is in the list, named after Claude's title for it
   (eso-rc-title). Read along, answer permission prompts, type.
4. Back at the laptop: `box 3`. Same session, including what you did from the phone.

Laptop and phone can both drive the session at any point, back and forth, with no handoff.

## Started on the phone: one move, then free

A session you start in the Claude app or at claude.ai/code runs on the box (through the Remote
Control server that `install.sh` sets up), in the folder you passed as `--dir`. It isn't in tmux,
so `box 3` can't reach it. To bring it to a terminal:

1. Let Claude finish its turn on the phone.
2. Laptop: `box`, then `/resume`. Phone-started sessions are listed as `☏ · <the phone's
   title>` (eso-phone-sync; Claude Code would otherwise hide them). Pick yours. A session you
   start on the phone shows up at the next session start (`box`, or `/clear` in an open one).
   Or type `! eso-phone`: it lists them newest first, each with its first message and a
   `/resume <id>` line to paste.
3. From now on, type only in the terminal session. On the phone, follow the **terminal
   session's own entry** (a new one, named after the first message you send after the move), not
   the original phone entry.

Why step 3: the resume doesn't fork. The terminal process writes into the same conversation file
while the phone's process keeps running, and that process only knows claude.ai's copy of the
conversation. Typing in both would interleave two diverging conversations. The phone's view of
the moved session starts at the move; the earlier part stays readable in the original entry.

The terminal tab shows the same `☏ · <title>`, and keeps it on later resumes.

After the move, the session switches freely between laptop and phone as above.

## Session names on the phone

Each session's Remote Control entry starts as `<hostname>-<adjective>-<animal>` and is renamed
from the first message of a new conversation. eso-rc-title renames it to Claude's own title on
every message, and leaves a name you set with `/rename` alone.

`/resume` inside a running session keeps that session's phone entry, and Claude Code stops sending
the resumed conversation's details to it, so the name sticks. `claude --resume` (the picker, at
start) reattaches the conversation's own entry with its name instead.

## Where things run

| Thing | Where | How to reach it |
|---|---|---|
| Sessions you start with `box` | tmux on the box (default server) | `box <n>`, `boxls`, the phone |
| Sessions you start on the phone | children of the Remote Control server | the phone, claude.ai/code, or `eso-phone` + `/resume` |
| The Remote Control server | `tmux -L eso-rc`, started by the eso-rc service | `tmux -L eso-rc attach -t rc` |

Stop the server (and the phone-started sessions it runs): `systemctl --user stop eso-rc` on
Linux, `launchctl bootout gui/$(id -u)/com.eso-box.rc` on macOS.

## What happens when

| Event | Result |
|---|---|
| The internet drops, or the router restarts | Claude and tmux keep running; Tailscale reconnects by itself. Reattach with `box <n>`. If an API call failed mid-outage, tell Claude to continue |
| The laptop sleeps or loses its connection | The SSH connection drops; the session keeps running detached and the phone still reaches it. `box <n>` reattaches (`boxls` for the numbers); plain `box` starts a new one |
| Short power cut (laptop box) | The battery carries it: same as an internet drop |
| Power off long enough to shut down | Boots by itself when power returns (BIOS "power on with AC attach", or `pmset autorestart` on a Mac). tmux sessions and running commands are lost; the Remote Control server comes back by itself. Continue a conversation with `box`, then `claude --continue` or `/resume` |
| Kernel crash or hard freeze | Reboots by itself within about a minute, then as above |
| No network for over ~10 minutes | The Remote Control server exits and eso-rc-loop restarts it 30 s later. Interactive sessions reconnect by themselves |

## Other ways in

- **claude.ai/code in a browser** reaches every session on the box, from any computer, with
  nothing installed. It lacks terminal-only commands (`/resume`, `/plugin`, `!` shell commands).
- **Remote desktop**, to see windows Claude opens on the box (a browser, for example): GNOME
  Settings > System > Remote Desktop > Desktop Sharing on, with Remote Control on, then RDP to the
  box's Tailscale name. On a Mac: Screen Sharing (VNC).
