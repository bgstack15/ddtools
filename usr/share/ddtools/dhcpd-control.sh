#!/bin/sh
# Filename: dhcpd-control.sh
# Location: 
# Author: bgstack15@gmail.com
# Startdate: 2017-05-28 18:18:46
# Title: Script that Facilitates the Configuration of DHCPD
# Purpose: 
# Package: 
# History: 
# Usage: 
# Reference: ftemplate.sh 2017-05-24a; framework.sh 2017-05-24a
# Improve:
fiversion="2017-05-24a"
dhcpdcontrolversion="2017-05-28a"

usage() {
   less -F >&2 <<ENDUSAGE
usage: dhcpd-control.sh [-duV] [ --flush | --edit | --edit-local | --remove-mac <mac> ] [ --force ]
version ${dhcpdcontrolversion}
 -d debug   Show debugging info, including parsed variables.
 -u usage   Show this usage block.
 -V version Show script version number.
 --flush    Clears all current leases
 --edit     Edit the combined file-- the one shared by both servers.
 --edit-local Edit the local file.
 --remove-mac <MAC> Clears the leases for this MAC address.
Return values:
0 Normal
1 Help or version info displayed
2 Count or type of flaglessvals is incorrect
3 Incorrect OS type
4 Unable to find dependency
5 Not run as root or sudo
ENDUSAGE
}

# DEFINE FUNCTIONS

# DEFINE TRAPS

clean_dhcpdcontrol() {
   #rm -f ${logfile} > /dev/null 2>&1
   [ ] #use at end of entire script if you need to clean up tmpfiles
}

CTRLC() {
   #trap "CTRLC" 2
   [ ] #useful for controlling the ctrl+c keystroke
}

CTRLZ() {
   #trap "CTRLZ" 18
   [ ] #useful for controlling the ctrl+z keystroke
}

parseFlag() {
   flag="$1"
   hasval=0
   case ${flag} in
      # INSERT FLAGS HERE
      "d" | "debug" | "DEBUG" | "dd" ) setdebug; ferror "debug level ${debug}";;
      "u" | "usage" | "help" | "h" ) usage; exit 1;;
      "V" | "fcheck" | "version" ) ferror "${scriptfile} version ${dhcpdcontrolversion}"; exit 1;;
      #"i" | "infile" | "inputfile" ) getval;infile1=${tempval};;
      "f" | "force" ) DHCPD_CONTROL_FORCE=1;;
      "flush" ) action="flush";;
      "edit-local" ) action="edit-local";;
      "edit" ) action="edit";;
      "remove-mac" ) getval; DHCPD_CONTROL_MAC_TO_REMOVE="${tempval}";;
   esac
   
   debuglev 10 && { test ${hasval} -eq 1 && ferror "flag: ${flag} = ${tempval}" || ferror "flag: ${flag}"; }
}

# DETERMINE LOCATION OF FRAMEWORK
while read flocation; do if test -x ${flocation} && test "$( ${flocation} --fcheck )" -ge 20170524; then frameworkscript="${flocation}"; break; fi; done <<EOFLOCATIONS
./framework.sh
${scriptdir}/framework.sh
~/bin/bgscripts/framework.sh
~/bin/framework.sh
~/bgscripts/framework.sh
~/framework.sh
/usr/local/bin/bgscripts/framework.sh
/usr/local/bin/framework.sh
/usr/bin/bgscripts/framework.sh
/usr/bin/framework.sh
/bin/bgscripts/framework.sh
/usr/share/bgscripts/framework.sh
EOFLOCATIONS
test -z "${frameworkscript}" && echo "$0: framework not found. Aborted." 1>&2 && exit 4

# INITIALIZE VARIABLES
# variables set in framework:
# today server thistty scriptdir scriptfile scripttrim
# is_cronjob stdin_piped stdout_piped stderr_piped sendsh sendopts
. ${frameworkscript} || echo "$0: framework did not run properly. Continuing..." 1>&2
infile1=
outfile1=
logfile=${scriptdir}/${scripttrim}.${today}.out
action=""
define_if_new interestedparties "bgstack15@gmail.com"
# SIMPLECONF
#define_if_new default_conffile "/etc/sysconfig/dhcpd-control"
define_if_new default_conffile "/home/bgirton/rpmbuild/SOURCES/updatezone-0.0-2/etc/sysconfig/dhcpd-control"
#define_if_new defuser_conffile ~/.config/dhcpdcontrol/dhcpdcontrol.conf
define_if_new EDITOR vi

