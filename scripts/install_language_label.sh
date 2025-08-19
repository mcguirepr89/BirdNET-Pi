#!/usr/bin/env bash

usage() { echo "Usage: $0 -l <language i18n id>" 1>&2; exit 1; }

while getopts "l:" o; do
  case "${o}" in
    l)
      lang=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

HOME=$(awk -F: '/1000/ {print $6}' /etc/passwd)

label_file_name="labels_${lang}.txt"

unzip -o $HOME/BirdNET-Pi/model/labels_l18n.zip $label_file_name \
  -d $HOME/BirdNET-Pi/model \
  && mv -f $HOME/BirdNET-Pi/model/$label_file_name $HOME/BirdNET-Pi/model/labels.txt \
  && logger "[$0] Changed language label file to '$label_file_name'";

label_file_name_flickr="labels_en.txt"

unzip -o $HOME/BirdNET-Pi/model/labels_l18n.zip $label_file_name_flickr \
  -d $HOME/BirdNET-Pi/model \
  && mv -f $HOME/BirdNET-Pi/model/$label_file_name_flickr $HOME/BirdNET-Pi/model/labels_flickr.txt \
  && logger "[$0] Set Flickr labels '$label_file_name_flickr'";

# install corresponding fonts for display characters in daily_plot
case "${lang}" in
  zh)
    sudo apt install -y fonts-wqy-zenhei \
    && logger "[$0] Install language:${zh} needed fonts";
    ;;
  *)
    true
    ;;
esac

exit 0
