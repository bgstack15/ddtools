#!/bin/sh
# Filename: updatezone.sh
# Location: 
# Author: bgstack15@gmail.com
# Startdate: 2017-05-26 07:02:47
# Title: Script that Updates a DNS Zone
# Purpose: Provides a single command to update dns zones
# Package: updatezone
# History: 
# Usage: 
#    Primarily intended for updating forward and reverse zones for bind9.
# Reference: ftemplate.sh 2017-05-24a; framework.sh 2017-05-24a
# Improve:
# Dependencies:
#    rndc 
#    ssh with password-less authentication to slave servers
#    each zone file has only a single zone
fiversion="2017-05-24a"
updatezoneversion="2017-05-27a"

usage() {
   less -F >&2 <<ENDUSAGE
usage: updatezone.sh [-duV] [ -c conffile | zone1 zone2 ... ]
version ${updatezoneversion}
 -d debug   Show debugging info, including parsed variables.
 -u usage   Show this usage block.
 -V version Show script version number.
 -c conffile Choose which conffile. Required if you do not name specific zones
 zone1      Dns zone defined as UZ_ZONE_NAME in any .conf file in ${default_dir}/
Return values:
0 Normal
1 Help or version info displayed
2 Count or type of flaglessvals is incorrect
3 Incorrect OS type
4 Unable to find dependency
5 Not run as root or sudo
6 Invalid configuration
7 Unable to modify zone files
ENDUSAGE
}

# DEFINE FUNCTIONS

check_zone_file() {
   # call: check_zone_file forward "${zone_name}" "${forward_file}" "{temp_forward_file}"
   debuglev 9 && ferror "check_zone_file $@"
   local zone_type="$1"
   local zone_name="$2"
   local zone_real_file="$3"
   local zone_temp_file="$4"

   # if this zone is defined
   if test -n "${zone_real_file}";
   then
      # if this zone file does not exist
      if test ! -f "${zone_real_file}";
      then
         ferror "${scriptfile}: 6. Cannot find file: ${zone_real_file}. Skipping ${zone_type} zone."
         pause_to_show_error=1
         rm -f "${zone_temp_file}"
      else
      # so the zone file exists

         # make sure we can modify it
         if ! touch "${zone_real_file}";
         then
            ferror "${scriptfile}: 7. Unable to modify zone file ${zone_real_file}. Aborted."
            exit 7
         fi

         # freeze zone so the file is up to date
         zone_action freeze "${zone_name}"
         echo "${zone_name}" >> "${zones_to_thaw_file}"

         # prepare temp file
         cp -p "${zone_real_file}" "${zone_temp_file}"
      fi
   fi
}

zone_action() {
   # call: zone_action ${forwardzone}
   debuglev 9 && ferror "zone_action $@"
   local action="$1"
   local zone="$2"
   case "${action}" in
      freeze|thaw)
         rndc "${action}" "${zone}" 2>&1 | grep -viE "a zone reload and thaw|Check the logs to see"
         ;;
      *)
         ferror "${scriptfile} minor error: ignoring unknown zone_action $@"
         ;;
   esac
}

update_real_zone_if_updated() {
   # call: update_real_zone_if_updated "${UZ_REVERSE_ZONE}" "${UZ_REVERSE_FILE}" "${temp_rev_file}"
   debuglev 9 && ferror "update_real_zone_if_updated $@"
   local zone_name="$1"
   local zone_real_file="$2"
   local zone_temp_file="$3"
   if test -n "${zone_temp_file}" && test -f "${zone_temp_file}";
   then
      if ! cmp -s "${zone_real_file}" "${zone_temp_file}";
      then
         # a change occurred, so increment the serial number and replace the original zone file
         increment_serial_in_zone_file "${zone_temp_file}"
         cat "${zone_temp_file}" > "${zone_real_file}"

         # plan to notify the dns slaves
         echo "${zone_name}" >> "${zones_to_update_file}"
      fi
   fi

   # If the temp file does not exist, it was deleted because the real file was invalid for whatever reason.
}

increment_serial_in_zone_file() {
   # call: increment_serial_in_zone_file "${zone_temp_file}"
   # dependencies: a single zone in the zone file, with the ";serial" comment after the number.
   debuglev 9 && ferror "increment_serial_in_zone_file $@"
   local infile="$1"
   currentnum="$( grep -iE "[0-9]+\s*;\s*serial" "${infile}" | grep -oIE "[0-9]+" )"
   nextnum=$(( currentnum + 1 ))
   sed -i -r -e "s/${currentnum}(\s*;\s*serial)/${nextnum}\1/" "${infile}"
}

# DEFINE TRAPS

clean_updatezone() {
   rm -rf ${tempdir} > /dev/null 2>&1
   [ ] #use at end of entire script if you need to clean up tmpfiles
}

CTRLC() {
   #trap "CTRLC" 2
   [ ] #useful for controlling the ctrl+c keystroke
   exit 0
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
      "V" | "fcheck" | "version" ) ferror "${scriptfile} version ${updatezoneversion}"; exit 1;;
      #"i" | "infile" | "inputfile" ) getval;infile1=${tempval};;
      "c" | "conf" | "config" | "conffile" ) getval;conffile=${tempval};;
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
define_if_new interestedparties "bgstack15@gmail.com"
# SIMPLECONF
#define_if_new default_conffile "/etc/updatezone/updatezone.conf"
#define_if_new defuser_conffile ~/.config/updatezone/updatezone.conf
define_if_new EDITOR vi
define_if_new default_dir "/etc/updatezone"

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

