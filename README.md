# IPSets
Scripts to geo whitelist, and block Tor exit nodes.
See the comments with-in the scripts for more info.
These scripts are designed to be self sufficient:
- systemd service will load the previous saved ipsets on boot (this is fast).
  - The script checks if the iptables rule for the ipset exists, if it does not (this assumes the system was rebooted) and the saved ipset file is present, it will load the saved ipset. In the case of loading the netblocks used in the US (white listing it with the geo whitelist script) of which there are many, this is very fast, the iptables rule is then inserted. The geo whitelist ipset iptables rule inverts the match, so anything not in the ipset is dropped.
  - If the saved ipset file does not exist, the script will then download, create, save the ipset, and insert the iptables rule.
-  When the script is run again, either manually or by cron, and the iptables rule exists the script will perform an update by removing the iptables rule and ipset, downloading the netblock (geo whitelist) or IP addresses (tor exit node list) again, creating the ipset, saving it, and re-inserting the iptables rule.
  - In the case of the US geo netblocks, creating the new ipset can take several minutes due to the large number of netblocks.
- If the download fails for some reason, the previously saved ipset is loaded from file.


# SSH connection limiting
We can also limit the number of repeated connections to SSH and start dropping new connections if the limit is exceeded.

This is very simple with two rules placed above the existing SSH accept rule, add this to `/etc/iptables/rules.v4` (change interface name ens3 as needed):
```
-A INPUT -i ens3 -p tcp --dport 22 -m recent --update --seconds 60 --hitcount 3 --name SSH --rsource -j DROP
-A INPUT -i ens3 -p tcp --dport 22 -m recent --set --name SSH --rsource -j ACCEPT
```
After three connection attempts with-in 60 seconds from the same IP address, new connections will be dropped for 60 seconds. After that time connections will be accepted again. This slows down and stops most brute force attempts for example
