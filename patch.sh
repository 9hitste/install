_9HITSUSER="_9hits"
ARGS=$@
wget -O "/tmp/get-patch.sh" https://9hitste.github.io/install/get-patch.sh
chmod +x "/tmp/get-patch.sh"
runuser -l $_9HITSUSER -c "/bin/bash /tmp/get-patch.sh $(printf "%q" "$ARGS")"
rm -f "/tmp/get-patch.sh"
