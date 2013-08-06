#!/bin/bash
# makeCIBls.sh
# https://github.com/vanillaSprinkles/countryipblocks_automation
# generate a list from www.countryipblocks.net
# ver .2
# 2013-08-05.21.28
# ver .1
# 2013-08-02.20.18

SREPO="https://github.com/vanillaSprinkles/countryipblocks_automation"


# load config
source "${0%/*}/CIBls.conf"
APP="makeCIBls"
APPf="countryipblocks automation"
APPFinalOutput="/tmp/${APP}.final.outs.txt"

TWDIR="/tmp/${APP}"

DEBUG=0
# 0 download and normal ops (silent)
# 1 print Header Formatting (skip header-format-download, exit after prints)
# 2 print Post Formatting   (skip header-format-download. attempts Post download)

function help () {
cat <<EOF 1>&2
invalid paramater(s):
                      ${@}
${0##*/}
  prints to stdout
  makes temp-output file "${APPFinalOutput}"
${0##*/} (*)(print)(*)
  debug method, prints temp-output file and exits
EOF
exit 1
}


arg1=${1,,}
if [[ -n "${@}" ]]; then
#if [[ "${@,,}" =~ "-help" ]]; then
  if [[ "${@,,}" =~ "print" ]]; then cat "${APPFinalOutput}"; exit 0; fi
  help "${@}"
fi


while [[ $rv -lt 15 ]]; do rv=$((RANDOM %23)); done
AGENT="Mozilla/5.0 (Windows NT 6.1; WOW64; rv:${rv}.0) Gecko/20100101 Firefox/${rv}.0"
#AGENT="Mozilla/5.0 (Windows NT 6.1; WOW64; rv:18.0) Gecko/20100101 Firefox/18.0"
URL="https://www.countryipblocks.net/country_selection.php"
REFERER="${URL}"



# create work dir
mkdir -p ${TWDIR}
if ! [ -d ${TWDIR} ] || ! [ -w ${TWDIR} ]; then
    echo "cannot write to ${TWDIR}; premature exit"
    exit 1
fi
DLFILE=${TWDIR}/${APP}.grepme
CKFILE=${TWDIR}/${APP}.cookies

if test $DEBUG -eq 0; then
  wget --no-check-certificate --quiet -q --user-agent="${AGENT}" --referer=${REFERER} --keep-session-cookies --save-cookies ${CKFILE} ${URL} -O ${DLFILE} 2>/dev/null
  tr -d '\015' < ${DLFILE} > ${DLFILE}.unix
  mv -f ${DLFILE}.unix  ${DLFILE}
fi


## get formatI ##
# list formats => not pretty
# grep -Eo ".format1.\s*value=.[0-9]*.\s*.*radio.>.*</\s*label\s*>" ${DLFILE}
REGEX="^[0-9][0-9]*$"
if [[ "${format}" =~ ${REGEX} ]]; then
  formatI=${format}
else
  FORMATSrough=$(grep -Eo ".format1.\s*value\s*=.[0-9]*.\s*.*radio.>.*</\s*label\s*>" ${DLFILE})
  formatI=$(echo ${FORMATSrough} | grep -Eio "value=.[0-9]*.\s.*>${format}<"  | sed 's/value=.\([0-9]*\) *.*/\1/g' )
  if [ -z "$formatI"  ]; then
    echo "bad format=\"${format}\""
    exit 1
  fi
fi
## end get formatI
if test $DEBUG -eq 1; then echo -e 'formatI: "'${formatI}'"'"\n"; fi




## get countriesS ##
# list countries => not pretty
#NO# grep -Eo "option\s\s*value\s*=\s*.[a-Z]*.\s\s*title\s*=\s*.Country: [A-Z]*.>[A-Z]*<"
# grep -Eo "option\s\s*value\s*=\s*.[a-Z]*.\s\s*title\s*=\s*.Country:\s.*.>.*<"
country="${countries[5]}"
CsRough=$(grep -Eo "option\s\s*value\s*=\s*.[a-Z]*.\s\s*title\s*=\s*.Country:\s.*.>.*<" ${DLFILE} ) 
#CFr=$( echo "$CsRough" | grep -Ei ">\s*.*${country}.*<" )  ## can get multiple countries ##
CF=()
for country in "${countries[@]}"; do
  CFr=$( echo "$CsRough" | grep -Ei ">\s*${country}[\s,]{1}*.*<" )  #| head -n 1)  # want multiple, 'korea' ?
  CF+=($(echo "$CFr" | sed 's/^option\svalue\s*=\s*.\([A-Z]*\).*$/\1/g' | grep -Eo "^[A-Z][A-Z]*" ))
done

if test $DEBUG -eq 1; then echo -e 'countries: "'${CF[@]}'"'"\n"; fi
## end get countriesS ##


## create "header"
h1='countries%5B%5D='
h2="format1=${formatI}&get_acl=Create+ACL"
Hf=""
for Cid in "${CF[@]}"; do
  Hf+="${h1}${Cid}&"
done
Hf+="${h2}"
## end create "header"
if test $DEBUG -eq 1; then echo -e '"header:" "'${Hf}'"'"\n"; exit 2; fi





## get The List 
# POST https://www.countryipblocks.net/country_selection.php 
# Content-Type: application/x-www-form-urlencoded
# Content-Length: 66 [ str len ]
#
# countries%5B%5D=CL&countries%5B%5D=ID&format1=1&get_acl=Create+ACL

if test $DEBUG -eq 0 || test $DEBUG -eq 2; then
  H1="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
  H2="Accept-Language: en-US,en;q=0.5"
  H3="Accept-Encoding: gzip, deflate"
  
  ## BOGONS
  BOGON="${bogons##*/_ipv4_bogons}"
  BURL="https://www.countryipblocks.net/bogons/${BOGON}_ipv4_bogons.txt"
  wget --no-check-certificate --quiet -q --user-agent="${AGENT}"  --referer="https://www.countryipblocks.net/bogons.php" -p ${BURL} -O ${DLFILE}.bogons #2>/dev/null

  # URL="http://www.countryipblocks.net/country_selection.php"
  wget --no-check-certificate --quiet -q --user-agent="${AGENT}" --header="${H1}" --header="${H2}" --header="${H3}"  --referer=${REFERER} --load-cookies "${CKFILE}" --post-data="${Hf}" -p ${URL} -O ${DLFILE}.2 #2>/dev/null
  ## DOWNLOAD IS COMPRESSED GZIP
  gunzip  -cd  ${DLFILE}.2 > ${DLFILE}.extr

  # append bogons, sort by ip later
  cat ${DLFILE}.extr  ${DLFILE}.bogons > ${DLFILE}
  rm -f ${DLFILE}.2 ${DLFILE}.bogons ${DLFILE}.extr
fi
## end get The List



## output the list
echo -e "# ${APPf}\n# maintained at:\n# ${SREPO}\n#\n# ${APPFinalOutput}\n" > "${APPFinalOutput}"
grep -Eo "^#.*"  ${DLFILE} >> "${APPFinalOutput}"
# quick sort IP via: http://larsmichelsen.com/open-source/quickie-sort-ip-addresses-on-linux-command-line-bash/
# -t .: Use dot as field seperator. -k 1,1n: First sort key is field 1, sort it numeric
grep -Eo "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}" ${DLFILE} | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n >> "${APPFinalOutput}"
cat "${APPFinalOutput}"
## end output the list


## cleanup
rm -rf "${TWDIR}"
## end cleanup
