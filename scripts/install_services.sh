#!/usr/bin/env bash
# This installs the services that have been selected
set -x # Uncomment to enable debugging
trap 'rm -f ${tmpfile}' EXIT
trap 'exit 1' SIGINT SIGHUP
tmpfile=$(mktemp)

config_file=$my_dir/birdnet.conf
export USER=$USER
export HOME=$HOME

export PYTHON_VIRTUAL_ENV="$HOME/BirdNET-Pi/birdnet/bin/python3"

install_depends() {
  apt install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
  apt -qqq update && apt -qqy upgrade
  echo "icecast2 icecast2/icecast-setup boolean false" | debconf-set-selections
  apt install -qqy caddy ftpd sqlite3 php-sqlite3 alsa-utils \
    pulseaudio avahi-utils sox libsox-fmt-mp3 php php-fpm php-curl php-xml \
    php-zip icecast2 swig ffmpeg wget unzip curl cmake make bc libjpeg-dev \
    zlib1g-dev python3-dev python3-pip python3-venv lsof net-tools
}


set_hostname() {
  if [ "$(hostname)" == "raspberrypi" ];then
    hostnamectl set-hostname birdnetpi
    sed -i 's/raspberrypi/birdnetpi/g' /etc/hosts
  fi
}

update_etc_hosts() {
  sed -ie s/'$(hostname).local'/"$(hostname).local ${BIRDNETPI_URL//https:\/\/} ${WEBTERMINAL_URL//https:\/\/} ${BIRDNETLOG_URL//https:\/\/}"/g /etc/hosts
}

