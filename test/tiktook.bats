#!/usr/bin/env bats
#
# How to run:
#   ~$ bats test/tiktook.bats

BATS_TEST_SKIPPED=

setup() {
    _SCRIPT="./tiktook.sh"
    _USER_NAME="test_user"
    _USERDATA_JSON_FILE="test/userdata-test.json"
    _ITEM_JSON_FILE="test/item-test.json"
    _EMPTY_ITEM_JSON_FILE="test/empty-item-test.json"
    _COVER_DIR="/tmp/cover"
    _VIDEO_DIR="/tmp/video"
    _SKIP_JSON_DATA=true
    _SKIP_COVER=false
    _SKIP_VIDEO=false
    _FROM_DATE_UNIXTIME="11111010"
    _TO_DATE_UNIXTIME="22221010"

    _JQ=$(command -v jq)
    _CURL=$(command -v echo)

    source $_SCRIPT
}

@test "CHECK: print_info()" {
    run print_info "this is an INFO"
    [ "$status" -eq 0 ]
    [ "$output" = "[32m[INFO][0m this is an INFO" ]
}

@test "CHECK: print_warn()" {
    run print_warn "this is a WARNING"
    [ "$status" -eq 0 ]
    [ "$output" = "[33m[WARNING][0m this is a WARNING" ]
}

@test "CHECK: print_error()" {
    run print_error "this is an ERROR"
    [ "$status" -eq 1 ]
    [ "$output" = "[31m[ERROR][0m this is an ERROR" ]
}

@test "CHECK: command_not_found()" {
    run command_not_found "bats"
    [ "$status" -eq 1 ]
    [ "$output" = "[31m[ERROR][0m bats command not found!" ]
}

@test "CHECK: command_not_found(): show where-to-install" {
    run command_not_found "bats" "batsland"
    [ "$status" -eq 1 ]
    [ "$output" = "[31m[ERROR][0m bats command not found! Install from batsland" ]
}

