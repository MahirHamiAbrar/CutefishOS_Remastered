# The user

- GitHub: MahirHamiAbrar. Works on a Linux laptop (Ubuntu with kernel 7.0, VS Code with the Claude Code extension, Docker Desktop, VirtualBox 7.2, a Modal account).
- Located in Bangladesh (the installer's geoip picked Asia/Dhaka and bn_BD formats). Test installs used English UI + Bengali formats, which is also a realistic setup for the user.
- Technical; delegates long autonomous runs and checks in with short messages ("continue").

## Standing rules they gave
- **Stay inside the workspace folder** (`/home/mhabrar/Projects/MyProjects/CutefishOS_Remastered`). Don't use other folders. VirtualBox's own registry (`~/.config/VirtualBox`) is the one accepted exception.
- **"Do not assume, if you have any questions just ask."** Ask about choices that are theirs: security/behaviour trade-offs, anything irreversible, anything touching the host outside the repo. Don't ask about things you can check yourself.
- **Modal: use a Function, not a Sandbox.** Profile `mhabrarmts2`; credentials in `~/.modal.toml`.
- **Commit and push frequently.**
- **Document everything, including setbacks,** in `docs/`.
- They wanted a watchdog to auto-continue after unexpected stops, turned off when the work is done. Session 3 made one as a cron job and deleted it at the end. Don't leave background jobs running.
- When they ask for a handoff, give (1) a summary of what was done and what's left, and (2) a ready-to-paste prompt for the next agent.

## How they react
- They interrupt or reject tool calls they don't want (e.g. an early Docker restart before they had agreed, long waits). Treat a rejection as "stop and wait for instructions".
- They accept a recommended option when the trade-off is explained (e.g. "Allow installer (Recommended)").
