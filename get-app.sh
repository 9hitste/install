#!/bin/bash
ARGS=$@
_9HITSUSER="_9hits"

#DOWNLOAD_URL="http://dl.9hits.com/9hitsv3-linux64.tar.bz2"
DOWNLOAD_URL="http://mirror-dl.9hits.com/9hitsv3-linux64.tar.bz2"

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
BULK_PROXY_TYPE=""
BULK_PROXY_LIST=""
NO_CRONJOB="no"
SCHEDULE_RESET=""
CREATE_SWAP=""
CACHE_DIR=""
CACHE_DEL="200"
SSH_CONNECTOR=""
INSTALL_DIR=~

function main() {
	parse_args
	install_9hits
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
		--bulk-add-proxy-type=*)
		  BULK_PROXY_TYPE="${i#*=}"
		  shift # past argument=value
		  ;;
		--bulk-add-proxy-list=*)
		  BULK_PROXY_LIST="${i#*=}"
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
		--download-url=*)
		  DOWNLOAD_URL="${i#*=}"
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
	crontab -r
	pkill 9hits ; pkill 9hbrowser ; pkill 9htl ; pkill exe
	echo "Removing exists instance..."
	rm -rf "$INSTALL_DIR/_9hits.tar.bz2"
	rm -rf "$INSTALL_DIR/9hitsv3-linux64/"
	rm -rf ~/.config/9hits-app/
	rm -rf ~/.cache/9hits-app/
	
	echo "Downloading the 9Hits App..."
	wget -O "$INSTALL_DIR/_9hits.tar.bz2" $DOWNLOAD_URL
	tar -xjvf "$INSTALL_DIR/_9hits.tar.bz2" -C "$INSTALL_DIR"
	
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
		if [ "$BULK_PROXY_TYPE" != "" ]; then
			NH_ARGS+=" --bulk-add-proxy-type=$BULK_PROXY_TYPE"
		fi
		if [ "$BULK_PROXY_LIST" != "" ]; then
			NH_ARGS+=" --bulk-add-proxy-list=$BULK_PROXY_LIST"
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
	export DISPLAY=:1 && $INSTALL_DIR/9hitsv3-linux64/9hits --auto-start --single-process --no-sandbox --no-zygote --disable-logging > /dev/null
	exit
done
EOL
		chmod +x "$INSTALL_DIR/9hitsv3-linux64/cron-start"
		echo "* * * * * $INSTALL_DIR/9hitsv3-linux64/cron-start" | crontab -
		
		if [ "$SCHEDULE_RESET" != "" ]; then
			crontab -l > tmpcron
			case "$SCHEDULE_RESET" in
				1)
					echo "0 * * * * pkill 9hits ; pkill 9hbrowser ; pkill 9htl ; pkill exe; $INSTALL_DIR/9hitsv3-linux64/cron-start >/dev/null 2>&1" >> tmpcron
					;;
				2)
					echo "0 */2 * * * pkill 9hits ; pkill 9hbrowser ; pkill 9htl ; pkill exe; $INSTALL_DIR/9hitsv3-linux64/cron-start >/dev/null 2>&1" >> tmpcron
					;;
				6)
					echo "0 */6 * * * pkill 9hits ; pkill 9hbrowser ; pkill 9htl ; pkill exe; $INSTALL_DIR/9hitsv3-linux64/cron-start >/dev/null 2>&1" >> tmpcron
					;;
				12)
					echo "0 */12 * * * pkill 9hits ; pkill 9hbrowser ; pkill 9htl ; pkill exe; $INSTALL_DIR/9hitsv3-linux64/cron-start >/dev/null 2>&1" >> tmpcron
					;;
				24)
					echo "0 0 * * * pkill 9hits ; pkill 9hbrowser ; pkill 9htl ; pkill exe; $INSTALL_DIR/9hitsv3-linux64/cron-start >/dev/null 2>&1" >> tmpcron
					;;
			esac
			crontab tmpcron
			rm -f tmpcron
		fi
		
		pkill 9h ; pkill exe
		Xvfb :1 &
		export DISPLAY=:1 && "$INSTALL_DIR/9hitsv3-linux64/9hits" $NH_ARGS && echo "9HITS WILL START WITHIN A MINUTE!" && pkill 9h
	fi
	
	rm -f "$INSTALL_DIR/_9hits.tar.bz2"
}

main