# REACT TO OPERATING SYSTEM TYPE
case $( uname -s ) in
   Linux) [ ];;
   FreeBSD) [ ];;
   *) echo "${scriptfile}: 3. Indeterminate OS: $( uname -s )" 1>&2 && exit 3;;
esac

## REACT TO ROOT STATUS
#case ${is_root} in
#   1) # proper root
#      [ ] ;;
#   sudo) # sudo to root
#      [ ] ;;
#   "") # not root at all
#      #ferror "${scriptfile}: 5. Please run as root or sudo. Aborted."
#      #exit 5
#      [ ]
#      ;;
#esac

# SET CUSTOM SCRIPT AND VALUES
#setval 1 sendsh sendopts<<EOFSENDSH      # if $1="1" then setvalout="critical-fail" on failure
#/usr/share/bgscripts/send.sh -hs     #                setvalout maybe be "fail" otherwise
#/usr/local/bin/send.sh -hs               # on success, setvalout="valid-sendsh"
#/usr/bin/mail -s
#EOFSENDSH
#test "${setvalout}" = "critical-fail" && ferror "${scriptfile}: 4. mailer not found. Aborted." && exit 4

# VALIDATE PARAMETERS
# objects before the dash are options, which get filled with the optvals
# to debug flags, use option DEBUG. Variables set in framework: fallopts
validateparams - "$@"

# CONFIRM TOTAL NUMBER OF FLAGLESSVALS IS CORRECT
#if test ${thiscount} -lt 2;
#then
#   ferror "${scriptfile}: 2. Fewer than 2 flaglessvals. Aborted."
#   exit 2
#fi

# CONFIGURE VARIABLES AFTER PARAMETERS

## LOAD CONFIG FROM SIMPLECONF
## This section follows a simple hierarchy of precedence, with first being used:
##    1. parameters and flags
##    2. environment
##    3. config file
##    4. default user config: ~/.config/script/script.conf
##    5. default config: /etc/script/script.conf
#if test -f "${conffile}";
#then
#   get_conf "${conffile}"
#else
#   if test "${conffile}" = "${default_conffile}" || test "${conffile}" = "${defuser_conffile}"; then :; else ferror "${scriptfile}: Ignoring conf file which is not found: ${conffile}."; fi
#fi
#test -f "${defuser_conffile}" && get_conf "${defuser_conffile}"
test -f "${default_conffile}" && get_conf "${default_conffile}"

## START READ CONFIG FILE TEMPLATE
#oIFS="${IFS}"; IFS="$( printf '\n' )"
#infiledata=$( ${sed} ':loop;/^\/\*/{s/.//;:ccom;s,^.[^*]*,,;/^$/n;/^\*\//{s/..//;bloop;};bccom;}' "${infile1}") #the crazy sed removes c style multiline comments
#IFS="${oIFS}"; infilelines=$( echo "${infiledata}" | wc -l )
#{ echo "${infiledata}"; echo "ENDOFFILE"; } | {
#   while read line; do
#   # the crazy sed removes leading and trailing whitespace, blank lines, and comments
#   if test ! "${line}" = "ENDOFFILE";
#   then
#      line=$( echo "${line}" | sed -e 's/^\s*//;s/\s*$//;/^[#$]/d;s/\s*[^\]#.*$//;' )
#      if test -n "${line}";
#      then
#         debuglev 8 && ferror "line=\"${line}\""
#         if echo "${line}" | grep -qiE "\[.*\]";
#         then
#            # new zone
#            zone=$( echo "${line}" | tr -d '[]' )
#            debuglev 7 && ferror "zone=${zone}"
#         else
#            # directive
#            varname=$( echo "${line}" | awk -F= '{print $1}' )
#            varval=$( echo "${line}" | awk -F= '{$1=""; printf "%s", $0}' | sed 's/^ //;' )
#            debuglev 7 && ferror "${zone}${varname}=\"${varval}\""
#            # simple define variable
#            eval "${zone}${varname}=\${varval}"
#         fi
#         ## this part is untested
#         #read -p "Please type something here:" response < ${thistty}
#         #echo "${response}"
#      fi
#   else

