#!/bin/sh
# GL.iNet SMS Tool Web App — remote installer
# Usage:
#   curl -4 -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-SMS-Tool-WebApp/main/install.sh | sh
#   curl -4 -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-SMS-Tool-WebApp/main/install.sh | sh -s -- --remove
#
# BusyBox/OpenWrt compatible: deliberately does NOT use the GNU/coreutils
# `install` command, which is absent on many GL.iNet firmware images.

set -eu

APP_NAME='GL.iNet-SMS-Tool-WebApp'
REPO='zippyy/GL.iNet-SMS-Tool-WebApp'
BRANCH='main'
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"
WEB_DIR='/www/sms'
CGI_DIR='/www/cgi-bin'
CGI_FILE="$CGI_DIR/glinet-sms-webapp"
UCI_CONFIG='/etc/config/glinet_sms_webapp'
DEFAULT_SPOOL='/etc/spool/sms'
TMP_DIR="/tmp/glinet-sms-tool-webapp.$$"

log() { printf '[%s] %s\n' "$APP_NAME" "$*"; }
fail() { printf '[%s] ERROR: %s\n' "$APP_NAME" "$*" >&2; exit 1; }
need_root() { [ "$(id -u)" = '0' ] || fail 'run as root'; }
has() { command -v "$1" >/dev/null 2>&1; }
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

fetch() {
    url="$1"
    out="$2"
    mkdir -p "$(dirname "$out")"

    if has curl; then
        curl -4 -fsSL "$url" -o "$out" 2>/dev/null || curl -fsSL "$url" -o "$out"
    elif has wget; then
        wget -4 -qO "$out" "$url" 2>/dev/null || wget -qO "$out" "$url"
    else
        fail 'curl or wget is required'
    fi

    [ -s "$out" ] || fail "downloaded an empty file: $url"
}

copy_file() {
    source_file="$1"
    target_file="$2"
    file_mode="$3"

    [ -f "$source_file" ] || fail "missing downloaded source: $source_file"
    mkdir -p "$(dirname "$target_file")"
    cp -f "$source_file" "$target_file" || fail "could not copy $source_file"
    chmod "$file_mode" "$target_file" || fail "could not set permissions on $target_file"
}

write_default_config() {
    [ -f "$UCI_CONFIG" ] && return 0
    mkdir -p /etc/config
    cat > "$UCI_CONFIG" <<EOF_CONFIG
config sms 'settings'
        option spool_base '$DEFAULT_SPOOL'
EOF_CONFIG
}

sms_spool_base() {
    base="$(uci -q get glinet_sms_webapp.settings.spool_base 2>/dev/null || true)"
    [ -n "$base" ] || base="$DEFAULT_SPOOL"
    printf '%s' "$base"
}

prepare_sms_spools() {
    base="$(sms_spool_base)"
    mkdir -p "$base/incoming" "$base/storage" "$base/sent" "$base/failed" "$base/outgoing" || \
        fail "could not create SMS spool folders under $base"
}

download_release_files() {
    mkdir -p "$TMP_DIR/www/sms" "$TMP_DIR/www/cgi-bin" "$TMP_DIR/luci"
    fetch "$RAW_BASE/www/sms/index.html" "$TMP_DIR/www/sms/index.html"
    fetch "$RAW_BASE/www/sms/app.css" "$TMP_DIR/www/sms/app.css"
    fetch "$RAW_BASE/www/sms/app.js" "$TMP_DIR/www/sms/app.js"
    fetch "$RAW_BASE/www/cgi-bin/glinet-sms-webapp" "$TMP_DIR/www/cgi-bin/glinet-sms-webapp"

    # LuCI is optional, so a missing controller should not prevent the web UI
    # itself from being installed.
    if has curl; then
        curl -4 -fsSL "$RAW_BASE/luci/glinet_sms_webapp.lua" -o "$TMP_DIR/luci/glinet_sms_webapp.lua" 2>/dev/null || true
    elif has wget; then
        wget -4 -qO "$TMP_DIR/luci/glinet_sms_webapp.lua" "$RAW_BASE/luci/glinet_sms_webapp.lua" 2>/dev/null || true
    fi
}

install_files() {
    rm -rf "$WEB_DIR"
    mkdir -p "$WEB_DIR" "$CGI_DIR" || fail 'could not create web directories'

    copy_file "$TMP_DIR/www/sms/index.html" "$WEB_DIR/index.html" 0644
    copy_file "$TMP_DIR/www/sms/app.css" "$WEB_DIR/app.css" 0644
    copy_file "$TMP_DIR/www/sms/app.js" "$WEB_DIR/app.js" 0644
    copy_file "$TMP_DIR/www/cgi-bin/glinet-sms-webapp" "$CGI_FILE" 0755

    if [ -d /usr/lib/lua/luci/controller ] && [ -s "$TMP_DIR/luci/glinet_sms_webapp.lua" ]; then
        copy_file "$TMP_DIR/luci/glinet_sms_webapp.lua" \
            /usr/lib/lua/luci/controller/glinet_sms_webapp.lua 0644
    fi
}

restart_uhttpd() {
    if [ -x /etc/init.d/uhttpd ]; then
        /etc/init.d/uhttpd enable >/dev/null 2>&1 || true
        /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
    else
        log 'uhttpd was not found; install/enable uhttpd, then open /sms/'
    fi
}

remove_app() {
    rm -rf "$WEB_DIR"
    rm -f "$CGI_FILE" /usr/lib/lua/luci/controller/glinet_sms_webapp.lua
    [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
    log 'removed application files; SMS spool data was left untouched'
}

install_app() {
    log "installing from $REPO@$BRANCH"
    write_default_config
    prepare_sms_spools
    download_release_files
    install_files
    restart_uhttpd

    lan_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
    [ -n "$lan_ip" ] || lan_ip='ROUTER-IP'
    log "installed: http://$lan_ip/sms/"
}

need_root
case "${1:-install}" in
    install|--update|update) install_app ;;
    --remove|remove|uninstall) remove_app ;;
    *)
        echo 'Usage: sh install.sh [install|--update|--remove]' >&2
        exit 2
        ;;
esac
