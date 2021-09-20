#!/usr/bin/env bash
#
# Take TikTok videos to your local machine
#
#/ Usage:
#/   ./tiktook.sh -u <username> [-d] [-c] [-v] [-f <yyyymmdd>] [-t <yyyymmdd>]
#/
#/ Options:
#/   -u               required, TikTok username
#/   -d               optional, skip json data download
#/   -c               optional, skip cover download
#/   -v               optional, skip video download
#/   -f <yyyymmdd>    optional, from date, format yyyymmdd
#/   -t <yyyymmdd>    optional, to date, format yyyymmdd

set -e
set -u

usage() {
    printf "%b\n" "$(grep '^#/' "$0" | cut -c4-)" >&2 && exit 1
}

set_var() {
    _HOST="https://www.tiktok.com"
    _ITEM_API="https://m.tiktok.com/share/item/list?count=30&type=1&minCursor=0&shareUid=&lang="
    _USER_AGENT="tiktok"
    _COOKIE="tt_webid=tiktok"
    _SCRIPT_PATH=$(dirname "$0")
    _TIME_STAMP=$(date +%s)
    _OUT_DIR="${_SCRIPT_PATH}/${_USER_NAME}_${_TIME_STAMP}"
    _DATA_DIR="$_OUT_DIR/data"
    _COVER_DIR="$_OUT_DIR/cover"
    _VIDEO_DIR="$_OUT_DIR/video"
    _SIGN_SCRIPT="$_SCRIPT_PATH/bin/sign.js"

    mkdir -p "$_OUT_DIR"
    [[ "$_SKIP_JSON_DATA" == false ]] && mkdir -p "$_DATA_DIR"
    [[ "$_SKIP_COVER" == false ]] && mkdir -p "$_COVER_DIR"
    [[ "$_SKIP_VIDEO" == false ]] && mkdir -p "$_VIDEO_DIR"

    if [[ -z "${_FROM_DATE:-}" ]]; then
        _FROM_DATE_UNIXTIME=$(date +%s -d "20160101")
    else
        _FROM_DATE_UNIXTIME=$(date +%s -d "$_FROM_DATE")
    fi
    if [[ -z "${_TO_DATE:-}" ]]; then
        _TO_DATE_UNIXTIME="$_TIME_STAMP"
    else
        _TO_DATE_UNIXTIME=$(date +%s -d "$_TO_DATE")
    fi
}

set_command() {
    _CURL="$(command -v curl)" || command_not_found "curl" "https://curl.haxx.se/download.html"
    _JQ="$(command -v jq)" || command_not_found "jq" "https://stedolan.github.io/jq/download/"
}

set_args() {
    expr "$*" : ".*--help" > /dev/null && usage
    _SKIP_JSON_DATA=false
    _SKIP_COVER=false
    _SKIP_VIDEO=false
    while getopts ":hdcvu:f:t:" opt; do
        case $opt in
            u)
                _USER_NAME="$OPTARG"
                ;;
            d)
                _SKIP_JSON_DATA=true
                ;;
            c)
                _SKIP_COVER=true
                ;;
            v)
                _SKIP_VIDEO=true
                ;;
            f)
                _FROM_DATE="$OPTARG"
                ;;
            t)
                _TO_DATE="$OPTARG"
                ;;
            h)
                usage
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                ;;
        esac
    done
}

print_info() {
    # $1: info message
    printf "%b\n" "\033[32m[INFO]\033[0m $1" >&2
}

print_warn() {
    # $1: warning message
    printf "%b\n" "\033[33m[WARNING]\033[0m $1" >&2
}

print_error() {
    # $1: error message
    printf "%b\n" "\033[31m[ERROR]\033[0m $1" >&2
    exit 1
}

command_not_found() {
    # $1: command name
    # $2: installation URL
    if [[ -n "${2:-}" ]]; then
        print_error "$1 command not found! Install from $2"
    else
        print_error "$1 command not found!"
    fi
}

check_arg() {
    if [[ -z "${_USER_NAME:-}" ]]; then
        print_error "-u <username> is missing!"
    fi

    if [[ -n "${_FROM_DATE:-}" ]]; then
        if [[ (! "$_FROM_DATE" =~ ^[[:digit:]]{8}$) ]]; then
            print_error "-f $_FROM_DATE, wrong date format, must be yyyymmdd!"
        else
            date +%s -d "$_FROM_DATE" > /dev/null
        fi
    fi

    if [[ -n "${_TO_DATE:-}" ]]; then
        date +%s -d "$_TO_DATE" >/dev/null 2>&1 || true
        if [[ (! "$_TO_DATE" =~ ^[[:digit:]]{8}$) ]]; then
            print_error "-t $_TO_DATE, wrong date format, must be yyyymmdd!"
        else
            date +%s -d "$_TO_DATE" > /dev/null
        fi
    fi

    if [[ -n "${_FROM_DATE:-}"  && -n "${_TO_DATE:-}" ]]; then
        if [[ $(compare_time "$_FROM_DATE" "$_TO_DATE") == ">" ]]; then
            print_error "-t ${_TO_DATE} is earlier than -f ${_FROM_DATE}!"
        fi
    fi
}