@test "CHECK: check_arg(): all mandatory variables are set" {
    run check_arg
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: check_arg(): no \$_USER_NAME" {
    unset _USER_NAME
    run check_arg
    [ "$status" -eq 1 ]
    [ "$output" = "$(printf '%b\n' "\033[31m[ERROR]\033[0m -u <username> is missing!")" ]
}

@test "CHECK: check_arg(): wrong format \$_FROM_DATE" {
    _FROM_DATE="20201a1b"
    run check_arg
    [ "$status" -eq 1 ]
    [ "$output" = "$(printf '%b\n' "\033[31m[ERROR]\033[0m -f $_FROM_DATE, wrong date format, must be yyyymmdd!")" ]
}

@test "CHECK: check_arg(): wrong date \$_FROM_DATE" {
    _FROM_DATE="20203030"
    run check_arg
    [ "$output" = "date: invalid date ‘"$_FROM_DATE"’" ]
}

@test "CHECK: check_arg(): wrong format \$_TO_DATE" {
    _TO_DATE="20201a1b"
    run check_arg
    [ "$status" -eq 1 ]
    [ "$output" = "$(printf '%b\n' "\033[31m[ERROR]\033[0m -t $_TO_DATE, wrong date format, must be yyyymmdd!")" ]
}

@test "CHECK: check_arg(): wrong date \$_TO_DATE" {
    _TO_DATE="20203030"
    run check_arg
    [ "$output" = "date: invalid date ‘"$_TO_DATE"’" ]
}

@test "CHECK: check_arg(): pass \$_FROM_DATE < \$_TO_DATE" {
    _FROM_DATE="10101010"
    _TO_DATE="20201010"
    run check_arg
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: check_arg(): pass \$_FROM_DATE = \$_TO_DATE" {
    _FROM_DATE="10101010"
    _TO_DATE="10101010"
    run check_arg
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: check_arg(): fail \$_FROM_DATE > \$_TO_DATE" {
    _FROM_DATE="20201010"
    _TO_DATE="10101010"
    run check_arg
    [ "$status" -eq 1 ]
    [ "$output" = "$(printf '%b\n' "\033[31m[ERROR]\033[0m -t ${_TO_DATE} is earlier than -f ${_FROM_DATE}!")" ]
}

@test "CHECK: compare_time(): =" {
    run compare_time "1" "1"
    [ "$status" -eq 0 ]
    [ "$output" == "=" ]
}

@test "CHECK: compare_time(): >" {
    run compare_time "2" "1"
    [ "$status" -eq 0 ]
    [ "$output" == ">" ]
}

@test "CHECK: compare_time(): <" {
    run compare_time "2" "3"
    [ "$status" -eq 0 ]
    [ "$output" == "<" ]
}

@test "CHECK: compare_time(): empty value" {
    run compare_time "" "4"
    [ "$status" -eq 0 ]
    [ "$output" == "<" ]
}

@test "CHECK: is_token_expired(): yes, file doesn't exist" {
    run is_token_expired "$(date +%s)" "+1 year"
    [ "$status" -eq 0 ]
    [ "$output" = "yes" ]
}

@test "CHECK: is_token_expired(): yes empty file" {
    tmpfile=$(mktemp)
    run is_token_expired "$tmpfile" "+1 month"
    [ "$status" -eq 0 ]
    [ "$output" = "yes" ]
}

@test "CHECK: is_token_expired(): yes, expired" {
    tmpfile=$(mktemp)
    echo "test" > "$tmpfile"
    run is_token_expired "$tmpfile" "-1 hour"
    [ "$status" -eq 0 ]
    [ "$output" = "yes" ]
}

@test "CHECK: is_token_expired(): no" {
    tmpfile=$(mktemp)
    echo "test" > "$tmpfile"
    run is_token_expired "$tmpfile" "+1 min"
    [ "$status" -eq 0 ]
    [ "$output" = "no" ]
}

@test "CHECK: is_item_list_empty: item list" {
    run is_item_list_empty "$(< $_ITEM_JSON_FILE)"
    [ "$status" -eq 0 ]
    [ "$output" = "no" ]
}

@test "CHECK: is_item_list_empty: empty item list" {
    run is_item_list_empty "$(< $_EMPTY_ITEM_JSON_FILE)"
    [ "$status" -eq 0 ]
    [ "$output" = "yes" ]
}

@test "CHECK: download_content" {
    _CURL="$(command -v echo)"
    run download_content "$(< $_ITEM_JSON_FILE)"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[32m[INFO][0m >> Downloading cover 111222333" ]
    [ "${lines[1]}" = "-L -g -o /tmp/cover/111222333.gif v123/dynamicCover/link" ]
    [ "${lines[2]}" = "[32m[INFO][0m >> Downloading video 111222333" ]
    [ "${lines[3]}" = "-L -g -o /tmp/video/111222333.mp4 v123/downloadAddr/link" ]
    [ "${lines[4]}" = "[32m[INFO][0m >> Downloading cover 111222334" ]
    [ "${lines[5]}" = "-L -g -o /tmp/cover/111222334.gif v124/dynamicCover/link" ]
    [ "${lines[6]}" = "[32m[INFO][0m >> Downloading video 111222334" ]
    [ "${lines[7]}" = "-L -g -o /tmp/video/111222334.mp4 v124/downloadAddr/link" ]
    [ "${lines[8]}" = "[32m[INFO][0m Skip download: media isn't published in the time period 11111010-22221010" ]
}

@test "CHECK: download_content: skip video" {
    _CURL="$(command -v echo)"
    _SKIP_VIDEO=true
    run download_content "$(< $_ITEM_JSON_FILE)"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[32m[INFO][0m >> Downloading cover 111222333" ]
    [ "${lines[1]}" = "-L -g -o /tmp/cover/111222333.gif v123/dynamicCover/link" ]
    [ "${lines[2]}" = "[32m[INFO][0m >> Downloading cover 111222334" ]
    [ "${lines[3]}" = "-L -g -o /tmp/cover/111222334.gif v124/dynamicCover/link" ]
    [ "${lines[4]}" = "[32m[INFO][0m Skip download: media isn't published in the time period 11111010-22221010" ]
}

@test "CHECK: download_content: skip cover" {
    _CURL="$(command -v echo)"
    _SKIP_COVER=true
    run download_content "$(< $_ITEM_JSON_FILE)"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[32m[INFO][0m >> Downloading video 111222333" ]
    [ "${lines[1]}" = "-L -g -o /tmp/video/111222333.mp4 v123/downloadAddr/link" ]
    [ "${lines[2]}" = "[32m[INFO][0m >> Downloading video 111222334" ]
    [ "${lines[3]}" = "-L -g -o /tmp/video/111222334.mp4 v124/downloadAddr/link" ]
    [ "${lines[4]}" = "[32m[INFO][0m Skip download: media isn't published in the time period 11111010-22221010" ]
}

@test "CHECK: download_content: media earlier than from-date" {
    _FROM_DATE_UNIXTIME="22221009"
    run download_content "$(< $_ITEM_JSON_FILE)"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[32m[INFO][0m >> Downloading cover 111222333" ]
    [ "${lines[1]}" = "-L -g -o /tmp/cover/111222333.gif v123/dynamicCover/link" ]
    [ "${lines[2]}" = "[32m[INFO][0m >> Downloading video 111222333" ]
    [ "${lines[3]}" = "-L -g -o /tmp/video/111222333.mp4 v123/downloadAddr/link" ]
    [ "${lines[4]}" = "[32m[INFO][0m Skip further download: media are published earlier than 22221009" ]
}
