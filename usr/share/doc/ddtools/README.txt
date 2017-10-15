File: usr/share/ddtools/docs/README.txt
Package: ddtools
Author: bgstack15
Startdate: 2017-05-26
Title: Readme file for ddtools
Purpose: All packages should come with a readme
Usage: Read it.
Reference: README.txt
Improve:
Document: Below this line

### WELCOME
ddtools is a suite of shell scripts that help manage dns and dhcpd.
Updatezone provides an easy way to update dns zone files. Intended primarily for bind9 zone files, experimentation is encouraged.
Instead of running the series of commands manually: rndc freeze, vi zonefile, rndc thaw and so on, use updatezone.
dhcpd-control helps manage paired dhcpd servers.

### CONFIGURATION
The conf files belong in /etc/ddtools/. See example in /usr/share/ddtools/examples/.

### USING THIS TOOL

$ updatezone ipa.smith122.com
Where this file exists: /etc/ddtools/ipa.smith122.com.conf

    UZ_ZONE_NAME=ipa.smith122.com
    UZ_FORWARD_ZONE=ipa.smith122.com
    UZ_FORWARD_FILE=/var/named/data/db.ipa.smith122.com
    UZ_REVERSE_ZONE=1.168.192.in-addr.arpa
    UZ_REVERSE_FILE=/var/named/data/db.192.168.1
    UZ_SLAVE_COUNT=1
    UZ_SLAVE_1=dns2

The updatezone tool searches for the value of UZ_ZONE_NAME to declare a match and use that configuration file.
The zone definitions are used in the freeze/thaw/retransfer commands.

This tool will only request updates for zones that are updated. Also, you do not need to adjust the serial number at all. The script will detect changes and then increment the serial number for you.

You can also specify multiple zones on the command line.
$ updatezone ipa.smith122.com ad.smith122.com

You can also use the --flush flag to clear out the A and PTR records whose TTL matches the dhcp server TTL. It ties in nicely with the dhcpd-control --flush command. Remember that you need to give a zone name (or -c conffile) option as well.

Example:
updatezone --flush ipa.smith122.com

### NOTES

### REFERENCE

### CHANGELOG
2017-05-27 B Stack <bgstack15@gmail.com> 0.0-2
- Initial package construction

2017-10-14 B Stack <bgstack15@gmail.com> 0.0-3
- Rearranged directory structure to match current standards
- Added bash autocompletion definition for updatezone
- Added --flush to updatezone to match dhcpd-control