install_scripts() {
  ln -sf ${my_dir}/scripts/* /usr/local/bin/
}

install_birdnet_analysis() {
  cat << EOF > $HOME/BirdNET-Pi/templates/birdnet_analysis.service
[Unit]
Description=BirdNET Analysis
After=birdnet_server.service
Requires=birdnet_server.service
[Service]
RuntimeMaxSec=900
Restart=always
Type=simple
RestartSec=2
User=${USER}
ExecStart=/usr/local/bin/birdnet_analysis.sh
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/birdnet_analysis.service /usr/lib/systemd/system
  systemctl enable birdnet_analysis.service
}

install_birdnet_server() {
  cat << EOF > $HOME/BirdNET-Pi/templates/birdnet_server.service
[Unit]
Description=BirdNET Analysis Server
Before=birdnet_analysis.service
[Service]
Restart=always
Type=simple
RestartSec=10
User=${USER}
ExecStart=$PYTHON_VIRTUAL_ENV /usr/local/bin/server.py
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/birdnet_server.service /usr/lib/systemd/system
  systemctl enable birdnet_server.service
}

install_extraction_service() {
  cat << EOF > $HOME/BirdNET-Pi/templates/extraction.service
[Unit]
Description=BirdNET BirdSound Extraction
[Service]
Restart=on-failure
RestartSec=3
Type=simple
User=${USER}
ExecStart=/usr/bin/env bash -c 'while true;do extract_new_birdsounds.sh;sleep 3;done'
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/extraction.service /usr/lib/systemd/system
  systemctl enable extraction.service
}

create_necessary_dirs() {
  echo "Creating necessary directories"
  [ -d ${EXTRACTED} ] || sudo -u ${USER} mkdir -p ${EXTRACTED}
  [ -d ${EXTRACTED}/By_Date ] || sudo -u ${USER} mkdir -p ${EXTRACTED}/By_Date
  [ -d ${EXTRACTED}/Charts ] || sudo -u ${USER} mkdir -p ${EXTRACTED}/Charts
  [ -d ${PROCESSED} ] || sudo -u ${USER} mkdir -p ${PROCESSED}

  sudo -u ${USER} ln -fs $my_dir/exclude_species_list.txt $my_dir/scripts
  sudo -u ${USER} ln -fs $my_dir/include_species_list.txt $my_dir/scripts
  sudo -u ${USER} ln -fs $my_dir/homepage/* ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/model/labels.txt ${my_dir}/scripts
  sudo -u ${USER} ln -fs $my_dir/scripts ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/scripts/play.php ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/scripts/spectrogram.php ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/scripts/overview.php ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/scripts/stats.php ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/scripts/todays_detections.php ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/scripts/history.php ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/scripts/weekly_report.php ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/homepage/images/favicon.ico ${EXTRACTED}
  sudo -u ${USER} ln -fs ${HOME}/phpsysinfo ${EXTRACTED}
  sudo -u ${USER} ln -fs $my_dir/templates/phpsysinfo.ini ${HOME}/phpsysinfo/
  sudo -u ${USER} ln -fs $my_dir/templates/green_bootstrap.css ${HOME}/phpsysinfo/templates/
  sudo -u ${USER} ln -fs $my_dir/templates/index_bootstrap.html ${HOME}/phpsysinfo/templates/html
  chmod -R g+rw $my_dir
  chmod -R g+rw ${RECS_DIR}
}

generate_BirdDB() {
  echo "Generating BirdDB.txt"
  if ! [ -f $my_dir/BirdDB.txt ];then
    sudo -u ${USER} touch $my_dir/BirdDB.txt
    echo "Date;Time;Sci_Name;Com_Name;Confidence;Lat;Lon;Cutoff;Week;Sens;Overlap" | sudo -u ${USER} tee -a $my_dir/BirdDB.txt
  elif ! grep Date $my_dir/BirdDB.txt;then
    sudo -u ${USER} sed -i '1 i\Date;Time;Sci_Name;Com_Name;Confidence;Lat;Lon;Cutoff;Week;Sens;Overlap' $my_dir/BirdDB.txt
  fi
  chown $USER:$USER ${my_dir}/BirdDB.txt && chmod g+rw ${my_dir}/BirdDB.txt
}

set_login() {
  if ! [ -d /etc/lightdm ];then
    systemctl set-default multi-user.target
    ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
  fi
}

install_recording_service() {
  echo "Installing birdnet_recording.service"
  cat << EOF > $HOME/BirdNET-Pi/templates/birdnet_recording.service
[Unit]
Description=BirdNET Recording
[Service]
Environment=XDG_RUNTIME_DIR=/run/user/1000
Restart=always
Type=simple
RestartSec=3
User=${USER}
ExecStart=/usr/local/bin/birdnet_recording.sh
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/birdnet_recording.service /usr/lib/systemd/system
  systemctl enable birdnet_recording.service
}

install_custom_recording_service() {
  echo "Installing custom_recording.service"
  cat << EOF > $HOME/BirdNET-Pi/templates/custom_recording.service
[Unit]
Description=BirdNET Custom Recording
[Service]
Environment=XDG_RUNTIME_DIR=/run/user/1000
Restart=always
Type=simple
RestartSec=3
User=${USER}
ExecStart=/usr/local/bin/custom_recording.sh
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/custom_recording.service /usr/lib/systemd/system
}

install_Caddyfile() {
  [ -d /etc/caddy ] || mkdir /etc/caddy
  if [ -f /etc/caddy/Caddyfile ];then
    cp /etc/caddy/Caddyfile{,.original}
  fi
  if ! [ -z ${CADDY_PWD} ];then
  HASHWORD=$(caddy hash-password --plaintext ${CADDY_PWD})
  cat << EOF > /etc/caddy/Caddyfile
http:// ${BIRDNETPI_URL} {
  root * ${EXTRACTED}
  file_server browse
  handle /By_Date/* {
    file_server browse
  }
  handle /Charts/* {
    file_server browse
  }
  basicauth /views.php?view=File* {
    birdnet ${HASHWORD}
  }
  basicauth /Processed* {
    birdnet ${HASHWORD}
  }
  basicauth /scripts* {
    birdnet ${HASHWORD}
  }
  basicauth /stream {
    birdnet ${HASHWORD}
  }
  basicauth /phpsysinfo* {
    birdnet ${HASHWORD}
  }
  basicauth /terminal* {
    birdnet ${HASHWORD}
  }
  reverse_proxy /stream localhost:8000
  php_fastcgi unix//run/php/php7.4-fpm.sock
  reverse_proxy /log* localhost:8080
  reverse_proxy /stats* localhost:8501
  reverse_proxy /terminal* localhost:8888
}
EOF
  else
    cat << EOF > /etc/caddy/Caddyfile
http:// ${BIRDNETPI_URL} {
  root * ${EXTRACTED}
  file_server browse
  handle /By_Date/* {
    file_server browse
  }
  handle /Charts/* {
    file_server browse
  }
  reverse_proxy /stream localhost:8000
  php_fastcgi unix//run/php/php7.4-fpm.sock
  reverse_proxy /log* localhost:8080
  reverse_proxy /stats* localhost:8501
  reverse_proxy /terminal* localhost:8888
}
EOF
  fi

  systemctl enable caddy
  usermod -aG $USER caddy
  usermod -aG video caddy
}

install_avahi_aliases() {
  cat << 'EOF' > $HOME/BirdNET-Pi/templates/avahi-alias@.service
[Unit]
Description=Publish %I as alias for %H.local via mdns
After=network.target network-online.target
Requires=network-online.target
[Service]
Restart=always
RestartSec=3
Type=simple
ExecStart=/bin/bash -c "/usr/bin/avahi-publish -a -R %I $(hostname -I |cut -d' ' -f1)"
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/avahi-alias@.service /usr/lib/systemd/system
  systemctl enable avahi-alias@"$(hostname)".local.service
}

install_birdnet_stats_service() {
  cat << EOF > $HOME/BirdNET-Pi/templates/birdnet_stats.service
[Unit]
Description=BirdNET Stats
[Service]
Restart=on-failure
RestartSec=5
Type=simple
User=${USER}
ExecStart=$HOME/BirdNET-Pi/birdnet/bin/streamlit run $HOME/BirdNET-Pi/scripts/plotly_streamlit.py --browser.gatherUsageStats false --server.address localhost --server.baseUrlPath "/stats"

[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/birdnet_stats.service /usr/lib/systemd/system
  systemctl enable birdnet_stats.service
}

install_spectrogram_service() {
  cat << EOF > $HOME/BirdNET-Pi/templates/spectrogram_viewer.service
[Unit]
Description=BirdNET-Pi Spectrogram Viewer
[Service]
Restart=always
RestartSec=10
Type=simple
User=${USER}
ExecStart=/usr/local/bin/spectrogram.sh
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/spectrogram_viewer.service /usr/lib/systemd/system
  systemctl enable spectrogram_viewer.service
}

install_chart_viewer_service() {
  echo "Installing the chart_viewer.service"
  cat << EOF > $HOME/BirdNET-Pi/templates/chart_viewer.service
[Unit]
Description=BirdNET-Pi Chart Viewer Service
[Service]
Restart=always
RestartSec=120
Type=simple
User=$USER
EnvironmentFile=${config_file}
ExecStart=$PYTHON_VIRTUAL_ENV /usr/local/bin/daily_plot.py
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/chart_viewer.service /usr/lib/systemd/system
  systemctl enable chart_viewer.service
}

install_gotty_logs() {
  sudo -u ${USER} ln -sf $my_dir/templates/gotty \
    ${HOME}/.gotty
  sudo -u ${USER} ln -sf $my_dir/templates/bashrc \
    ${HOME}/.bashrc
  cat << EOF > $HOME/BirdNET-Pi/templates/birdnet_log.service
[Unit]
Description=BirdNET Analysis Log
[Service]
Restart=on-failure
RestartSec=3
Type=simple
User=${USER}
Environment=TERM=xterm-256color
ExecStart=/usr/local/bin/gotty --address localhost -p 8080 -P log --title-format "BirdNET-Pi Log" birdnet_log.sh
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/birdnet_log.service /usr/lib/systemd/system
  systemctl enable birdnet_log.service
  cat << EOF > $HOME/BirdNET-Pi/templates/web_terminal.service
[Unit]
Description=BirdNET-Pi Web Terminal
[Service]
Restart=on-failure
RestartSec=3
Type=simple
Environment=TERM=xterm-256color
ExecStart=/usr/local/bin/gotty --address localhost -w -p 8888 -P terminal --title-format "BirdNET-Pi Terminal" login
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/web_terminal.service /usr/lib/systemd/system
  systemctl enable web_terminal.service
}

configure_caddy_php() {
  echo "Configuring PHP for Caddy"
  sed -i 's/www-data/caddy/g' /etc/php/*/fpm/pool.d/www.conf
  systemctl restart php7\*-fpm.service
  echo "Adding Caddy sudoers rule"
  cat << EOF > /etc/sudoers.d/010_caddy-nopasswd
caddy ALL=(ALL) NOPASSWD: ALL
EOF
  chmod 0440 /etc/sudoers.d/010_caddy-nopasswd
}

