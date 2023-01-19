#!/bin/bash
DEFAULT_DOWNLOAD="http://mirror-dl.9hits.com/3.0.4/9hitsv3-linux64.tar.bz2"
_9HITSUSER="_9hits"

set -- --default-dl=$DEFAULT_DOWNLOAD $@
ARGS=$@
dist="unknown"

function main() {
	[ "$(id -u)" != "0" ] && \
		abort "This script must be executed as root."
		
	check_dist
	
	echo "Installing dependencies..."
	case "${dist}" in
		debian|ubuntu)
			install_apt
			;;
		centos|fedora|rocky)
			install_yum
			;;
		*)
			not_supported
			;;
	esac
	
	check_custom_dir
	get_app
}

function get_app() {
	if id "$_9HITSUSER" &>/dev/null; then
		echo "9HITS LOG: user created: $_9HITSUSER"
	else
		echo "9HITS LOG: creating user: $_9HITSUSER"
		useradd -m $_9HITSUSER
	fi

	wget -O "/tmp/get-app.sh" https://9hitste.github.io/install/3.0.4/get-app.sh && chmod +x "/tmp/get-app.sh"
	runuser -l $_9HITSUSER -c "/bin/bash /tmp/get-app.sh $(printf "%q" "$ARGS")"
	rm -f "/tmp/get-app.sh"
}

function check_custom_dir() {
	for i in $ARGS; do
	  case $i in
		--install-dir=*)
			if [ ! -d "${i#*=}" ];then
				mkdir "${i#*=}"
			fi
			setfacl -R -m u:$_9HITSUSER:rwx "${i#*=}"
			shift # past argument=value
		  ;;
		--cache-dir=*)
			if [ ! -d "${i#*=}" ];then
				mkdir "${i#*=}"
			fi
			setfacl -R -m u:$_9HITSUSER:rwx "${i#*=}"
			shift # past argument=value
		  ;;
		*)
		  ;;
	  esac
	done
}

function install_apt() {
	DEBIAN_FRONTEND=noninteractive apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
	DEBIAN_FRONTEND=noninteractive apt-get install -y unzip acl cron xvfb bzip2 libcanberra-gtk-module libxss1 htop sed tar libxtst6 libnss3 wget psmisc bc libgtk-3-0 libgbm-dev libatspi2.0-0 libatomic1
}

function install_yum() {
	yum update -y
	yum install -y unzip acl cronie libatomic alsa-lib-devel gtk3-devel libgbm libxkbcommon-x11 cups-libs.i686 cups-libs.x86_64 atk.x86_64 libnss3.so xorg-x11-server-Xvfb sed tar Xvfb wget bzip2 libXScrnSaver psmisc
}

function check_dist() {
	echo -n "Verifying compatibility with 9hits..."
	if [  -f /etc/os-release  ]; then
		dist=$(awk -F= '$1 == "ID" {gsub("\"", ""); print$2}' /etc/os-release)
	elif [ -f /etc/redhat-release ]; then
		dist=$(awk '{print tolower($1)}' /etc/redhat-release)
	else
		not_supported
	fi

	dist=$(echo "${dist}" | tr '[:upper:]' '[:lower:]')

	case "${dist}" in
		debian|ubuntu|centos|fedora|rocky)
			echo "OK"
			;;
		*)
			not_supported
			;;
	esac
}

function not_supported() {
	cat <<-EOF
	The 9Hits App does not support the OS/Distribution on this machine.
	EOF
	exit 1
}

# abort with an error message
function abort() {
	read -r line func file <<< "$(caller 0)"
	echo "ERROR in $file:$func:$line: $1" > /dev/stderr
	exit 1
}

main
