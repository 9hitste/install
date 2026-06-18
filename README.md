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

> **Note:** Root/sudo is NOT required for the basic installation. It is only needed when using `--install-deps`, `--install-vnc`, or `--create-swap`.
> The script automatically runs the viewer inside a **screen** session named `9hits`, so it keeps running after you disconnect. Use `--install-deps` to have `screen` installed automatically.

# Install
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | bash -s -- options
```

To install system dependencies first (requires sudo):
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- --install-deps options
```

# Available options
| Option | Description |
| --- | --- |
| --install-dir | Where to download and extract the 9Hits Viewer, default is `$HOME/9hits` |
| --install-deps | Install required system dependencies (Xvfb, libnss3, libgtk-3-0, etc.), requires root |
| --install-vnc | Install x11vnc and start a VNC server mirroring the viewer display, requires root |
| --vnc-pw | VNC password (recommended). If omitted, VNC will be open with no authentication |
| --vnc-port | VNC port, default `5901` (5900 is avoided as it commonly clashes with other VNC servers) |
| --default-dl | Override the default download URL for the viewer |
| --create-swap | Create swap space, e.g. `--create-swap=10G`, requires root |
| --access-key | Your [9Hits access key](https://panel.9hits.com/user/profile) |
| --allow-popups | `yes` or `no`, default = `yes` |
| --allow-adult | `yes` or `no`, default = `yes` |
| --allow-crypto | `yes` or `no`, default = `yes` |
| --hide-browser | `yes` or `no`, default = `yes` |
| --system-session | Create a session using the real IP of this machine |
| --ex-proxy-sessions | Number of sessions using an external proxy pool |
| --ex-proxy-url | External proxy pool URL |
| --bulk-add-proxy-list | Proxy list for bulk session creation, format: `server:port;user;pass\|server:port;user2;pass2` (`\|` separated) |
| --bulk-add-proxy-type | Proxy type for bulk add, possible values: `http`, `socks4`, `socks5`, `ssh` |
| --session-note | Note applied to all created sessions |
| --cache-path | Override the default browser cache directory |
| --cache-limit | `-1`: default, `0`: no cache, or a number of bytes to limit disk cache usage, eg: 104857600 (for 100MB = 100 * 1024 * 1024) |
| --clear-all-sessions | Remove all previously created sessions before applying new configuration |

# Examples
All examples below default to creating 10G [SWAP](https://opensource.com/article/18/9/swap-space-linux-systems), recommended if your machine uses an SSD and has limited RAM. Remove `--create-swap=10G` if not needed (also remove `sudo`).

- Run 1 system session:
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- --install-deps --access-key=186eaced825ab3e3468dfda97d880333 --system-session --allow-crypto=no --create-swap=10G
```

- Run 1 system session + 10 sessions using your own proxy pool:
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- --install-deps --access-key=186eaced825ab3e3468dfda97d880333 --system-session --ex-proxy-sessions=10 --ex-proxy-url=http://my_pool_url/ --allow-crypto=no --session-note=http-pool --note=my-vps --hide-browser=yes --create-swap=10G
```

- Run 1 system session + 2 sessions via bulk proxy add (wrap `--bulk-add-proxy-list` value in double quotes):
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- --install-deps --access-key=186eaced825ab3e3468dfda97d880333 --system-session --bulk-add-proxy-type=ssh --bulk-add-proxy-list="12.24.45.56;user;pass|my-ssh.com;admin;12345" --allow-crypto=no --session-note=my-ssh --note=my-vps --hide-browser=yes --create-swap=10G
```

- Install with VNC access (connect using [TigerVNC](https://tigervnc.org/) or any VNC client):
```
curl -sSLk https://9hitste.github.io/install/v6/install.sh | sudo bash -s -- --install-deps --install-vnc --vnc-pw=mysecret --access-key=186eaced825ab3e3468dfda97d880333 --system-session
```
After install, the script prints the VNC address (`<server-ip>:5901`). Connect with a VNC client and you will see the viewer running live.

# Managing the screen session
The script automatically starts the viewer inside a detached `screen` session named `9hits`. After install completes you can:

```
# Attach to view logs / status
screen -r 9hits

# Detach again (from inside screen)
Ctrl+A then D

# Stop the viewer
screen -S 9hits -X quit
```
