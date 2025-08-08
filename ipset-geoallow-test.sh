#!/bin/bash

## ipsets-geoallow.sh ##
# //github.com/lonney9/ipsets
# version 1.1 test:
#   - It works from command line
#   - Need to test with cron and systemd
#   - Improve script quality and condition handling..

# Geo allow downloads netblocks of countries to whitelist using an inverted DROP rule.
# Designed to be self sufficient to load, update and save ipsets. 

# Script uses ipset to create ipsets (lists of many addresses or subnets).
# Iptables then references that set in a rule.

# Self contained script that will load a saved set on first run.
# Or if no saved ipset found, download, add and save the set.
# Or update existing running ipset, save and reload it.

# This is a simple "batch style" script that works with systemd and cron.
# My goal is to get a nicely written script working with vars and functions etc later (version 2)


echo " "
echo " "


# Test if the firewall rule is not (inverted match) present and if an saved ipset file is present.
#   In this case the system may have been restarted.
# If the fw rule is not present, and the saved ipset is present, load the saved set.
# If neither is true, attempt to download, create, load, and save a new ipset to refresh the running set or create a saved ipset.
#   In this case, the running ipset will be updated (script can be scheduled), or if the saved ipset file is not found, a new one
#   will be downloaded, created, inserted into iptables, and saved.
# This single if with a two-way branch, handles three conditions
#   Load from file after boot / no saved file (attempt download) / update running system (schedule the script as is) 

if ! /usr/sbin/iptables -C INPUT -i enp0s6 -m set ! --match-set geoallow src -j DROP 2>/dev/null && [ -f /etc/iptables/ipsets/geoallow.ipset ]; then
  echo "[ ** iptables rule does not exist, ipset file found ]"
  echo "[ restore ipset from file ]"
    # Delete the fw rules and running ipset incase it's present or add checks to script to handle it better
  /usr/sbin/iptables -D INPUT -i enp0s6 -m set ! --match-set geoallow src -j DROP
  /usr/sbin/ipset -X geoallow
  /usr/sbin/ipset restore -file /etc/iptables/ipsets/geoallow.ipset
  echo " "
  echo "* * *"
  echo " "
  /usr/sbin/ipset list geoallow | head -n 7
  echo " "
  echo "* * *"
  echo " "
    # Add firewall rule in position 7
  echo "[ add fw rule ]"
  /usr/sbin/iptables -I INPUT 7 -i enp0s6 -m set ! --match-set geoallow src -j DROP

  else
    # update and save (either the rule is present (running system) OR the file is missing, download to refresh and save.
  echo "[ ** fw rule loaded or saved ipset does not exist ]"
  echo "[ attempt update and save - download + load + save new ipset file ]"


  ##  START DOWNLOAD CODE  ##

  /usr/sbin/iptables -D INPUT -i enp0s6 -m set ! --match-set geoallow src -j DROP
  /usr/sbin/ipset -X geoallow
  /usr/sbin/ipset -N geoallow nethash maxelem 131072

  for i in au ca nz us; do ## Prod.
  ## for i in au nz; do ## Test.
    echo "${i}"
    /usr/bin/curl -k -s -S "https://www.ipdeny.com/ipblocks/data/countries/${i}.zone" | /usr/bin/xargs -n 1 /usr/sbin/ipset -A geoallow

    if [ ! "$?" = 0 ]; then
      # try and reload a saved ipset (in the event an update to a running set fails, put the old one back)
      # in cases where there is no saved ipset set, this is the end of the line..

      echo "[ download failed ]"
      
      if [ -f /etc/iptables/ipsets/geoallow.ipset ]; then 

        echo "[ loading saved ipset ]"
        /usr/sbin/ipset -X geoallow
        /usr/sbin/ipset restore -file /etc/iptables/ipsets/geoallow.ipset
        /usr/sbin/iptables -I INPUT 7 -i enp0s6 -m set ! --match-set geoallow src -j DROP
        exit 0

        else 
        # If the download fails and there is no file in this case, we're stuffed. #
        echo "[ download failed, no saved ipset, giving up :\ ]"
        exit 1
        
      fi

    fi

  done

  ##  END DOWNLOAD CODE  ##

  # Display ipset info
  echo " "
  echo "* * *"
  echo " "
  /usr/sbin/ipset list geoallow | head -n 7
  echo " "
  echo "* * *"
  echo " "

  # Add firewall rule in position 7
  echo "[ add fw rule ]"
  /usr/sbin/iptables -I INPUT 7 -i enp0s6 -m set ! --match-set geoallow src -j DROP
  echo "[ saving new ipset to file ]"
  /usr/sbin/ipset save geoallow -file /etc/iptables/ipsets/geoallow.ipset

fi

echo "[ END MAIN SCRIPT ]"

# End main script.