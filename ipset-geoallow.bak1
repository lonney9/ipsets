#!/bin/bash

# This was the first one v1.0, worked fine on an Intel VM, then didnt work on an ARM VM
# I think cron for some reason on ARM  systems ignores #!/bin/bash and needs the "!" escaped with "\!" line in the v1.1 script
# Geo whitelist ipsets script, drops connections from countries NOT whitelisted
# See https://www.ipdeny.com/ipblocks/ for list
# Should to variablize country codes (line 25), file paths, ipset name, and iptables cmd to make it nice
# Run on system boot, and schdule with cron once per day
# crontab (note - paths iptables, ipset, curl, xargs need to be full path for cron to find them):
# ipset geo whitelist update (12:07pm UTC / 4.07am PT)
# 7 12 * * * /etc/iptables/ipsets/ipset-geoallow.sh > /dev/null 2>&1

/usr/sbin/iptables -C INPUT -i ens3 -m set ! --match-set geoallow src -j DROP > /dev/null 2>&1
if [ $? -ne 0 ] && [ -f /etc/iptables/ipsets/geoallow.ipset ]; then
    # iptables rule missing (reboot?) and saved ipset file exists, load it
    echo "Restoring from saved ipset file"
    /usr/sbin/iptables -D INPUT -i ens3 -m set ! --match-set geoallow src -j DROP > /dev/null 2>&1
    /usr/sbin/ipset -X geoallow
    /usr/sbin/ipset restore -file /etc/iptables/ipsets/geoallow.ipset
    # Assumes connection tracking rule is 1st to allow related connections back in, insert rule 2nd
    /usr/sbin/iptables -I INPUT 2 -i ens3 -m set ! --match-set geoallow src -j DROP
else
    # iptables rule exists, or saved ipset file does not, re-create ipset (updating it) and save
    /usr/sbin/iptables -D INPUT -i ens3 -m set ! --match-set geoallow src -j DROP
    /usr/sbin/ipset -X geoallow
    /usr/sbin/ipset -N geoallow nethash maxelem 131072
    for i in au ca nz us; do
        echo "${i}"
        /usr/bin/curl -k -s -S "https://www.ipdeny.com/ipblocks/data/countries/${i}.zone" | /usr/bin/xargs -n 1 /usr/sbin/ipset -A geoallow
        if [ $? -ne 0 ]; then
            # If the download fails, reload from saved ipset file and re-insert iptables rule
            echo "Download failed, reload last saved ipset"
            /usr/sbin/ipset -X geoallow
            /usr/sbin/ipset restore -file /etc/iptables/ipsets/geoallow.ipset
            /usr/sbin/iptables -I INPUT 2 -i ens3 -m set ! --match-set geoallow src -j DROP
            # We're done, busting out
            exit 1
        fi
    done
    # ipset download and creation suceeded, save it and re-insert iptables rule
    echo "Download suceeded, saving updated ipset, re-inserting iptables rule"
    /usr/sbin/ipset save geoallow -file /etc/iptables/ipsets/geoallow.ipset
    /usr/sbin/iptables -I INPUT 2 -i ens3 -m set ! --match-set geoallow src -j DROP
fi
