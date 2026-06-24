#!/bin/sh
# GL.iNet SMS Tool Web App - BusyBox/OpenWrt installer
set -eu

APP_NAME='GL.iNet-SMS-Tool-WebApp'
REPO='zippyy/GL.iNet-SMS-Tool-WebApp'
REF='main'
RAW_BASE="https://raw.githubusercontent.com/$REPO/$REF"
WEB_DIR='/www/sms'
CGI_DIR='/www/cgi-bin'
CGI_FILE="$CGI_DIR/glinet-sms-webapp"
UCI_CONFIG='/etc/config/glinet_sms_webapp'
SPOOL_BASE='/etc/spool/sms'
TMP_DIR="/tmp/glinet-sms-webapp.$$"

log() { printf '[%s] %s\n' "$APP_NAME" "$*"; }
fail() { printf '[%s] ERROR: %s\n' "$APP_NAME" "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT HUP INT TERM

[ "$(id -u)" = '0' ] || fail 'run as root'

fetch() {
    url="$1"
    output="$2"
    mkdir -p "$(dirname "$output")"
    if has curl; then
        curl -4 -fsSL "$url" -o "$output" 2>/dev/null || curl -fsSL "$url" -o "$output"
    elif has wget; then
        wget -4 -qO "$output" "$url" 2>/dev/null || wget -qO "$output" "$url"
    else
        fail 'curl or wget is required'
    fi
    [ -s "$output" ] || fail "download failed: $url"
}

copy_to_router() {
    source_file="$1"
    target_file="$2"
    mode="$3"
    [ -f "$source_file" ] || fail "missing source file: $source_file"
    mkdir -p "$(dirname "$target_file")"
    cp -f "$source_file" "$target_file"
    chmod "$mode" "$target_file"
}

write_config() {
    [ -f "$UCI_CONFIG" ] && return 0
    mkdir -p /etc/config
    cat > "$UCI_CONFIG" <<EOF
config sms 'settings'
        option spool_base '$SPOOL_BASE'
EOF
}

current_spool_base() {
    base="$(uci -q get glinet_sms_webapp.settings.spool_base 2>/dev/null || true)"
    [ -n "$base" ] || base="$SPOOL_BASE"
    printf '%s' "$base"
}

download_app() {
    fetch "$RAW_BASE/www/sms/index.html" "$TMP_DIR/index.html"
    fetch "$RAW_BASE/www/sms/app.css" "$TMP_DIR/app.css"
    fetch "$RAW_BASE/www/sms/app.js" "$TMP_DIR/app.js"
    fetch "$RAW_BASE/www/cgi-bin/glinet-sms-webapp" "$TMP_DIR/glinet-sms-webapp"
}

restart_web_servers() {
    [ -x /etc/init.d/nginx ] && /etc/init.d/nginx restart >/dev/null 2>&1 || true
    [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
}

do_install() {
    log "installing from $REPO@$REF"
    write_config
    base="$(current_spool_base)"
    mkdir -p "$base/incoming" "$base/storage" "$base/sent" "$base/failed" "$base/outgoing"
    download_app

    rm -rf "$WEB_DIR"
    mkdir -p "$WEB_DIR" "$CGI_DIR"
    chmod 0755 /www "$WEB_DIR" "$CGI_DIR" 2>/dev/null || true
    copy_to_router "$TMP_DIR/index.html" "$WEB_DIR/index.html" 0644
    # GL.iNet nginx builds may only treat index.htm as a directory index.
    copy_to_router "$TMP_DIR/index.html" "$WEB_DIR/index.htm" 0644
    copy_to_router "$TMP_DIR/app.css" "$WEB_DIR/app.css" 0644
    copy_to_router "$TMP_DIR/app.js" "$WEB_DIR/app.js" 0644
    copy_to_router "$TMP_DIR/glinet-sms-webapp" "$CGI_FILE" 0755
    restart_web_servers

    lan_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
    [ -n "$lan_ip" ] || lan_ip='ROUTER-IP'
    log "installed: http://$lan_ip/sms/index.htm"
}

remove_app() {
    rm -rf "$WEB_DIR"
    rm -f "$CGI_FILE"
    restart_web_servers
    log 'removed application files; SMS data was not deleted'
}

case "${1:-install}" in
    install|update|--update) do_install ;;
    remove|uninstall|--remove) remove_app ;;
    *) fail 'usage: sh install.sh [install|--update|--remove]' ;;
esac
