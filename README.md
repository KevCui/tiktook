TikTook
=======

> Take TikTok videos to local

## Features

- No need to sign in TikTok account
- No need to register TikTok API
- Download covers and videos from TikTok directly
- Download json data, including profile data, cover/video data...
- Skip image download, or/and video download, or/and json data download
- Set time period to download only contents which were published in this period
-

## Dependency

- [curl](https://curl.haxx.se/download.html)
- [jq](https://stedolan.github.io/jq/download/)
- [putility](https://github.com/KevCui/pUtility)

## Installation

```bash
~$ git clone https://github.com/KevCui/tiktook.git
~$ cd tiktook
~$ git submodule init
~$ git submodule update
~$ cd putility
~$ npm i puppeteer-core commander
```

## Usage

```
Usage:
  ./tiktook.sh -u <username> [-d] [-c] [-v] [-f <yyyymmdd>] [-t <yyyymmdd>]

Options:
  -u               required, TikTok username
  -d               optional, skip json data download
  -c               optional, skip cover download
  -v               optional, skip video download
  -f <yyyymmdd>    optional, from date, format yyyymmdd
  -t <yyyymmdd>    optional, to date, format yyyymmdd
```

### Example

- Download all videos since `1 Jun 2016`, from `@tiktok` account:

```bash
~$ ./tiktook.sh -u tiktok -f 20200601
```

## How to run tests

```bash
~$ bats test/tiktook.bats
```

## Disclaimer

The purpose of this script is to download media contents from TikTok in order to backup and archive them. Please do NOT copy or distribute downloaded contents to others. Please do remember that the copyright of contents always belongs to the owner of TikTok account. Please use this script at your own responsibility.
