#!/bin/bash

dist="unknown"
url="http://dl.9hits.com/9hitsv3-linux64.tar.bz2"


ARGS=$@
CURRENT_HASH=$(date +%s)
TOKEN=""
NOTE=""
MODE="exchange"
AUTO_START="no"
HIDE_BROWSER="no"
SYSTEM_SESSION="no"
CLEAR_ALL_SESSIONS="no"
ALLOW_POPUPS="yes"
ALLOW_ADULT="yes"
ALLOW_CRYPTO="yes"
SESSION_NOTE=""
EX_PROXY_SESSIONS=""
EX_PROXY_URL=""
NO_CRONJOB="no"
SCHEDULE_RESET=""
CREATE_SWAP=""
CACHE_DIR=""
CACHE_DEL="200"
SSH_CONNECTOR=""
INSTALL_DIR=$HOME

function main() {
	[ "$(id -u)" != "0" ] && \
		abort "This script must be executed as root."
		
	parse_args
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
}

function parse_args() {
	for i in $ARGS; do
	  case $i in
		--install-dir=*)
		  INSTALL_DIR="${i#*=}"
		  shift # past argument=value
		  ;;
		--mode=*)
		  MODE="${i#*=}"
		  shift # past argument=value
		  ;;
		--token=*)
		  TOKEN="${i#*=}"
		  shift # past argument=value
		  ;;
		--note=*)
		  NOTE="${i#*=}"
		  shift # past argument=value
		  ;;
		--allow-popups=*)
		  ALLOW_POPUPS="${i#*=}"
		  shift # past argument=value
		  ;;
		--allow-adult=*)
		  ALLOW_ADULT="${i#*=}"
		  shift # past argument=value
		  ;;
		--allow-crypto=*)
		  ALLOW_CRYPTO="${i#*=}"
		  shift # past argument=value
		  ;;
		--system-session)
		  SYSTEM_SESSION="yes"
		  shift # past argument with no value
		  ;;
		--ex-proxy-sessions=*)
		  EX_PROXY_SESSIONS="${i#*=}"
		  shift # past argument=value
		  ;;
		--ex-proxy-url=*)
		  EX_PROXY_URL="${i#*=}"
		  shift # past argument=value
		  ;;
		--session-note=*)
		  SESSION_NOTE="${i#*=}"
		  shift # past argument=value
		  ;;
		--ssh-connector=*)
		  SSH_CONNECTOR="${i#*=}"
		  shift # past argument=value
		  ;;
		--cache-dir=*)
		  CACHE_DIR="${i#*=}"
		  shift # past argument=value
		  ;;
		--create-swap=*)
		  CREATE_SWAP="${i#*=}"
		  shift # past argument=value
		  ;;
		--cache-del=*)
		  CACHE_DEL="${i#*=}"
		  shift # past argument=value
		  ;;
		--auto-start)
		  AUTO_START="yes"
		  shift # past argument with no value
		  ;;
		--hide-browser)
		  HIDE_BROWSER="yes"
		  shift # past argument with no value
		  ;;
		--clear-all-sessions)
		  CLEAR_ALL_SESSIONS="yes"
		  shift # past argument with no value
		  ;;
		--no-cronjob)
		  NO_CRONJOB="yes"
		  shift # past argument with no value
		  ;;
		--schedule-reset=*)
		  SCHEDULE_RESET="${i#*=}"
		  shift # past argument=value
		  ;;
		-*|--*)
		  echo "Unknown option $i"
		  ;;
		*)
		  ;;
	  esac
	done
}

