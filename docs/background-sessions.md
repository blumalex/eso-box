# Background sessions: an alternative to tmux

Claude Code has its own way to keep sessions running without a terminal: background sessions,
managed in **agent view** (research preview; [docs](https://code.claude.com/docs/en/agent-view)).
A supervisor process on the box runs each session, and any terminal can attach to it.

- `claude --bg "task"` starts one; inside any session, `←` on an empty prompt (or `/bg`) moves
  that session to the background.
- `claude attach <id or part of its name>` opens one in this terminal; `←` or `Ctrl+Z` leaves it
  running. From a laptop: `ssh -t mybox claude attach <name>`.
- `claude agents` lists them by state (needs input, working, done); peek and reply without
  attaching. `claude logs`, `stop`, `rm`, `respawn` manage them.

## Compared with eso-box's tmux sessions

Checked on a Linux box with Claude Code 2.1.325: a background session connected to Remote
Control by itself (so it shows on the phone), ran the hooks, got `DISPLAY` and `PATH` from the
shell that started it, and `claude attach` from a fresh shell opened it with its conversation.

| | tmux (`box`) | Background sessions |
|---|---|---|
| Survives the laptop disconnecting | yes | yes |
| Phone | Remote Control | Remote Control |
| Session crashes | gone | the supervisor restarts it |
| Box reboots | gone; `eso-snapshot` before a reboot brings back the open ones, else `/resume` by hand | listed as failed; attaching or replying restarts it from its saved conversation |
| Claude Code updates | old sessions stay on the old version | idle sessions move by themselves; `claude respawn --all` |
| Overview | `boxls` (names) | `claude agents` (state per session) |
| Scrolling | normal terminal scrollback | fullscreen only (`PgUp`, `Ctrl+O`) |
| ◐/✳ tab glyph | yes | no: attached sessions don't report status to the terminal |
| File edits | where you are | `--bg` sessions move into their own `.claude/worktrees/` before editing |

## Why eso-box still defaults to tmux

- Agent view is a research preview; its interface may change.
- The supervisor runs on demand. In 2.1.325, `claude daemon --help` says "Service install is
  disabled in this version — the daemon runs on demand and exits when the last client
  disconnects", so nothing starts it at boot. (The Remote Control server, which lets the phone
  start sessions, still needs eso-box's service either way.)
- Not yet checked here: a background session left unattached overnight.
- If your repo has its own worktree setup, `--bg` sessions' automatic worktrees skip it, unless
  you add a `WorktreeCreate` hook. Sessions moved with `←` keep editing where they were.
- Phone-started sessions still can't be attached; they need `eso-phone` + `/resume` in both
  setups.
