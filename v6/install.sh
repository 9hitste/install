#!/bin/bash
# 9Hits Viewer v6 - Linux installer & auto-restart runner
# Usage: bash install.sh --access-key=<32hex> [options]

DEFAULT_DOWNLOAD="https://dl.9hits.com/9hitsv6-linux64.tar.bz2"

# --- Defaults ---
INSTALL_DIR="$HOME/9hits"
RESTART_DELAY=5
DO_INSTALL_DEPS=0
DO_INSTALL_VNC=0
VNC_PW=""
VNC_PORT=5901   # 5901 by default to avoid clashing with VNC servers commonly on 5900
XVFB_RESOLUTION=""   # empty or "auto" -> pick based on CPU/RAM (min 1920x1080x24)
CREATE_SWAP=""
XVFB_DISPLAY=":99"
SCREEN_SESSION="9hits"

# App args forwarded to nhviewer (--exit-on-init / --auto-start are managed by this script)
APP_ARGS=()

# --------------------------------------------------------------------------
# Arg parsing
# --------------------------------------------------------------------------
parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --install-dir=*)   INSTALL_DIR="${arg#*=}" ;;
      --install-deps)    DO_INSTALL_DEPS=1 ;;
      --install-vnc)     DO_INSTALL_VNC=1 ;;
      --vnc-pw=*)        VNC_PW="${arg#*=}" ;;
      --vnc-port=*)      VNC_PORT="${arg#*=}" ;;
      --resolution=*)    XVFB_RESOLUTION="${arg#*=}" ;;
      --create-swap=*)   CREATE_SWAP="${arg#*=}" ;;
      --restart-delay=*) RESTART_DELAY="${arg#*=}" ;;
      --default-dl=*)    DEFAULT_DOWNLOAD="${arg#*=}" ;;
      # Script controls these - strip from forwarded args
      --exit-on-init|--auto-start) ;;
      # Everything else goes straight to nhviewer
      *) APP_ARGS+=("$arg") ;;
    esac
  done
}

# --------------------------------------------------------------------------
# System requirements check (Chrome 146 minimums)
# --------------------------------------------------------------------------
check_system() {
  # Architecture
  local arch
  arch=$(uname -m)
  if [ "$arch" != "x86_64" ]; then
    echo "ERROR: Unsupported architecture '$arch'. Only x86_64 is supported." >&2
    exit 1
  fi

  # OS version
  if [ ! -f /etc/os-release ]; then
    echo "ERROR: Cannot detect OS version (/etc/os-release not found)." >&2
    exit 1
  fi

  local dist version_id major minor ok=0
  dist=$(awk -F= '$1=="ID"{gsub("\"",""); print tolower($2)}' /etc/os-release)
  version_id=$(awk -F= '$1=="VERSION_ID"{gsub("\"",""); print $2}' /etc/os-release)
  major=$(echo "$version_id" | cut -d. -f1)
  minor=$(echo "$version_id" | cut -d. -f2)
  minor=${minor:-0}

  # Minimums below track the glibc >= 2.31 requirement of Chromium 146.
  case "$dist" in
    ubuntu)
      # 20.04 minimum (major > 20, or major == 20 and minor >= 4)
      { [ "$major" -gt 20 ] || { [ "$major" -eq 20 ] && [ "$minor" -ge 4 ]; }; } && ok=1
      local min_ver="20.04"
      ;;
    debian)
      [ "$major" -ge 11 ] && ok=1
      local min_ver="11 (Bullseye)"
      ;;
    centos|rhel)
      [ "$major" -ge 9 ] && ok=1
      local min_ver="9"
      ;;
    rocky|almalinux)
      [ "$major" -ge 9 ] && ok=1
      local min_ver="9"
      ;;
    fedora)
      [ "$major" -ge 36 ] && ok=1
      local min_ver="36"
      ;;
    *)
      echo "ERROR: Unsupported distribution '$dist'." >&2
      echo "       Supported: Ubuntu 20.04+, Debian 11+, CentOS Stream 9+, RHEL 9+, Rocky/AlmaLinux 9+, Fedora 36+" >&2
      exit 1
      ;;
  esac

  if [ "$ok" -ne 1 ]; then
    echo "ERROR: $dist $version_id is too old for Chromium 146 (needs glibc >= 2.31, minimum: $min_ver)." >&2
    exit 1
  fi

  echo "System check passed: $dist $version_id ($arch)"
}

