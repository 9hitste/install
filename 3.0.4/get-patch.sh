ARGS=$@
INSTALL_DIR=~
DOWNLOAD_URL=""

function main() {
	echo "Updating..."
	parse_args
	update
}

function parse_args() {
	for i in $ARGS; do
	  case $i in
		--install-dir=*)
		  INSTALL_DIR="${i#*=}"
		  shift # past argument=value
		  ;;
		--default-dl=*)
		  DOWNLOAD_URL="${i#*=}"
		  shift # past argument=value
		  ;;
		--download-url=*)
		  DOWNLOAD_URL="${i#*=}"
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


function update () {
	if [ -d "$INSTALL_DIR/9hitsv3-linux64/" ]; then
		echo "Backing up crontab..."
		crontab -l > "$INSTALL_DIR/9hitsv3-linux64/_9hits_cron.bak" && crontab -r
		echo "Stopping running app..."
		pkill 9hits ; pkill 9hbrowser ; pkill 9htl ; pkill exe
		echo "Downdloading..."
		cd "$INSTALL_DIR/9hitsv3-linux64/" && wget -O "$INSTALL_DIR/_9hits_patch.tar.bz2" $DOWNLOAD_URL
		echo "Extracting update..."
		pkill 9hits ; pkill 9hbrowser ; pkill 9htl ; pkill exe
		cd "$INSTALL_DIR/9hitsv3-linux64/" && tar -xvf "$INSTALL_DIR/_9hits_patch.tar.bz2"
		rm -f "$INSTALL_DIR/_9hits_patch.tar.bz2"
		chmod -R 777 "$INSTALL_DIR/9hitsv3-linux64/"
		chmod +x "$INSTALL_DIR/9hitsv3-linux64/9hits"
		chmod +x "$INSTALL_DIR/9hitsv3-linux64/3rd/9htl"
		chmod +x "$INSTALL_DIR/9hitsv3-linux64/browser/9hbrowser"
		chmod +x "$INSTALL_DIR/9hitsv3-linux64/9HitsApp"
	
		echo "Removing cache..."
		rm -rf ~/.cache/9hits-app/
		echo "Restoring crontab..."
		if [ -f "$INSTALL_DIR/9hitsv3-linux64/_9hits_cron.bak" ]; then
			crontab "$INSTALL_DIR/9hitsv3-linux64/_9hits_cron.bak"
			rm -f "$INSTALL_DIR/9hitsv3-linux64/_9hits_cron.bak"
			echo "Restored"
		fi
		if !(crontab -l | grep -q "* * * * * $INSTALL_DIR/9hitsv3-linux64/cron-start"); then
			(echo "* * * * * $INSTALL_DIR/9hitsv3-linux64/cron-start") | crontab -
			echo "Re-created"
		fi
		
		echo "9HITS APPLICATION HAS BEEN UPDATED!"
	else
		echo "ERROR: NOT FOUND THE 9HITS APPLICATION ($INSTALL_DIR)!"
	fi
}

main
