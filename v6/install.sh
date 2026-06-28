#!/bin/bash
# 9Hits Viewer v6 - Linux installer (systemd-supervised)
# Usage: sudo bash install.sh --access-key=<32hex> [options]
# Requires systemd + root. For containers/non-systemd hosts use the Docker image.

DEFAULT_DOWNLOAD="https://dl.9hits.com/9hitsv6-linux64.tar.bz2"

# --- Defaults ---
INSTALL_DIR="/opt/9hits"
RESTART_DELAY=5
DO_INSTALL_DEPS=1   # install system deps by default; --skip-install-deps to opt out
DO_INSTALL_VNC=0
VNC_PW=""
NO_VNC_PW=0     # 1 (via --no-vnc-pw) = run VNC open; otherwise a random password is generated
VNC_PORT=5901   # 5901 by default to avoid clashing with VNC servers commonly on 5900
XVFB_RESOLUTION=""   # empty or "auto" -> pick based on CPU/RAM (min 1920x1080x24)
CREATE_SWAP=""
XVFB_DISPLAY=":99"
SCREEN_SESSION="9hits"
RESET_INTERVAL=""   # e.g. 6h/24h/30m -> forwarded to the viewer (--reset-interval), which gracefully self-restarts on that interval; empty = never

# App args forwarded to nhviewer (--exit-on-init / --auto-start are managed by this script)
APP_ARGS=()

# --------------------------------------------------------------------------
# Arg parsing
# --------------------------------------------------------------------------
parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --install-dir=*)   INSTALL_DIR="${arg#*=}" ;;
      --skip-install-deps) DO_INSTALL_DEPS=0 ;;
      # avoid pass this old flag to the viewer
      --install-deps) DO_INSTALL_DEPS=1 ;;
      --install-vnc)     DO_INSTALL_VNC=1 ;;
      --vnc-pw=*)        VNC_PW="${arg#*=}" ;;
      --no-vnc-pw)       NO_VNC_PW=1 ;;
      --vnc-port=*)      VNC_PORT="${arg#*=}" ;;
      --resolution=*)    XVFB_RESOLUTION="${arg#*=}" ;;
      --create-swap=*)   CREATE_SWAP="${arg#*=}" ;;
      --restart-delay=*) RESTART_DELAY="${arg#*=}" ;;
      --default-dl=*)    DEFAULT_DOWNLOAD="${arg#*=}" ;;
      --reset-interval=*) RESET_INTERVAL="${arg#*=}" ;;
      # Script controls these - strip from forwarded args
      --exit-on-init|--auto-start) ;;
      # Everything else goes straight to nhviewer
      *) APP_ARGS+=("$arg") ;;
    esac
  done
}