## REACT TO BEING A CRONJOB
#if test ${is_cronjob} -eq 1;
#then
#   [ ]
#else
#   [ ]
#fi

# SET TRAPS
#trap "CTRLC" 2
#trap "CTRLZ" 18
#trap "clean_dhcpdcontrol" 0

# MAIN LOOP
#{

   # use DHCPD_CONTROL_COMBINED_FILE and DHCPD_CONTROL_DHCPD_FILE

   # derive if primary or secondary server
   is_primary="$( sed -n -r -e '/failover.*\{/,/\}/p' ${DHCPD_CONTROL_DHCPD_FILE} | grep -iE "^\s*primary" )"
   if ! test -n "${is_primary}";
   then
      if ! fistruthy "${DHCPD_CONTROL_FORCE}";
      then
         ferror "${scriptfile}: 4. Canot determine that this is the primary server. Try --force option. Aborted."
         exit 4
      fi
   fi

   # Derive secondary server for later actions
   define_if_new DHCPD_CONTROL_OTHER_SERVER "$( grep -oiE "peer address [0-9.]{7,15}\s*;" "${DHCPD_CONTROL_DHCPD_FILE}" | tr -dc '[0-9.]' )"
   
   # DEBUG SIMPLECONF
   debuglev 5 && {
      ferror "Using values"
      # used values: EX_(OPT1|OPT2|VERBOSE)
      set | grep -iE "^DHCPD_CONTROL_" 1>&2
   }

   please_update_other_server_conf=0
   please_update_other_server_leases=0
   please_update_other_server_service=0
   # WORKHERE: add local service, other_server_service
   case "${action}" in

      "flush")
         # Clear temorary leases file
         debuglev 4 && ferror "Flushing all leases"
         if test -z "${DHCPD_CONTROL_LEASES_TEMP_FILE}";
         then
            ferror "Skipping leases temp file. Variable not defined: DHCPD_CONTROL_LEASES_TEMP_FILE."
         else
            if test -f "${DHCPD_CONTROL_LEASES_TEMP_FILE}";
            then
               case "${DHCPD_CONTROL_LEASES_TEMP_FILE}" in
                  /var/lib/dhcp*)
                     rm -f "${DHCPD_CONTROL_LEASES_TEMP_FILE}"
                     please_update_other_server_conf=1
                     ;;
                  *)
                     ferror "Will not delete unsafe leases temp file ${DHCPD_CONTROL_LEASES_TEMP_FILE}."
                     ;;
               esac
            fi
         fi
         # Clear leases file
         if test -z "${DHCPD_CONTROL_LEASES_FILE}";
         then
            ferror "Skipping leases file. Variable not defined: DHCPD_CONTROL_LEASES_FILE."
         else
            if test -f "${DHCPD_CONTROL_LEASES_FILE}";
            then
               case "${DHCPD_CONTROL_LEASES_FILE}" in
                  /var/lib/dhcp*)
                     printf "" > "${DHCPD_CONTROL_LEASES_FILE}"
                     please_update_other_server_conf=1
                     ;;
                  *)
                     ferror "Will not clear unsafe leases file ${DHCPD_CONTROL_LEASES_FILE}."
                     ;;
               esac
            fi
         fi
         ;;
   esac

   # Update other server if necessary
   if fistruthy "${please_update_other_server}";
   then
      if test -n "${DHCPD_CONTROL_OTHER_SERVER}";
      then
         echo "please notify other server ${DHCPD_CONTROL_OTHER_SERVER}"
      fi
   fi

#} | tee -a ${logfile}

# EMAIL LOGFILE
#${sendsh} ${sendopts} "${server} ${scriptfile} out" ${logfile} ${interestedparties}

## STOP THE READ CONFIG FILE
#exit 0
#fi; done; }
