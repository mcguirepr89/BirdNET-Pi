#!/usr/bin/env bash
#Display network info for phpsysinfo

echo "........................................IPs....................................."
echo "LAN IP: $(hostname -I|cut -d' ' -f1)"
echo "Public IP: $(curl -s4 ifconfig.co)"
if dpkg -l | grep -q vcgencmd ; then
  echo "..................................\`vcgencmd stats\`.............................."
  sudo -u$USER vcgencmd get_throttled
  hex=$(sudo -u$USER vcgencmd get_throttled | cut -d'x' -f2)
  binary=$(echo "ibase=16;obase=2;$hex" | bc)
  echo "Binary: $binary"
  revbinary=$(echo $binary | rev)
  if echo $binary | grep 1; then
    echo "ISSUES DETECTED"
    if [ ${revbinary:0:1} -eq 1 ] &>/dev/null; then
      message="Under-voltage detected"
      echo "$message"
      dmesg -H | grep -i voltage
    fi
    if [ ${revbinary:1:1} -eq 1 ] &>/dev/null; then
      message="Arm frequency capped"
      echo "$message"
      dmesg -H | grep -i frequen
    fi
    if [ ${revbinary:2:1} -eq 1 ] &>/dev/null; then
      message="Currently Throttled"
      echo "$message"
      dmesg -H | grep -i throttl
    fi
    if [ ${revbinary:3:1} -eq 1 ] &>/dev/null; then
      message="Soft temperatue limit active"
      echo "$message"
      dmesg -H | grep -i temperature
    fi
    if [ ${revbinary:16:1} -eq 1 ] &>/dev/null; then
      message="Under-voltage has occurred"
      echo "$message"
      dmesg -H | grep -i voltage
    fi
    if [ ${revbinary:17:1} -eq 1 ] &>/dev/null; then
      message="Arm frequency capping has occurred"
      echo "$message"
      dmesg -H | grep -i frequen
    fi
    if [ ${revbinary:18:1} -eq 1 ] &>/dev/null; then
      message="Throttling has occurred"
      echo "$message"
      dmesg -H | grep -i throttl
    fi
    if [ ${revbinary:19:1} -eq 1 ] &>/dev/null; then
      message="Soft temperature limit has occurred"
      echo "$message"
      dmesg -H | grep -i temperature
    fi
  fi

  echo "....................................Clock Speeds................................"
  for i in arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi; do
    echo -e "${i}:\t$(sudo -u$USER vcgencmd measure_clock ${i})"
  done
  echo "........................................Volts..................................."
  for i in core sdram_c sdram_i sdram_p; do
    echo -e "${i}:\t$(sudo -u$USER vcgencmd measure_volts ${i})"
  done
fi
echo ".....................................Caddyfile.................................."
cat /etc/caddy/Caddyfile
echo ".................................... Crontab...................................."
cat /etc/crontab | grep -ve '^#'