function install_9hits() {
	pkill 9hits ; pkill 9hbrowser ; pkill 9htl ; pkill exe
	echo "Removing exists instance..."
	rm -rf "$INSTALL_DIR/_9hits.tar.bz2"
	rm -rf "$INSTALL_DIR/9hitsv3-linux64/"
	rm -rf ~/.config/9hits-app/
	rm -rf ~/.cache/9hits-app/
	
	echo "Downloading the 9Hits App..."
	wget -O "$INSTALL_DIR/_9hits.tar.bz2" $url
	tar -xjvf "$INSTALL_DIR/_9hits.tar.bz"2 -C "$INSTALL_DIR"
	
	chmod -R 777 "$INSTALL_DIR/9hitsv3-linux64/"
	chmod +x "$INSTALL_DIR/9hitsv3-linux64/9hits"
	chmod +x "$INSTALL_DIR/9hitsv3-linux64/3rd/9htl"
	chmod +x "$INSTALL_DIR/9hitsv3-linux64/browser/9hbrowser"
	chmod +x "$INSTALL_DIR/9hitsv3-linux64/9HitsApp"
	#sysctl vm.drop_caches=3
	
	echo "9Hits App is initializing..."
	
	NH_ARGS=" --mode=$MODE --current-hash=$CURRENT_HASH --hide-browser=$HIDE_BROWSER"
	
	if [ "$TOKEN" != "" ]; then
		NH_ARGS+=" --token=$TOKEN"
	fi
	if [ "$NOTE" != "" ]; then
		NH_ARGS+=" --note=$NOTE"
	fi
	if [ "$CREATE_SWAP" != "" ]; then
		swapoff "$INSTALL_DIR/9hits_swap" && rm -f "$INSTALL_DIR/9hits_swap"
		fallocate -l "$CREATE_SWAP" "$INSTALL_DIR/9hits_swap" && chmod 600 "$INSTALL_DIR/9hits_swap" && mkswap "$INSTALL_DIR/9hits_swap" && swapon "$INSTALL_DIR/9hits_swap"
	fi
	
	if [ "$MODE" == "exchange" ]; then
		NH_ARGS+=" --allow-popups=$ALLOW_POPUPS --allow-adult=$ALLOW_ADULT --allow-crypto=$ALLOW_CRYPTO"
		
		if [ "$SESSION_NOTE" != "" ]; then
			NH_ARGS+=" --session-note=$SESSION_NOTE"
		fi
		if [ "$SYSTEM_SESSION" == "yes" ]; then
			NH_ARGS+=" --system-session"
		fi
		if [ "$EX_PROXY_SESSIONS" != "" ]; then
			NH_ARGS+=" --ex-proxy-sessions=$EX_PROXY_SESSIONS"
		fi
		if [ "$EX_PROXY_URL" != "" ]; then
			NH_ARGS+=" --ex-proxy-url=$EX_PROXY_URL"
		fi
		if [ "$CACHE_DIR" != "" ]; then
			NH_ARGS+=" --cache-path=$CACHE_DIR"
		fi
		if [ "$SSH_CONNECTOR" != "" ]; then
			NH_ARGS+=" --ssh-connector=$SSH_CONNECTOR"
		fi
		if [ "$CACHE_DEL" != "" ]; then
			NH_ARGS+=" --cache-del=$CACHE_DEL"
		fi
	fi
	
	if [ "$NO_CRONJOB" == "yes" ]; then
		if [ "$AUTO_START" == "yes" ]; then
			NH_ARGS+=" --auto-start"
		fi
		
		echo "9Hits App is starting..."
		"$INSTALL_DIR/9hitsv3-linux64/9hits" $NH_ARGS
	else
		NH_ARGS+=" --reset-cache --exit-on-init"
		cat >"$INSTALL_DIR/9hitsv3-linux64/cron-start" <<EOL
#!/bin/bash
while [[ ! \$(pidof 9hits) ]]; do
	killall 9hits 9hbrowser 9htl exe
	Xvfb :1 &
	export DISPLAY=:1 && $INSTALL_DIR/9hitsv3-linux64/9hits --auto-start --single-process --no-sandbox --no-zygote --disable-crash-handler=true --disable-logging > /dev/null
	exit
done
EOL
		chmod +x "$INSTALL_DIR/9hitsv3-linux64/cron-start"
		#if crontab is not created yet
		if !(crontab -l | grep -q "* * * * * $INSTALL_DIR/9hitsv3-linux64/cron-start"); then
			crontab -l > tmpcron
			echo "* * * * * $INSTALL_DIR/9hitsv3-linux64/cron-start" >> tmpcron
			crontab tmpcron
			rm -f tmpcron
		fi
		
		pkill 9h ; pkill exe
		Xvfb :1 &
		export DISPLAY=:1 && "$INSTALL_DIR/9hitsv3-linux64/9hits" $NH_ARGS && echo "9HITS WILL START WITHIN A MINUTE!" && pkill 9h
	fi
	
	#echo $NH_ARGS
}

function install_apt() {
	DEBIAN_FRONTEND=noninteractive apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
	DEBIAN_FRONTEND=noninteractive apt-get install -y xvfb bzip2 libcanberra-gtk-module libxss1 htop sed tar libxtst6 libnss3 wget psmisc bc libgtk-3-0 libgbm-dev libatspi2.0-0 libatomic1 && install_9hits
}

function install_yum() {
	yum update -y
	yum install -y libatomic alsa-lib-devel gtk3-devel libgbm libxkbcommon-x11 cups-libs.i686 cups-libs.x86_64 atk.x86_64 libnss3.so xorg-x11-server-Xvfb sed tar Xvfb wget bzip2 libXScrnSaver psmisc && install_9hits
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