# VALIDATE PARAMETERS
# objects before the dash are options, which get filled with the optvals
# to debug flags, use option DEBUG. Variables set in framework: fallopts
validateparams - "$@"

# CONFIRM TOTAL NUMBER OF FLAGLESSVALS IS CORRECT
#if test ${thiscount} -lt 1;
#then
#   #ferror "${scriptfile}: 2. Fewer than 2 flaglessvals. Aborted."
#   #exit 2
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
#   #if test "${conffile}" = "${default_conffile}" || test "${conffile}" = "${defuser_conffile}"; then :; else
#   ferror "${scriptfile}: Ignoring conf file which is not found: ${conffile}."
#   #fi
#fi
#test -f "${defuser_conffile}" && get_conf "${defuser_conffile}"
#test -f "${default_conffile}" && get_conf "${default_conffile}"

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
trap "clean_updatezone" 0

## DEBUG SIMPLECONF
#debuglev 5 && {
#   ferror "Using values"
#   # used values: EX_(OPT1|OPT2|VERBOSE)
#   set | grep -iE "^UZ_" 1>&2
#}

# MAKE TEMP LOCATIONS
tempdir=/tmp/updatezone/
if ! mkdir -p "${tempdir}";
then
   ferror "${scriptfile}: 4. Unable to make temp directory ${tempdir}. Aborted."
   exit 4
fi

# MAIN LOOP
main() {
   # call: main "${conffile}"
   get_conf "$1"
   # DEBUG SIMPLECONF
   debuglev 5 && {
      ferror "Using values"
      # used values: EX_(OPT1|OPT2|VERBOSE)
      set | grep -iE "^UZ_" 1>&2
   }
   local temp_for_file="$( mktemp -p "${tempdir}" forward.XXXX 2>/dev/null )"
   local temp_rev_file="$( mktemp -p "${tempdir}" reverse.XXXX 2>/dev/null )"
   local zones_to_thaw_file="$( mktemp -p "${tempdir}" thaw.XXXX )"
   local zones_to_update_file="$( mktemp -p "${tempdir}" update.XXXX )"
   for word in "${temp_for_file}" "${temp_rev_file}";
   do
      if test ! -f "${word}";
      then
         ferror "${scriptfile}: 4. Unable to make temp file ${word}. Aborted."
         exit 4
      fi
   done

   local pause_to_show_error=0
   # Check forward zone file and freeze
   check_zone_file forward "${UZ_FORWARD_ZONE}" "${UZ_FORWARD_FILE}" "${temp_for_file}"

   # Check reverse zone file and freeze
   check_zone_file reverse "${UZ_REVERSE_ZONE}" "${UZ_REVERSE_FILE}" "${temp_rev_file}"

   # Slow down to show errors if any
   fistruthy "${pause_to_show_error}" && sleep 1.3

   # Allow user to edit files that exist
   local these_temp_files="$( find "${temp_for_file}" "${temp_rev_file}" 2>/dev/null | xargs )"
   test -n "${these_temp_files}" && $EDITOR ${these_temp_files}

   # Update the real zone if the temp file was updated
   update_real_zone_if_updated "${UZ_FORWARD_ZONE}" "${UZ_FORWARD_FILE}" "${temp_for_file}"
   update_real_zone_if_updated "${UZ_REVERSE_ZONE}" "${UZ_REVERSE_FILE}" "${temp_rev_file}" 
   # Thaw zones that need it
   while read thiszone;
   do
      zone_action thaw "${thiszone}"
   done < "${zones_to_thaw_file}"

   # Transfer zones that need it
   # This section exists because my automatic zone transfers/updates do not work.
   
      # Build list of commands to run on each dns slave server
      transfercommand=""
      while read thiszone;
      do
         transfercommand="${transfercommand}rndc retransfer ${thiszone}; "
      done < "${zones_to_update_file}"

      # Execute command on each slave server
      if test -n "${transfercommand}";
      then
         x=0
         while test ${x} -lt ${UZ_SLAVE_COUNT};
         do
            x=$(( x + 1 ))
            eval this_dns_slave=\"\${UZ_SLAVE_${x}}\"
            debuglev 5 && ferror "ssh ${this_dns_slave} ${transfercommand}"
            ssh ${this_dns_slave} ${transfercommand}
         done
      fi

} #| tee -a ${logfile}


if test -n "${conffile}";
then
   ( main "${conffile}"; )
else
   # assume the $opt items are the zone names
   y=0
   while test $y -lt $thiscount;
   do
      y=$(( y + 1 ))
      eval "thiszonename=\${opt${y}}"
      debuglev 1 && ferror "Will try to update zone ${thiszonename}"
      file_for_this_zone="$( grep -liE "UZ_ZONE_NAME=${thiszonename}" "${default_dir}/"*.conf 2>/dev/null )"
      if test -n "${file_for_this_zone}" && test -f "${file_for_this_zone}";
      then
         ( main "${file_for_this_zone}"; )
      else
         ferror "Skipping zone ${thiszonename} for which no file was found in ${default_dir}/"
      fi
   done
fi

# EMAIL LOGFILE
#${sendsh} ${sendopts} "${server} ${scriptfile} out" ${logfile} ${interestedparties}

## STOP THE READ CONFIG FILE
#exit 0
#fi; done; }
