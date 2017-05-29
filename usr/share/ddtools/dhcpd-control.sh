#!/bin/sh
# Filename: dhcpd-control.sh
# Location: 
# Author: bgstack15@gmail.com
# Startdate: 2017-05-28 18:18:46
# Title: Script that Facilitates the Configuration of DHCPD Across a Server Pair
# Purpose: Provides a single command for would take a series of steps
# Package: ddtools
# History: 
# Usage: 
# Reference: ftemplate.sh 2017-05-24a; framework.sh 2017-05-24a
#    order of dhcpd servers to restart https://kb.isc.org/article/AA-01043/0/Recommendations-for-restarting-a-DHCP-failover-pair.html
#    merge lines with sed http://www.linuxquestions.org/questions/programming-9/merge-lines-in-a-file-using-sed-191121/
# Improve:
#    provide mechanisms for non-systemd service control
# Dependencies:
#    systemd
fiversion="2017-05-24a"
dhcpdcontrolversion="2017-05-29a"

usage() {
   less -F >&2 <<ENDUSAGE
usage: dhcpd-control.sh [-duV] [ --flush | --edit | --edit-local | --edit-other | --remove-mac <mac> ] [ --force ]
version ${dhcpdcontrolversion}
 -d debug   Show debugging info, including parsed variables.
 -u usage   Show this usage block.
 -V version Show script version number.
 --flush    Clears all current leases
 --edit     Edit the combined file-- the one shared by both servers.
 --edit-local Edit the local file.
 --edit-other Edit the other server dhcpd file.
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
   {
      rm -f ${tmp_dhcpd_combined_file} ${tmp_dhcpd_local_file} ${tmp_dhcpd_other_file} ${tmp_mac_local_file} ${tmp_macless_local_file}
   } 1>/dev/null 2>&1
   #use at end of entire script if you need to clean up tmpfiles
}

