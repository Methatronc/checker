#!/bin/bash

docker ps --format "{{.Image}}" > images.list
discord="[webhook_url]"
list=""

while read line ; do
if [ "`echo $line | grep \/`" == "" ] ; then
  line=library/$line
fi
image=`echo $line | cut -d : -f 1 | sed 's/ghcr.io\///'`
tag=`echo $line | cut -d : -f 2 | sed 's/ghcr.io\///'`
last_updated=""
page=1
if [ "$tag" == "$image" ] ; then
  tag="latest"
fi
while [ "$last_updated" == "" ] ; do
last_updated=`curl --silent "https://hub.docker.com/v2/repositories/$image/tags?page=$page" | jq --arg tag "$tag" '.results[] | select(.name==$tag) | .last_updated'`
page=`expr "$page" + 1`
done
current_epoch=$(expr "$(date '+%s')" - 86400)
last_updated_epoch=$(date -d $(echo $last_updated | cut -d \" -f 2) '+%s')
if [ "$last_updated_epoch" \> "$current_epoch" ] ; then
  list=$list$(echo " \`$line\`")
else
  echo "Pas de mise à jour pour $line depuis hier."
fi
done < images.list

text=\""Une mise à jour est disponible pour $(echo $list | sed 's/\ /\ et\ /g')"\"
curl -H "Content-Type: application/json" -d "{\"username\": \"Methatronc\",\"embeds\":[{\"description\": $text, \"title\":\"Surveillant de mise à jour d'images docker\", \"color\":2960895}]}" $discord