# --------------------------------------------------------------------------
# Dependency installation (requires root)
# --------------------------------------------------------------------------
detect_dist() {
  local dist
  if [ -f /etc/os-release ]; then
    dist=$(awk -F= '$1=="ID"{gsub("\"",""); print $2}' /etc/os-release)
  elif [ -f /etc/redhat-release ]; then
    dist=$(awk '{print tolower($1)}' /etc/redhat-release)
  else
    echo "Cannot detect Linux distribution." >&2; return 1
  fi
  echo "${dist,,}"
}

install_deps() {
  local dist
  dist=$(detect_dist) || exit 1
  echo "Detected distribution: $dist"
  case "$dist" in
    debian|ubuntu)
      DEBIAN_FRONTEND=noninteractive apt-get update -q
      DEBIAN_FRONTEND=noninteractive apt-get install -y \
        screen unzip acl xvfb bzip2 libcanberra-gtk-module libxss1 \
        libxtst6 libnss3 wget psmisc bc libgtk-3-0 \
        libgbm-dev libatspi2.0-0 libatomic1 x11-utils
      ;;
    centos|rhel|rocky|almalinux|fedora)
      yum update -y
      yum install -y \
        screen unzip acl libatomic alsa-lib gtk3 libgbm libxkbcommon-x11 \
        cups-libs atk xorg-x11-server-Xvfb xdpyinfo \
        wget bzip2 libXScrnSaver psmisc
      ;;
    *)
      echo "Unsupported distribution: $dist" >&2; exit 1 ;;
  esac
}

# --------------------------------------------------------------------------
# Swap
# --------------------------------------------------------------------------
setup_swap() {
  local size="$1" swap_file="/tmp/9hits_swap"
  swapoff "$swap_file" 2>/dev/null; rm -f "$swap_file"
  fallocate -l "$size" "$swap_file" \
    && chmod 600 "$swap_file" \
    && mkswap "$swap_file" \
    && swapon "$swap_file" \
    && echo "Swap created: $size at $swap_file"
}

# --------------------------------------------------------------------------
# Download & extract
# --------------------------------------------------------------------------
download_app() {
  local tmp_file="/tmp/nhviewer-linux64.tar.bz2"
  echo "Downloading nhviewer from: $DEFAULT_DOWNLOAD"
  wget -q --show-progress -O "$tmp_file" "$DEFAULT_DOWNLOAD" || {
    echo "ERROR: Download failed." >&2; exit 1
  }
  mkdir -p "$INSTALL_DIR"
  echo "Extracting to $INSTALL_DIR ..."
  tar -xjf "$tmp_file" -C "$INSTALL_DIR" --strip-components=1
  rm -f "$tmp_file"
  chmod +x "$INSTALL_DIR/nhviewer"
  echo "Installed to $INSTALL_DIR"
}

# --------------------------------------------------------------------------
# Auto-pick the virtual display resolution from machine size (CPU + RAM).
# The framebuffer itself is tiny; bigger resolutions mainly cost Chromium
# render + x11vnc encode CPU, so we scale by server capability. Min 1920x1080.
# --------------------------------------------------------------------------
auto_resolution() {
  local cores mem_mb
  cores=$(nproc 2>/dev/null || echo 1)
  mem_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null)
  mem_mb=${mem_mb:-0}

  if [ "$cores" -ge 4 ] && [ "$mem_mb" -ge 4000 ]; then
    echo "2560x1440x24"
  else
    echo "1920x1080x24"   # minimum
  fi
}

