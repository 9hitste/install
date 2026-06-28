# About
This script will help you install and run the 9Hits Viewer v6 without GUI on Linux to start earning points, any patches are welcome :)

![9Hits Viewer v6](/v6/v6.png)

# Requirements
## Recommended versions per distribution

| Distribution | Minimum (works) | Recommended |
| --- | --- | --- |
| **Ubuntu** | 20.04 LTS (Focal) | **22.04 LTS (Jammy)** |
| **Debian** | 11 (Bullseye) | **12 (Bookworm)** |
| **CentOS** | Stream 9 | **CentOS Stream 9** |
| **RHEL** | 9 | **9** |
| **Rocky / AlmaLinux** | 9 | **9** |
| **Fedora** | 36 | **39 or newer** |

Other distros may work but are not well-tested.

> **Note:** This installer **requires systemd and root** (run with `sudo`). systemd supervises the viewer - it auto-restarts on crash and survives reboot. System dependencies (`screen`, `Xvfb`, etc.) are installed **automatically**; pass `--skip-install-deps` to skip that (e.g. on re-runs). With `screen` present the viewer runs inside a **screen** session named `9hits` so you can attach to watch the live dashboard; without it the viewer still runs headless under systemd (follow it with `journalctl -u 9hits -f`).
> For containers or non-systemd hosts, use the Docker image instead!

# Install
Run with `sudo` (systemd + root required). System dependencies (`screen`, `Xvfb`, etc.) are installed automatically; add `--skip-install-deps` to skip them
(e.g. on re-runs where they are already present):
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- options
```

# Available options
| Option | Description |
| --- | --- |
| --install-dir | Where to download and extract the 9Hits Viewer (also holds its config + browser cache/profiles), default is `/opt/9hits` |
| --skip-install-deps | Skip installing system dependencies (Xvfb, libnss3, libgtk-3-0, screen, etc.). They are installed by default; use this on re-runs where they are already present |
| --install-vnc | Install x11vnc and start a VNC server mirroring the viewer display, requires root |
| --vnc-pw | VNC password. If omitted, a random password is generated and printed to the terminal |
| --no-vnc-pw | Run VNC with NO password (open). Only use this if you explicitly want an unauthenticated VNC |
| --vnc-port | VNC port, default `5901` (5900 is avoided as it commonly clashes with other VNC servers) |
| --default-dl | Override the default download URL for the viewer |
| --reset-interval | Periodic reset interval, e.g. `30m`, `1h`, `6h`, `24h` (bare number = seconds; minimum 60s, max ~24d). The viewer gracefully stops its sessions and exits on that interval, and systemd relaunches it. Omitted = reset on crash only |
| --create-swap | Create swap space, e.g. `--create-swap=10G`, requires root |
| --access-key | Your [9Hits access key](https://panel.9hits.com/user/profile) |
| --allow-popups | `yes` or `no`, default = `yes` |
| --allow-adult | `yes` or `no`, default = `yes` |
| --allow-crypto | `yes` or `no`, default = `yes` |
| --hide-browser | `yes` or `no`, default = `no` |
| --system-session | Create a session using the real IP of this machine |
| --ex-proxy-sessions | Number of sessions using an external proxy pool |
| --ex-proxy-url | External proxy pool URL |
| --bulk-add-proxy-list | Proxy list for bulk session creation, format: `server:port;user;pass\|server:port;user2;pass2` (`\|` separated) |
| --bulk-add-proxy-type | Proxy type for bulk add, possible values: `http`, `socks4`, `socks5`, `ssh` |
| --session-note | Note applied to all created sessions |
| --cache-path | Override the default browser cache directory |
| --cache-limit | `-1`: default, `0`: no cache, or a number of bytes to limit disk cache usage, eg: 104857600 (for 100MB = 100 * 1024 * 1024) |
| --clear-all-sessions | Remove all previously created sessions before applying new configuration |
| --hide-columns | Comma-separated columns to hide in the viewer table; every other column is forced shown (overrides the saved layout). Columns: `id`, `note`, `proxy`, `client`, `quality`, `hits`, `points` (`status` is always shown). e.g. `--hide-columns=quality,points` |

# Examples
All examples below default to creating 10G [SWAP](https://opensource.com/article/18/9/swap-space-linux-systems), recommended if your machine uses an SSD and has limited RAM. Remove `--create-swap=10G` if not needed (also remove `sudo`).

- Run 1 system session:
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- --access-key=186eaced825ab3e3468dfda97d880333 --system-session --allow-crypto=no --create-swap=10G
```

- Run 1 system session + 10 sessions using your own proxy pool:
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- --access-key=186eaced825ab3e3468dfda97d880333 --system-session --ex-proxy-sessions=10 --ex-proxy-url=http://my_pool_url/ --allow-crypto=no --session-note=http-pool --note=my-vps --hide-browser=yes --create-swap=10G
```

- Run 1 system session + 2 sessions via bulk proxy add (wrap `--bulk-add-proxy-list` value in double quotes):
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- --access-key=186eaced825ab3e3468dfda97d880333 --system-session --bulk-add-proxy-type=ssh --bulk-add-proxy-list="12.24.45.56;user;pass|my-ssh.com;admin;12345" --allow-crypto=no --session-note=my-ssh --note=my-vps --hide-browser=yes --create-swap=10G
```

- Install with VNC access (connect using [TigerVNC](https://tigervnc.org/) or any VNC client):
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- --install-vnc --vnc-pw=mysecret --access-key=186eaced825ab3e3468dfda97d880333 --system-session
```
After install, the script prints the VNC address (`<server-ip>:5901`). Connect with a VNC client and you will see the viewer running live.

# Supervision: systemd

The viewer is supervised by **systemd**, so it **auto-restarts if killed and survives
reboot**. When `screen` is installed (it is by default), systemd runs `nhviewer`
inside a `screen` session named `9hits` (no extra restart-loop script) so you can attach
to watch the live dashboard; if `screen` is absent it runs headless under systemd and you
follow it with `journalctl -u 9hits -f`. Either way systemd is the sole supervisor.
Re-running `install.sh` is safe.

## Periodic reset (`--reset-interval`)

Pass `--reset-interval=6h` (or `24h`, `30m`, …) to reset the viewer on an interval.
The reset is handled **inside the viewer**: it gracefully stops every session
(closing each browser and SSH tunnel) and exits cleanly, then systemd relaunches
a fresh instance. This is a clean self-restart, not an external `kill` - no half-written
cache or orphaned Chromium processes. Without the flag, the viewer is only restarted on
crash. The minimum interval is 60s and the maximum is ~24 days; out-of-range values are
clamped. (Requires a viewer build that supports `--reset-interval`.)

```
# Watch the live dashboard (when screen is installed)
screen -dr 9hits          # Ctrl+A then D to detach (viewer keeps running)

# Service control
systemctl status 9hits
journalctl -u 9hits -f
systemctl restart 9hits
systemctl disable --now 9hits 9hits-xvfb   # stop + don't start on boot
# if you installed VNC (--install-vnc), include it too:
systemctl disable --now 9hits 9hits-xvfb 9hits-vnc
```
