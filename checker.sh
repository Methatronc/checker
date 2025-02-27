#!/bin/bash

token=""

# below will check wether to use discord or gotify
# and wether to use english of french language
if [[ "$token" =~ "https://discord.com/api/webhooks" ]] ; then
  server=discord
else
  server=gotify
fi
if [ "`env | grep fr_FR`" != "" ] ; then
  lang=fr
else
  lang=en
fi

# below will remove duplicates
docker ps --format "{{.Image}}" | sort -u > images.list

list=""

while read line ; do

# below is needed for images such as debian/postgres/... that can only be accessed with library/[image_name] url
  if [ "`echo $line | grep \/`" == "" ] ; then
    line=library/$line
  fi

# belows is needed because linuxserver images will output with ghcr.io/ appended to the name and that needs to be cut
  image=`echo $line | cut -d : -f 1 | sed 's/ghcr.io\///' | sed 's/lscr.io\///'`
  tag=`echo $line | cut -d : -f 2 | sed 's/ghcr.io\///' | sed 's/lscr.io\///'`

  last_updated=""
  page=1

# below adds by default the tag 'latest' to the images that are without tag, same way docker does
  if [ "$tag" == "$image" ] ; then
    tag="latest"
  fi

  repo=`curl --silent "https://hub.docker.com/v2/repositories/$image/tags?page=$page"`

# below is needed for non-docker hub images
  if [ "$repo" == "{\"count\":0,\"next\":null,\"previous\":null,\"results\":[]}" ] ; then
    last_updated="1970-01-01T00:00:00.000000Z"
  elif [ "$repo" == "{\"detail\": \"Object not found\"}" ] ; then
    last_updated="1970-01-01T00:00:00.000000Z"
  fi

# below is necessary because most images will get multiple pages and your tag might not be on the first.
# I limited page to 100 because so far I never saw a request needing more that a dozen pages, and without
# a limit the loop could, should a bug arise, last forever.
  while [ "$last_updated" == "" ] && [ "$page" -lt 100 ] ; do
    repo=`curl --silent "https://hub.docker.com/v2/repositories/$image/tags?page=$page"`
    last_updated=`echo $repo | jq --arg tag "$tag" '.results[] | select(.name==$tag) | .last_updated'`

# sleep below in order to reduce requests frequency
    sleep 2
    ((page+=1))
  done

# below comparison will give as a result updates from the last 24h ( 86400s )
# change '86400' to another value to increase or reduce that search time
  current_epoch=$(expr "$(date '+%s')" - 86400)
  last_updated_epoch=$(date -d $(echo $last_updated | cut -d \" -f 2) '+%s')

  if [ "$lang" == "en" ] ; then
    nope="No update for $line since yesterday."
  else
    nope="Pas de mise à jour pour $line depuis hier."
  fi
  if [ "$last_updated_epoch" \> "$current_epoch" ] ; then
    list=$list$(echo "\n\n\`$line\`")
  else
    echo $nope
  fi
done < images.list

if [ "$lang" == "en" ] ; then
  text=\""An update is available for :$(echo $list)"\"
else
  text=\""Une mise à jour est disponible pour :$(echo $list)"\"
fi
if [ "$server" == "discord" ] ; then
  curl -H "Content-Type: application/json" -d "{\"username\": \"Methatronc\",\"embeds\":[{\"description\": $text, \"title\":\"Docker Image Update Checker\", \"color\":2960895}]}" $token
else
  curl -H "Content-Type: application/json" -X POST $token -d "{\"title\":\"Docker Image Update Checker\",\"message\":$text,\"priority\":5,\"extras\":{\"client::display\":{\"contentType\":\"text/markdown\"}}}"
fi