# --------------------------------------------------------------------------
# Xvfb - disowned so it survives after this script exits
# --------------------------------------------------------------------------
start_xvfb() {
  if xdpyinfo -display "$XVFB_DISPLAY" &>/dev/null; then
    echo "Display $XVFB_DISPLAY already available, reusing."
    return
  fi
  Xvfb "$XVFB_DISPLAY" -screen 0 "$XVFB_RESOLUTION" -nolisten tcp &
  disown $!
  local tries=0
  until xdpyinfo -display "$XVFB_DISPLAY" &>/dev/null || [ $tries -ge 10 ]; do
    sleep 0.5; ((tries++))
  done
  echo "Xvfb started on display $XVFB_DISPLAY"
}

# --------------------------------------------------------------------------
# Kill all viewer/browser processes cleanly before (re)starting
# --------------------------------------------------------------------------
kill_viewer() {
  pkill -TERM -f nhviewer  2>/dev/null || true
  pkill -TERM -f may  2>/dev/null || true
  # Renderer / GPU / utility processes share the same binary name; the above
  # pkill -f catches them all. Give them 2 s to exit gracefully, then SIGKILL.
  sleep 2
  pkill -KILL -f nhviewer  2>/dev/null || true
  pkill -KILL -f may  2>/dev/null || true
}

# --------------------------------------------------------------------------
# VNC (x11vnc) - mirrors the Xvfb display so you can see nhviewer remotely
# --------------------------------------------------------------------------
install_vnc() {
  local dist
  dist=$(detect_dist) || exit 1
  echo "Installing x11vnc..."
  case "$dist" in
    debian|ubuntu)
      DEBIAN_FRONTEND=noninteractive apt-get update -q
      DEBIAN_FRONTEND=noninteractive apt-get install -y x11vnc
      ;;
    centos|rhel|rocky|almalinux|fedora)
      # x11vnc is in EPEL
      yum install -y epel-release 2>/dev/null || true
      yum install -y x11vnc
      ;;
    *)
      echo "ERROR: Cannot install x11vnc on unsupported distribution '$dist'." >&2; exit 1 ;;
  esac
  echo "x11vnc installed."
}

start_vnc() {
  # Kill any existing x11vnc on the same port
  pkill -f "x11vnc.*:${VNC_PORT}" 2>/dev/null || true
  sleep 0.5

  local auth_opts
  if [ -n "$VNC_PW" ]; then
    mkdir -p "$HOME/.x11vnc"
    x11vnc -storepasswd "$VNC_PW" "$HOME/.x11vnc/passwd" 2>/dev/null
    chmod 600 "$HOME/.x11vnc/passwd"
    auth_opts="-rfbauth $HOME/.x11vnc/passwd"
  else
    auth_opts="-nopw"
    echo "WARNING: VNC started without password. Use --vnc-pw=<password> to secure it." >&2
  fi

  # shellcheck disable=SC2086
  x11vnc -display "$XVFB_DISPLAY" -rfbport "$VNC_PORT" \
    -forever -shared -noxdamage -quiet \
    $auth_opts &
  disown $!

  # Wait briefly and verify it's up
  local tries=0
  until ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT}" || [ $tries -ge 10 ]; do
    sleep 0.5; ((tries++))
  done

  echo "x11vnc started - mirrors display $XVFB_DISPLAY on port $VNC_PORT"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