CTRLC() {
   #trap "CTRLC" 2
   clean_dhcpdcontrol
   #useful for controlling the ctrl+c keystroke
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
      "edit-other" ) action="edit-other";;
      "edit" ) action="edit";;
      "remove-mac" ) getval; DHCPD_CONTROL_MAC_TO_REMOVE="${tempval}"; action="remove-mac";;
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
# WORKHERE: fix sysconfig call to normal spot
define_if_new default_conffile "/home/bgirton/rpmbuild/SOURCES/ddtools-0.0-2/etc/sysconfig/dhcpd-control"
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
trap "CTRLC" 2
#trap "CTRLZ" 18
trap "clean_dhcpdcontrol" 0

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

   update_conf_local=0
   update_leases_local=0
   restart_service_local=0
   update_conf_other=0
   update_leases_other=0
   restart_service_other=0
   debuglev 8 && ferror "BEGIN action ${action}"
   case "${action}" in

      "flush")
         debuglev 8 && ferror "BEGIN flush"
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
                     systemctl stop "${DHCPD_CONTROL_SERVICE}"
                     rm -f "${DHCPD_CONTROL_LEASES_TEMP_FILE}"
                     update_leases_other=1;
                     restart_service_other=1;
                     restart_service_local=1;
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
                     systemctl stop "${DHCPD_CONTROL_SERVICE}"
                     printf "" > "${DHCPD_CONTROL_LEASES_FILE}"
                     update_leases_other=1;
                     restart_service_other=1;
                     restart_service_local=1;
                     ;;
                  *)
                     ferror "Will not clear unsafe leases file ${DHCPD_CONTROL_LEASES_FILE}."
                     ;;
               esac
            fi
         fi
         ;;

      "edit")
         debuglev 8 && ferror "BEGIN edit"
         # prepare temp file
         tmp_dhcpd_combined_file="$( mktemp -p /tmp dhcpd.combined.XXXXX )"
         cp -p "${DHCPD_CONTROL_COMBINED_FILE}" "${tmp_dhcpd_combined_file}"
         # edit file
         $EDITOR "${tmp_dhcpd_combined_file}"
         # if change occurred, prepare to replace
         if ! cmp -s "${DHCPD_CONTROL_COMBINED_FILE}" "${tmp_dhcpd_combined_file}";
         then
            debuglev 1 && ferror "Updating dhcpd combined file."
            /usr/share/bgscripts/bup.sh "${DHCPD_CONTROL_COMBINED_FILE}"
            cp -p "${tmp_dhcpd_combined_file}" "${DHCPD_CONTROL_COMBINED_FILE}"
            update_conf_other=1
            restart_service_local=1
            restart_service_other=1
         fi
         ;;

      "edit-local")
         debuglev 8 && ferror "BEGIN edit-local"
         # prepare temp file
         tmp_dhcpd_local_file="$( mktemp -p /tmp dhcpd.XXXXX )"
         cp -p "${DHCPD_CONTROL_DHCPD_FILE}" "${tmp_dhcpd_local_file}"
         $EDITOR "${tmp_dhcpd_local_file}"
         # if change occurred, prepare to replace
         if ! cmp -s "${DHCPD_CONTROL_DHCPD_FILE}" "${tmp_dhcpd_local_file}";
         then
            debuglev 1 && ferror "Updating local dhcpd file."
            /usr/share/bgscripts/bup.sh "${DHCPD_CONTROL_DHCPD_FILE}"
            cp -p "${tmp_dhcpd_local_file}" "${DHCPD_CONTROL_DHCPD_FILE}"
            restart_service_local=1
         fi
         ;;

      "edit-other")
         debuglev 8 && ferror "BEGIN edit-other"
         tmp_dhcpd_other_file="$( mktemp -p /tmp dhcpd.other.XXXXX )"
         scp -p "${DHCPD_CONTROL_OTHER_SERVER}:${DHCPD_CONTROL_DHCPD_FILE}" "${tmp_dhcpd_other_file}"
         cp -p "${tmp_dhcpd_other_file}" "${tmp_dhcpd_other_file}8" #arbitrary number # edit file
         ${EDITOR} "${tmp_dhcpd_other_file}8"
         if ! cmp -s "${tmp_dhcpd_other_file}" "${tmp_dhcpd_other_file}8";
         then
            debuglev 1 && ferror "Updating other server dhcpd file."
            ssh "${DHCPD_CONTROL_OTHER_SERVER}" /usr/share/bgscripts/bup.sh "${DHCPD_CONTROL_DHCPD_FILE}";
            scp -p "${tmp_dhcpd_other_file}8" "${DHCPD_CONTROL_OTHER_SERVER}:${DHCPD_CONTROL_DHCPD_FILE}";
            restart_service_other=1
         fi
         ;;

      "remove-mac")
         debuglev 8 && ferror "BEGIN remove-mac"
         # working on this
         # WORKHERE: verify that doing it on local is sufficient.
         # sed -n -r -e '/^lease.*\{/,/^\}/{/^lease|hardware|\}/{p}}' /tmp/foo1 | sed -e ':a;/\}/!{N;s/\n/ /;ba};' # base form
         # sed -n -r -e '/^lease.*\{/,/^\}/{p}' /tmp/foo1 | sed -e ':a;/\}/!{N;s/\n/ /;ba};' -e 's/\s\+/ /g;' # slightly trimmed
         # sed -n -r -e '/\{/,/^\}/{p}' /tmp/foo1 | sed -e ':a;/\}/!{N;s/\n/ /;ba};' -e 's/\s\+/ /g;' | grep -iE "ec:9a:74:48:bc:c4" # find the one mac address
         tmp_mac_local_file="$( mktemp -p /tmp leases.mac.XXXXX )"
         tmp_macless_local_file="$( mktemp -p /tmp leases.macless.XXXXX )"
         if test -z "${DHCPD_CONTROL_MAC_TO_REMOVE}";
         then
            ferror "${scripttrim}: 2. No MAC address provided. aborted."
            exit 2
         fi
         sed -n -r -e '/\{/,/^\}/{p}' "${DHCPD_CONTROL_LEASES_FILE}" | sed -e ':a;/\}/!{N;s/\n/ /;ba};' -e 's/\s\+/ /g;' | grep -iE "${DHCPD_CONTROL_MAC_TO_REMOVE}" > "${tmp_mac_local_file}"
         if test -n "$( cat "${tmp_mac_local_file}" )";
         then
            ferror "Removing leases:"
            cat "${tmp_mac_local_file}" 1>&2
         fi
         sed -n -r -e '/\{/,/^\}/{p}' "${DHCPD_CONTROL_LEASES_FILE}" | sed -e ':a;/\}/!{N;s/\n/ /;ba};' -e 's/\s\+/ /g;' | grep -viE "${DHCPD_CONTROL_MAC_TO_REMOVE}" > "${tmp_macless_local_file}"
         if ! cmp -s "${tmp_macless_local_file}" "${DHCPD_CONTROL_LEASES_FILE}"
         then
            systemctl stop "${DHCPD_CONTROL_SERVICE}"
            cp -p "${tmp_macless_local_file}" "${DHCPD_CONTROL_LEASES_FILE}"
            restart_service_local=1
         fi
         ;;

   esac

   # Prepare instructions for other server
   debuglev 8 && ferror "BEGIN prepare instructions for other server"
   local_instructions=""
   other_instructions=""
   instructions=""
   fistruthy "${update_leases_other}" && \
      other_instructions="${other_instructions}systemctl stop ${DHCPD_CONTROL_SERVICE}\; rm -f ${DHCPD_CONTROL_LEASES_TEMP_FILE}\; echo \"\" \> ${DHCPD_CONTROL_LEASES_FILE}\; "
   fistruthy "${update_conf_other}" && \
      local_instructions="${local_instructions}scp ${DHCPD_CONTROL_COMBINED_FILE} ${DHCPD_CONTROL_OTHER_SERVER}:${DHCPD_CONTROL_COMBINED_FILE}; "
   fistruthy "${restart_service_local}" && \
      instructions="${instructions}systemctl restart ${DHCPD_CONTROL_SERVICE}.service"
   fistruthy "${restart_service_other}" && \
      other_instructions="${other_instructions}systemctl restart ${DHCPD_CONTROL_SERVICE}"

   # Instruct other server to act
   debuglev 8 && ferror "BEGIN instruct other server to act"
   if test -n "${DHCPD_CONTROL_OTHER_SERVER}";
   then
      debuglev 1 && {
         test -n "${local_instructions}" && {
            ferror "run local commands:"
            ferror "${local_instructions}"
         }
         test -n "${other_instructions}" && { 
            ferror "run on other server ${DHCPD_CONTROL_OTHER_SERVER}:"
            ferror "ssh ${DHCPD_CONTROL_OTHER_SERVER} ${other_instructions}"
         }
      }
      test -n "${local_instructions}" && ${local_instructions}
      test -n "${other_instructions}" && ssh ${DHCPD_CONTROL_OTHER_SERVER} eval ${other_instructions}
   fi

   # Local actions regardless of other server
   if test -n "${instructions}";
   then
      debuglev 1 && {
         ferror "run commands:"
         ferror "${instructions}"
      }
      ${instructions}
   fi

#} | tee -a ${logfile}

# EMAIL LOGFILE
#${sendsh} ${sendopts} "${server} ${scriptfile} out" ${logfile} ${interestedparties}

## STOP THE READ CONFIG FILE
#exit 0
#fi; done; }
