#!/bin/bash

# Tor exit node ipsets blocklist
# Should to variablize file paths, ipset name, and iptables cmd to make it nice
# Run on system boot, and schdule with cron once per day
# crontab (note - paths iptables, ipset, curl, xargs need to be full path for cron to find them):
# ipset tor exit node blocklst update (12:17pm UTC / 4.17am PT)
# 17 12 * * * /etc/iptables/ipsets/ipset-torblock.sh > /dev/null 2>&1

/usr/sbin/iptables -C INPUT -i ens3 -m set --match-set torblock src -j DROP > /dev/null 2>&1
if [ $? -ne 0 ] && [ -f /etc/iptables/ipsets/torblock.ipset ]; then
    # iptables rule missing (reboot?) and saved ipset file exists, load it.
    echo "Restoring from saved ipset file"
    /usr/sbin/iptables -D INPUT -i ens3 -m set --match-set torblock src -j DROP > /dev/null 2>&1
    /usr/sbin/ipset -X torblock
    /usr/sbin/ipset restore -file /etc/iptables/ipsets/torblock.ipset
    # Assumes connection tracking rule is 1st to allow related connections back in, insert rule 2nd
    /usr/sbin/iptables -I INPUT 2 -i ens3 -m set --match-set torblock src -j DROP
else
    # iptables rule exists, or saved ipset file does not, re-create ipset (updating it) and save
    /usr/sbin/iptables -D INPUT -i ens3 -m set --match-set torblock src -j DROP 2>/dev/null
    /usr/sbin/ipset -X torblock
    /usr/sbin/ipset -N torblock iphash
    /usr/bin/curl -k -s -S "https://check.torproject.org/torbulkexitlist" | /usr/bin/xargs -n 1 /usr/sbin/ipset -A torblock
    if [ $? -ne 0 ]; then
        # If the download fails, reload from saved ipset file and re-insert iptables rule
        echo "Download failed, reload last saved ipset"
        /usr/sbin/ipset -X torblock
        /usr/sbin/ipset restore -file /etc/iptables/ipsets/torblock.ipset
        /usr/sbin/iptables -I INPUT 2 -i ens3 -m set --match-set torblock src -j DROP
        # We're done, busting out #
        exit 1
    fi
    # ipset download and creation suceeded, save it and re-insert iptables rule
    echo "Download suceeded, saving updated ipset, re-inserting iptables rule"
    /usr/sbin/ipset save torblock -file /etc/iptables/ipsets/torblock.ipset
    /usr/sbin/iptables -I INPUT 2 -i ens3 -m set --match-set torblock src -j DROP
fi