install_phpsysinfo() {
  sudo -u ${USER} git clone https://github.com/phpsysinfo/phpsysinfo.git \
    ${HOME}/phpsysinfo
}

config_icecast() {
  if [ -f /etc/icecast2/icecast.xml ];then
    cp /etc/icecast2/icecast.xml{,.prebirdnetpi}
  fi
  sed -i 's/>admin</>birdnet</g' /etc/icecast2/icecast.xml
  passwords=("source-" "relay-" "admin-" "master-" "")
  for i in "${passwords[@]}";do
  sed -i "s/<${i}password>.*<\/${i}password>/<${i}password>${ICE_PWD}<\/${i}password>/g" /etc/icecast2/icecast.xml
  done
  sed -i 's|<!-- <bind-address>.*|<bind-address>127.0.0.1</bind-address>|;s|<!-- <shoutcast-mount>.*|<shoutcast-mount>/stream</shoutcast-mount>|'

  systemctl enable icecast2.service
}

install_livestream_service() {
  cat << EOF > $HOME/BirdNET-Pi/templates/livestream.service
[Unit]
Description=BirdNET-Pi Live Stream
After=network-online.target
Requires=network-online.target
[Service]
Environment=XDG_RUNTIME_DIR=/run/user/1000
Restart=always
Type=simple
RestartSec=3
User=${USER}
ExecStart=/usr/local/bin/livestream.sh
[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/livestream.service /usr/lib/systemd/system
  systemctl enable livestream.service
}

install_cleanup_cron() {
  sed "s/\$USER/$USER/g" $my_dir/templates/cleanup.cron >> /etc/crontab
}

install_weekly_cron() {
  sed "s/\$USER/$USER/g" $my_dir/templates/weekly_report.cron >> /etc/crontab
}

chown_things() {
  chown -R $USER:$USER $HOME/Bird*
}

increase_caddy_timeout() {
  mkdir /etc/systemd/system/caddy.service.d
  cat << EOF > /etc/systemd/system/caddy.service.d/override.conf
[Service]
TimeoutSec=300s
EOF
  systemctl daemon-reload
}

install_services() {
  set_hostname
  update_etc_hosts
  set_login

  install_depends
  install_scripts
  install_Caddyfile
  install_avahi_aliases
  install_birdnet_analysis
  install_birdnet_server
  install_birdnet_stats_service
  install_recording_service
  install_custom_recording_service # But does not enable
  install_extraction_service
  install_spectrogram_service
  install_chart_viewer_service
  install_gotty_logs
  install_phpsysinfo
  install_livestream_service
  install_cleanup_cron
  install_weekly_cron
  increase_caddy_timeout

  create_necessary_dirs
  generate_BirdDB
  configure_caddy_php
  config_icecast
  USER=$USER HOME=$HOME ${my_dir}/scripts/createdb.sh
}

if [ -f ${config_file} ];then
  source ${config_file}
  install_services
  chown_things
else
  echo "Unable to find a configuration file. Please make sure that $config_file exists."
fi
