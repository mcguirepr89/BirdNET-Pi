#!/usr/bin/env bash
# Creates and installs the /etc/birdnet/birdnet.conf file
set -x # Uncomment to enable debugging
set -e
trap 'exit 1' SIGINT SIGHUP

echo "Beginning $0"
birdnet_conf=$my_dir/birdnet.conf

# Retrieve latitude and longitude from web
json=$(curl -s4 http://ip-api.com/json)
if [ "$(echo "$json" | jq -r .status)" = "success" ]; then
  LATITUDE=$(echo "$json" | jq .lat)
  LONGITUDE=$(echo "$json" | jq .lon)
else
  echo -e "\033[33mCouldn't set latitude and longitude automatically, you will need to do this manually from the web interface by navigating to Tools -> Settings -> Location.\033[0m"
  LATITUDE=0.0000
  LONGITUDE=0.0000
fi

install_config() {
  sed \
    -e "s/@@hostname@@/$HOSTNAME/g" \
    -e "s/@@latitude@@/$LATITUDE/g" \
    -e "s/@@longitude@@/$LONGITUDE/g" \
    < $my_dir/birdnet-defaults.conf.template \
    > $birdnet_conf
}

# Checks for a birdnet.conf file
if ! [ -f ${birdnet_conf} ];then
  install_config
fi
chmod g+w ${birdnet_conf}
[ -d /etc/birdnet ] || sudo mkdir /etc/birdnet
sudo ln -sf $birdnet_conf /etc/birdnet/birdnet.conf
grep -ve '^#' -e '^$' /etc/birdnet/birdnet.conf > $my_dir/firstrun.ini