main() {
  parse_args "$@"
  check_system

  # --- Optional root-only steps ---
  if [ "$DO_INSTALL_DEPS" -eq 1 ]; then
    [ "$(id -u)" -ne 0 ] && { echo "ERROR: --install-deps requires root (run with sudo)." >&2; exit 1; }
    install_deps
  fi

  if [ "$DO_INSTALL_VNC" -eq 1 ]; then
    [ "$(id -u)" -ne 0 ] && { echo "ERROR: --install-vnc requires root (run with sudo)." >&2; exit 1; }
    install_vnc
  fi

  if [ -n "$CREATE_SWAP" ]; then
    [ "$(id -u)" -ne 0 ] && { echo "ERROR: --create-swap requires root (run with sudo)." >&2; exit 1; }
    setup_swap "$CREATE_SWAP"
  fi

  # --- Download ---
  download_app

  # --- Virtual display ---
  if [ -z "$XVFB_RESOLUTION" ] || [ "$XVFB_RESOLUTION" = "auto" ]; then
    XVFB_RESOLUTION=$(auto_resolution)
    echo "Auto-selected Xvfb resolution: $XVFB_RESOLUTION ($(nproc 2>/dev/null) cores)"
  fi
  start_xvfb
  export DISPLAY="$XVFB_DISPLAY"

  # --- VNC (mirrors Xvfb so you can see nhviewer remotely) ---
  if [ "$DO_INSTALL_VNC" -eq 1 ]; then
    start_vnc
  fi

  # --- Init run: apply cmdline settings/sessions, then exit ---
  echo ""
  echo "==> Initializing settings..."
  kill_viewer
  "$INSTALL_DIR/nhviewer" "${APP_ARGS[@]}" --exit-on-init
  echo "==> Init complete."

  # --- Generate runner script ---
  # NOTE: the runner only passes --auto-start. The config/session args
  # (--access-key, --system-session, --clear-all-sessions, proxy lists, etc.)
  # are applied once above via --exit-on-init and persisted; re-passing them on
  # every restart would re-create sessions or wipe them (--clear-all-sessions).
  cat > "$INSTALL_DIR/runner.sh" << RUNNER_EOF
#!/bin/bash
export DISPLAY=$XVFB_DISPLAY

RESTART_DELAY=$RESTART_DELAY
PERIODIC_RESTART=86400  # restart every 24 h regardless of crash

kill_viewer() {
  pkill -TERM -f nhviewer  2>/dev/null || true
  pkill -TERM -f may  2>/dev/null || true
  sleep 2
  pkill -KILL -f nhviewer  2>/dev/null || true
  pkill -KILL -f may  2>/dev/null || true
}

while true; do
  kill_viewer

  # Run nhviewer in the FOREGROUND: its dashboard requires a controlling TTY and
  # exits immediately if backgrounded with '&'. 'timeout' provides the periodic
  # 24h restart (sends SIGTERM, exit code 124) without backgrounding.
  timeout \$PERIODIC_RESTART $INSTALL_DIR/nhviewer --auto-start --in-loop

  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] nhviewer exited - restarting in \${RESTART_DELAY}s..."
  sleep \$RESTART_DELAY
done
RUNNER_EOF
  chmod +x "$INSTALL_DIR/runner.sh"

  # --- Launch runner inside a detached screen session ---
  screen -S "$SCREEN_SESSION" -X quit >/dev/null 2>&1
  sleep 1
  screen -dmS "$SCREEN_SESSION" "$INSTALL_DIR/runner.sh"

  echo ""
  echo "==> 9HitsViewer is running in screen session '$SCREEN_SESSION'."
  echo "    Attach : screen -r $SCREEN_SESSION"
  echo "    Stop   : screen -S $SCREEN_SESSION -X quit"

  if [ "$DO_INSTALL_VNC" -eq 1 ]; then
    local server_ip
    server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo ""
    echo "==> VNC is running - connect to view nhviewer live."
    echo "    Address  : ${server_ip:-<server-ip>}:$VNC_PORT"
    echo "    Client   : TigerVNC (https://tigervnc.org) or any VNC client"
    if [ -z "$VNC_PW" ]; then
      echo "    Password : none (use --vnc-pw=<password> to secure)"
    fi
    echo "    To restart VNC manually: x11vnc -display $XVFB_DISPLAY -rfbport $VNC_PORT -forever -shared -noxdamage -nopw &"
  fi
}

main "$@"
