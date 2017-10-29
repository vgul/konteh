#!/bin/bash

set -u

EFFSCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
MY_DIR="$(dirname "${EFFSCRIPT}")"

if [ "$(id -u)" == "0" ]; then
  CACHE_DIR='/var/cache/konteh'
else
  CACHE_DIR="${MY_DIR}"
fi

TAG="lena"

KONTEH_URL01="https://k.telcom.net.ua/users/sign_in?locale=en"
KONTEH_URL02="https://k.telcom.net.ua/users/sign_in"
KONTEH_URL03="https://k.telcom.net.ua"

UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36'
ROTATE_SIZE=${ROTATE_SIZE:-10}

CONF_FILE='/etc/konteh.conf'
function usage {
  cat << EOC 

  konteh.sh - IP extractor for konteh.com.ua internet provider

  How to run

  konteh.sh [OPTIONS]
    --ip           - print only IP

    --[no-]dry-run - use cached data

    --help         - this help

    --config       - path to config file
          This file should contain variables

            KONTEH_LOGIN=pass
            KONTEH_PASSWD=pass

          Default path: $CONF_FILE

  Curl log files store in \$(pwd)/Data directory 
  or for root user in /var/cache/konteh/Data.
  They are rotate

EOC

}


ONLY_IP=
DRY_RUN=
while [ $# -gt 0 ]; do
    case "$1" in
  
       --help|-h|-\?)
            usage
            exit 0
            ;;

        --dry-run)
            DRY_RUN=1
            shift
            ;;

        --no-dry-run)
            shift
            ;;

        --ip|-i)
            ONLY_IP=1
            shift
            ;;
        -c|--config)
            CONF_FILE=$2
            shift 2
            ;;

        --)
            # Rest of command line arguments are non option arguments
            shift # Discard separator from list of arguments
            continue
            #break # Finish for loop
            ;;

        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 2
            ;;

        *)
            echo "Not expected arguments: $1" >&2
            usage
            exit 2
            # finish parsing options
            #break
    esac
done

function rotate () {
    local FILE="$1"
    local MAX=${2:-90}

    local BODY="$(basename $FILE)"
    local DATA_DIR="$(dirname $FILE)"

    local ROTATE_FLAG=
    [ -e "${FILE}" ] && ROTATE_FLAG=1

    [ -n "${ROTATE_FLAG}" ] && {
      find "${DATA_DIR}" -maxdepth 1 -name ${BODY}\.\* \( -type d -or -type f \) -printf '%f\n' | sort -t '.' -k1 -nr | while read CF; do
        NUM=${CF##*\.}
        #NUM=$(echo ${NUM}|sed -e 's/^0*//g')
        #echo "Found: $CF NUM: $NUM" >&2
        printf -v NEWCF "${BODY}.%d" $((++NUM))
        if ((NUM<=MAX)); then
            [ -d "${DATA_DIR}/${NEWCF}" ] && {
                rm -rf "${DATA_DIR}/${NEWCF}"
            }
          mv "${DATA_DIR}/$CF" "${DATA_DIR}/${NEWCF}"
        else
          [ -e "${DATA_DIR}/$NEWCF" ] && rm -rf "${DATA_DIR}/${NEWCF}"
        fi
      done
      mv "${DATA_DIR}/$BODY"  "${DATA_DIR}/${BODY}.0"
    }
}

function get_data {
    local ACTION="$1"
    local TAG="$2"
    local URL="${3}"
    local METHOD="${4:-GET}"
    local PARAMS="${5:-}"

    local MARKER="${ACTION}-${TAG}"
    local INVOKE_DATA_DIR="${INVOKE_DIR}"

    local DUMP_HEADER="${INVOKE_DATA_DIR}/${MARKER}.headers"
    local DUMP_STDERR="${INVOKE_DATA_DIR}/${MARKER}.stderr"
    local OUTPUT="${INVOKE_DATA_DIR}/${MARKER}.output.html"

    local COOKIES_FILE="${INVOKE_DATA_DIR}/${TAG}.cookies.txt"
    local COOKIES_FILE_TMP="${INVOKE_DATA_DIR}/${TAG}.cookies-tmp.txt"

    local GET_COOKIES=
    local SET_COOKIES=
    
    if [ -f "${COOKIES_FILE}" ]; then
      SET_COOKIES="--cookie     ${COOKIES_FILE}"
    fi
    # you want to store
    GET_COOKIES="--cookie-jar ${COOKIES_FILE_TMP}"

    echo "${URL}" > ${INVOKE_DATA_DIR}/${MARKER}.url

    CURL_CMD="curl \
                    --verbose \
                    --request ${METHOD} \
                    --dump-header ${DUMP_HEADER} \
                    --stderr ${DUMP_STDERR} \
                    --output ${OUTPUT} \
                    ${UA:+ --user-agent \"${UA}\"} \
                    ${PARAMS:+ --data \"${PARAMS}\"} \
                    ${SET_COOKIES:-} \
                    ${GET_COOKIES:-} \
                    ${REFERER:+--referer ${REFERER}} \
                \"${URL}\""

   ((!DRY_RUN)) && eval "${CURL_CMD}"

   [ -f "${COOKIES_FILE_TMP}" ] && {
     mv "${COOKIES_FILE_TMP}" "${COOKIES_FILE}" >&2
   }
    echo "${OUTPUT}"
}

function get_item { 
  local I=$1; 
  cat $OUTPUT | grep -A1 "<td>$I</td>" | tail -1 | sed -e 's/\s*<\/\?td>//g'
}

# Body
if [ -f "${CONF_FILE}" ]; then
  source "${CONF_FILE}"
else
  echo "Credentials are not set. See --help" >&2
  exit 1
fi

DATA_DIR="${CACHE_DIR}/Data"
INVOKE_DIR="${DATA_DIR}/invoke"
((! DRY_RUN)) && rotate "${INVOKE_DIR}" ${ROTATE_SIZE}
((! DRY_RUN)) && mkdir -p "${INVOKE_DIR}"
[ ! -d "${DATA_DIR}" -a ! "$DRY_RUN" ] && { echo dir will be created ;  mkdir ${DATA_DIR} ;}


OUTPUT=$(get_data 'init' "${TAG}" "${KONTEH_URL01}" "GET")
TOKEN="$(cat $OUTPUT | sed -ne '/authenticity_token.*value="/s/.*value="\(\S\+\)".*/\1/p' | sed -e 's/+/%2B/g')"

POST_DATA="authenticity_token=${TOKEN}&user[login]=${KONTEH_LOGIN}&user[password]=${KONTEH_PASSWD}"
get_data 'logon' "${TAG}" "${KONTEH_URL02}" "POST" $POST_DATA > /dev/null

OUTPUT=$(get_data 'final' "${TAG}" "${KONTEH_URL03}" "GET")


ACTIVE="$(get_item 'Active')"
STATUS="$(get_item 'Status')"
BALANCE="$(get_item 'Balance')"
TO_PAY="$(get_item 'To Pay')"
SINCE="$(get_item 'Connected since')"
IP="$(get_item 'IP Address')"


if [ -n "${ONLY_IP}" ]; then
  echo -n $IP
  exit 0
fi

echo "Active:  ${ACTIVE}"
echo "Status:  ${STATUS}"
echo "Balance: ${BALANCE}"
echo "To pay:  ${TO_PAY}"
echo "Since:   ${SINCE}"
echo "IP:      ${IP}"