is_item_list_empty() {
    # $1: item list json data
    local o
    o="yes"
    [[ "$($_JQ -r '.body.itemListData | length' <<< "$1")" -gt 0 ]] && o="no"
    echo "$o"
}

download_content() {
    # $1: item list json data
    local l j id c v
    l=$($_JQ -r '.body.itemListData | length' <<< "$1")
    for (( i = 0; i < l; i++ )); do
        j=$($_JQ -r '.body.itemListData[$i | tonumber]' --arg i "$i" <<< "$1")
        id=$($_JQ -r '.itemInfos.id' <<< "$j")
        ts=$($_JQ -r '.itemInfos.createTime' <<< "$j")
        c=$($_JQ -r '.itemInfos.coversDynamic[0]' <<< "$j")
        v=$($_JQ -r '.itemInfos.video.urls[0]' <<< "$j")

        if [[ $(compare_time "$ts" "$_FROM_DATE_UNIXTIME") != "<" && $(compare_time "$ts" "$_TO_DATE_UNIXTIME") != ">" ]]; then
            [[ "$_SKIP_JSON_DATA" == false ]] && echo "$j" > "$_DATA_DIR/${id}.json"

            if [[ "$_SKIP_COVER" == false ]]; then
                print_info ">> Downloading cover $id"
                $_CURL -L -g -o "$_COVER_DIR/${id}.gif" "$c"
            fi

            if [[ "$_SKIP_VIDEO" == false ]]; then
                print_info ">> Downloading video $id"
                $_CURL -L -g -o "$_VIDEO_DIR/${id}.mp4" -H "Referer: $v" "$v"
            fi
         else
            if [[ $(compare_time "$ts" "$_FROM_DATE_UNIXTIME") == "<" ]]; then
                print_info "Skip further download: media are published earlier than ${_FROM_DATE_UNIXTIME}"
                exit 0
            fi
            print_info "Skip download: media isn't published in the time period ${_FROM_DATE_UNIXTIME}-${_TO_DATE_UNIXTIME}"
        fi
    done
}

compare_time() {
    # $1: timestamp/date 1
    # $2: timestamp/date 2
    if [[ "$1" -eq "$2" ]]; then
        echo "="
    elif [[ "$1" -gt "$2" ]]; then
        echo ">"
    elif [[ "$1" -lt "$2" ]]; then
        echo "<"
    fi
}

get_user_data() {
    # $1: tiktok handle
    local u
    if [[ "$1" == "@"* ]]; then
        u="$1"
    else
        u="@$1"
    fi
    $_CURL -sS "$_HOST/${u}" -H "User-Agent: $_USER_AGENT" \
    | grep '"props":' \
    | sed -E 's/.*\{"props"/{"props"/' \
    | sed -E 's/\}<.*/}/' \
    | "$_JQ" -r
}

json_path() {
    # $1: JSON data
    "$_JQ" -r 'paths(scalars) as $p | "." + ([([$p[] | tostring] | join(".")), (getpath($p) | tojson)] | join(": "))'
}

get_signature() {
    # $1: URL
    # $2: user agent
    $_SIGN_SCRIPT "$1" "$2"
}

get_item() {
    # $1: id
    # $2: secUid
    # $3: maxCursor
    # $4: user agent
    local u s l
    u="${_ITEM_API}&id=${1}&secUid=${2}&maxCursor=${3}"
    s=$(get_signature "$u" "$4")
    l="${u}&_signature=${s}"
    print_info ">> Fetching item list: $l"
    $_CURL -sS "$l" -H "User-Agent: $4" -H "Cookie: $_COOKIE"
}

get_fp_token() {
    $_CURL "$_HOST" -H "User-Agent: $_USER_AGENT"
}

main() {
    set_args "$@"
    check_arg
    set_command
    set_var

    local data uid secuid maxcur res

    data=$(get_user_data "$_USER_NAME")
    [[ "$_SKIP_JSON_DATA" == false ]] && echo "$data" > "$_DATA_DIR/userdata.json"

    uid=$(json_path <<< "$data" | grep "author.id" | tail -1 | awk -F '"' '{print $2}')
    secuid=$(json_path <<< "$data" | grep "author.secUid" | tail -1 | awk -F '"' '{print $2}')
    maxcur="0"

    print_info "id: $uid"
    print_info "secUid: $secuid"
    print_info "user-agent: $_USER_AGENT"

    while true; do
        print_info "maxCursor: $maxcur"
        res=$(get_item "$uid" "$secuid" "$maxcur" "$_USER_AGENT")
        [[ -z "$res" ]] && print_error "Empty response!"
        if [[ $(is_item_list_empty "$res") == "no" ]]; then
            download_content "$res"
            maxcur="$($_JQ -r '.body.maxCursor' <<< "$res")"
        else
            print_info "~ FIN ~"
            break
        fi
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