# --------------------------------------------------------------------------
# System requirements check
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

  # Minimums below track the glibc >= 2.31
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
    echo "ERROR: $dist $version_id is too old (needs glibc >= 2.31, minimum: $min_ver)." >&2
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
# Kill all viewer/browser processes cleanly before (re)starting
# --------------------------------------------------------------------------
kill_viewer() {
  # Match the exact process NAME (comm), not the command line. A bare "pkill -f
  # may" is dangerously broad — "may" as a substring once matched (and killed)
  # our own SSH shell. "-x" only hits processes actually named may/nhviewer and
  # is install-path independent (catches strays from an old INSTALL_DIR too).
  # systemd's KillMode=control-group is the primary killer; this is the backup
  # for any stray outside the cgroup.
  pkill -TERM -x nhviewer 2>/dev/null || true
  pkill -TERM -x may      2>/dev/null || true
  sleep 2
  pkill -KILL -x nhviewer 2>/dev/null || true
  pkill -KILL -x may      2>/dev/null || true
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

# Random 8-char alphanumeric (VNC truncates passwords to 8 chars anyway).
gen_password() {
  LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 8
}

# Resolve the VNC password (random unless given, or none with --no-vnc-pw) and
# write the rfbauth file consumed by the 9hits-vnc systemd unit.
prepare_vnc_password() {
  if [ -z "$VNC_PW" ] && [ "$NO_VNC_PW" -eq 0 ]; then
    VNC_PW=$(gen_password)
    echo ""
    echo "  ============================================================"
    echo "   VNC auto-generated password: $VNC_PW"
    echo "   (set your own with --vnc-pw=<pw>, or open it with --no-vnc-pw)"
    echo "  ============================================================"
    echo ""
  fi
  if [ -n "$VNC_PW" ]; then
    mkdir -p "$HOME/.x11vnc"
    x11vnc -storepasswd "$VNC_PW" "$HOME/.x11vnc/passwd" 2>/dev/null
    chmod 600 "$HOME/.x11vnc/passwd"
  fi
}

# --------------------------------------------------------------------------
# Flags for the supervised (auto-start) run, baked into the systemd viewer unit.
# Only run-time flags belong here; config/sessions are applied once by the init
# pass (--exit-on-init) and persisted, so they must NOT be re-passed (would
# re-create sessions or wipe them via --clear-all-sessions). --reset-interval is
# handled INSIDE the viewer (it gracefully self-restarts on that interval);
# systemd merely relaunches it on the clean exit.
# --------------------------------------------------------------------------
build_run_flags() {
  RUN_FLAGS=(--auto-start --in-loop --render-to-terminal)
  [ -n "$RESET_INTERVAL" ] && RUN_FLAGS+=("--reset-interval=$RESET_INTERVAL")
}

# --------------------------------------------------------------------------
# Init run: apply cmdline settings/sessions to the persisted config, then exit.
# --------------------------------------------------------------------------
run_init() {
  echo ""
  echo "==> Initializing settings..."
  kill_viewer
  "$INSTALL_DIR/nhviewer" "${APP_ARGS[@]}" --exit-on-init
  echo "==> Init complete."
}

# --------------------------------------------------------------------------
# Tear down EVERY trace of a previous run so re-running install.sh never
# conflicts. Also kills any runner.sh loop left behind by older versions of
# this script (we no longer create one), to avoid loop-on-loop. Safe when
# nothing is running.
# --------------------------------------------------------------------------
teardown_stack() {
  local dnum="${XVFB_DISPLAY#:}"; dnum="${dnum%%.*}"
  echo "==> Cleaning up any previous instance..."
  # Stop systemd-managed units from a prior run (if any)
  systemctl stop "${SCREEN_SESSION}.service" "${SCREEN_SESSION}-vnc.service" "${SCREEN_SESSION}-xvfb.service" 2>/dev/null || true
  # Kill the screen session AND any stale runner.sh loop from an older version
  screen -S "$SCREEN_SESSION" -X quit >/dev/null 2>&1 || true
  pkill -TERM -f "$INSTALL_DIR/runner.sh" 2>/dev/null || true
  sleep 2
  pkill -KILL -f "$INSTALL_DIR/runner.sh" 2>/dev/null || true
  rm -f "$INSTALL_DIR/runner.sh" 2>/dev/null || true
  # Kill viewer + engine children
  kill_viewer
  # Kill any stray Xvfb on our display and clear its lock
  pkill -f "Xvfb $XVFB_DISPLAY" 2>/dev/null || true
  sleep 1
  rm -f "/tmp/.X${dnum}-lock" "/tmp/.X11-unix/X${dnum}" 2>/dev/null || true
  screen -wipe >/dev/null 2>&1 || true
}

# --------------------------------------------------------------------------
# systemd setup (the only supervisor). Writes the units, enables them (reboot
# persistence), and (re)starts the supervised stack. The viewer runs inside
# `screen` so the dashboard stays attachable (screen -r). Idempotent: re-running
# overwrites the units and restarts cleanly.
# --------------------------------------------------------------------------
setup_systemd() {
  local dnum xvfb_bin x11vnc_bin screen_bin vnc_units="" exec_pre="" exec_start
  dnum="${XVFB_DISPLAY#:}"; dnum="${dnum%%.*}"
  xvfb_bin=$(command -v Xvfb); screen_bin=$(command -v screen); x11vnc_bin=$(command -v x11vnc)

  echo "==> Installing systemd services..."

  # --- Xvfb display unit ---
  cat > "/etc/systemd/system/${SCREEN_SESSION}-xvfb.service" << UNIT
[Unit]
Description=9hits Xvfb virtual display $XVFB_DISPLAY
After=network-online.target

[Service]
Type=simple
ExecStartPre=-/bin/sh -c 'rm -f /tmp/.X${dnum}-lock /tmp/.X11-unix/X${dnum} 2>/dev/null'
ExecStart=$xvfb_bin $XVFB_DISPLAY -screen 0 $XVFB_RESOLUTION -nolisten tcp
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

  # --- optional x11vnc unit ---
  if [ "$DO_INSTALL_VNC" -eq 1 ]; then
    local vnc_auth="-nopw"
    [ -n "$VNC_PW" ] && vnc_auth="-rfbauth $HOME/.x11vnc/passwd"
    cat > "/etc/systemd/system/${SCREEN_SESSION}-vnc.service" << UNIT
[Unit]
Description=9hits x11vnc (mirror $XVFB_DISPLAY)
After=${SCREEN_SESSION}-xvfb.service
Requires=${SCREEN_SESSION}-xvfb.service
BindsTo=${SCREEN_SESSION}-xvfb.service

[Service]
Type=simple
ExecStart=$x11vnc_bin -display $XVFB_DISPLAY -rfbport $VNC_PORT -forever -shared -noxdamage -quiet $vnc_auth
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
    vnc_units="${SCREEN_SESSION}-vnc.service"
  fi

  # --- viewer unit: runs nhviewer DIRECTLY inside screen so the dashboard stays
  # attachable (screen -r) while systemd is the sole supervisor. systemd's
  # Restart=always relaunches on crash AND on the viewer's own scheduled clean
  # exit (--reset-interval), so there is no restart loop to maintain here. ---
  if [ -n "$screen_bin" ]; then
    exec_pre="ExecStartPre=-$screen_bin -S $SCREEN_SESSION -X quit"
    exec_start="$screen_bin -DmS $SCREEN_SESSION $INSTALL_DIR/nhviewer ${RUN_FLAGS[*]}"
  else
    # No screen -> the unit has no controlling pty, so drop --render-to-terminal
    # (its alternate-screen takeover would just spew escape codes into the journal).
    local headless_flags=() f
    for f in "${RUN_FLAGS[@]}"; do [ "$f" = "--render-to-terminal" ] || headless_flags+=("$f"); done
    exec_start="$INSTALL_DIR/nhviewer ${headless_flags[*]}"
  fi
  cat > "/etc/systemd/system/${SCREEN_SESSION}.service" << UNIT
[Unit]
Description=9hits viewer
After=${SCREEN_SESSION}-xvfb.service network-online.target
Requires=${SCREEN_SESSION}-xvfb.service
StartLimitIntervalSec=0

[Service]
Type=simple
Environment=DISPLAY=$XVFB_DISPLAY HOME=$HOME
WorkingDirectory=$INSTALL_DIR
$exec_pre
ExecStart=$exec_start
Restart=always
RestartSec=$RESTART_DELAY
KillMode=control-group

[Install]
WantedBy=multi-user.target
UNIT

  systemctl daemon-reload
  systemctl enable "${SCREEN_SESSION}-xvfb.service" $vnc_units "${SCREEN_SESSION}.service" >/dev/null 2>&1 || true

  # Bring the display (+VNC) up BEFORE the init pass needs it.
  systemctl restart "${SCREEN_SESSION}-xvfb.service"
  [ -n "$vnc_units" ] && systemctl restart "$vnc_units"
  export DISPLAY="$XVFB_DISPLAY"
  local tries=0
  until xdpyinfo -display "$XVFB_DISPLAY" &>/dev/null || [ $tries -ge 20 ]; do sleep 0.5; ((tries++)); done

  run_init

  systemctl restart "${SCREEN_SESSION}.service"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
main() {
  parse_args "$@"
  check_system

  # Validate --reset-interval early (number + optional s/m/h/d unit).
  if [ -n "$RESET_INTERVAL" ] && ! echo "$RESET_INTERVAL" | grep -Eq '^[0-9]+[smhd]?$'; then
    echo "ERROR: --reset-interval must be a number with an optional s/m/h/d unit (e.g. 30m, 1h, 6h, 24h)." >&2
    exit 1
  fi

  # systemd is required: it is the supervisor (auto-restart + boot persistence).
  if [ ! -d /run/systemd/system ]; then
    echo "ERROR: this installer requires systemd (no /run/systemd/system)." >&2
    echo "       For containers / non-systemd hosts, use the Docker image instead." >&2
    exit 1
  fi
  if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: root is required (systemd unit installation). Re-run with sudo." >&2
    exit 1
  fi

  # --- Optional steps (root already guaranteed above) ---
  [ "$DO_INSTALL_DEPS" -eq 1 ] && install_deps
  [ "$DO_INSTALL_VNC" -eq 1 ] && install_vnc
  [ -n "$CREATE_SWAP" ] && setup_swap "$CREATE_SWAP"

  # --- Download ---
  download_app

  # --- Resolve virtual display resolution ---
  if [ -z "$XVFB_RESOLUTION" ] || [ "$XVFB_RESOLUTION" = "auto" ]; then
    XVFB_RESOLUTION=$(auto_resolution)
    echo "Auto-selected Xvfb resolution: $XVFB_RESOLUTION ($(nproc 2>/dev/null) cores)"
  fi

  # Clean up any previous run first (idempotent; also clears stale old-version loops).
  teardown_stack

  # Assemble the run-time flags baked into the viewer unit.
  build_run_flags

  # VNC password must exist before the unit (which uses -rfbauth) starts.
  [ "$DO_INSTALL_VNC" -eq 1 ] && prepare_vnc_password
  setup_systemd

  echo ""
  local disable_units="$SCREEN_SESSION $SCREEN_SESSION-xvfb"
  [ "$DO_INSTALL_VNC" -eq 1 ] && disable_units="$disable_units $SCREEN_SESSION-vnc"
  echo "==> 9HitsViewer is running under systemd (auto-restart + survives reboot)."
  echo "    Status   : systemctl status $SCREEN_SESSION"
  echo "    Logs     : journalctl -u $SCREEN_SESSION -f"
  command -v screen >/dev/null 2>&1 && \
    echo "    Dashboard: screen -dr $SCREEN_SESSION   (Ctrl+A then D to detach)"
  echo "    Stop     : systemctl stop $SCREEN_SESSION"
  echo "    Disable  : systemctl disable --now $disable_units"

  if [ -n "$RESET_INTERVAL" ]; then
    echo "    Reset    : viewer self-restarts every $RESET_INTERVAL (graceful, in-app)"
  fi

  if [ "$DO_INSTALL_VNC" -eq 1 ]; then
    local server_ip
    server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo ""
    echo "==> VNC is running - connect to view nhviewer live."
    echo "    Address  : ${server_ip:-<server-ip>}:$VNC_PORT"
    echo "    Client   : TigerVNC (https://tigervnc.org) or any VNC client"
    if [ -n "$VNC_PW" ]; then
      echo "    Password : $VNC_PW"
    else
      echo "    Password : none (--no-vnc-pw)"
    fi
  fi
}

main "$@"
