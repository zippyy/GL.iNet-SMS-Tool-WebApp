#!/bin/sh
# GL.iNet SMS Tool Web App installer
# Intended for: curl -4 -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-SMS-Tool-WebApp/main/install.sh | sh

set -eu

APP_NAME="GL.iNet-SMS-Tool-WebApp"
REPO="zippyy/GL.iNet-SMS-Tool-WebApp"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"
WEB_DIR="/www/sms"
CGI_DIR="/www/cgi-bin"
CGI_FILE="$CGI_DIR/glinet-sms-webapp"
UCI_CONFIG="/etc/config/glinet_sms_webapp"
SPOOL_BASE="/etc/spool/sms"
TMP_DIR="/tmp/glinet-sms-webapp-install.$$"

log() { printf '[%s] %s\n' "$APP_NAME" "$*"; }
fail() { printf '[%s] ERROR: %s\n' "$APP_NAME" "$*" >&2; exit 1; }
need_root() { [ "$(id -u)" = "0" ] || fail "run as root"; }
has() { command -v "$1" >/dev/null 2>&1; }

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT INT TERM

# Prefer IPv4 because some GL.iNet/OpenWrt IPv6 paths to raw.githubusercontent.com
# return an erroneous 404. Falls back to the normal connection method.
fetch() {
    url="$1"
    out="$2"
    mkdir -p "$(dirname "$out")"

    if has curl; then
        curl -4 -fsSL "$url" -o "$out" 2>/dev/null || curl -fsSL "$url" -o "$out"
    elif has wget; then
        wget -4 -qO "$out" "$url" 2>/dev/null || wget -qO "$out" "$url"
    else
        fail "curl or wget is required"
    fi

    [ -s "$out" ] || fail "downloaded an empty file: $url"
}

write_default_config() {
    [ -f "$UCI_CONFIG" ] && return 0
    mkdir -p /etc/config
    cat > "$UCI_CONFIG" <<EOF_CONFIG
config sms 'settings'
        option spool_base '$SPOOL_BASE'
EOF_CONFIG
}

prepare_sms_spools() {
    base="$(uci -q get glinet_sms_webapp.settings.spool_base 2>/dev/null || true)"
    [ -n "$base" ] || base="$SPOOL_BASE"
    mkdir -p "$base/incoming" "$base/storage" "$base/sent" "$base/failed" "$base/outgoing"
}

download_release_files() {
    mkdir -p "$TMP_DIR/www/sms" "$TMP_DIR/www/cgi-bin" "$TMP_DIR/luci"

    fetch "$RAW_BASE/www/sms/index.html" "$TMP_DIR/www/sms/index.html"
    fetch "$RAW_BASE/www/sms/app.css" "$TMP_DIR/www/sms/app.css"
    fetch "$RAW_BASE/www/sms/app.js" "$TMP_DIR/www/sms/app.js"
    fetch "$RAW_BASE/www/cgi-bin/glinet-sms-webapp" "$TMP_DIR/www/cgi-bin/glinet-sms-webapp"
    fetch "$RAW_BASE/luci/glinet_sms_webapp.lua" "$TMP_DIR/luci/glinet_sms_webapp.lua"
}

install_files() {
    rm -rf "$WEB_DIR"
    mkdir -p "$WEB_DIR" "$CGI_DIR"

    cp -f "$TMP_DIR/www/sms/index.html" "$WEB_DIR/index.html"
    cp -f "$TMP_DIR/www/sms/app.css" "$WEB_DIR/app.css"
    cp -f "$TMP_DIR/www/sms/app.js" "$WEB_DIR/app.js"
    install -m 0755 "$TMP_DIR/www/cgi-bin/glinet-sms-webapp" "$CGI_FILE"

    # This adds a LuCI Services menu link when LuCI is installed. The app itself
    # does not require LuCI and remains available at /sms/ either way.
    if [ -d /usr/lib/lua/luci/controller ]; then
        install -m 0644 "$TMP_DIR/luci/glinet_sms_webapp.lua" \
            /usr/lib/lua/luci/controller/glinet_sms_webapp.lua
    fi
}

restart_services() {
    if [ -x /etc/init.d/uhttpd ]; then
        /etc/init.d/uhttpd enable >/dev/null 2>&1 || true
        /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
    else
        log "uhttpd was not found; install/enable uhttpd, then open /sms/"
    fi
}

remove_app() {
    rm -rf "$WEB_DIR"
    rm -f "$CGI_FILE" /usr/lib/lua/luci/controller/glinet_sms_webapp.lua
    [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
    log "removed application files; SMS spool data was left untouched"
}

install_app() {
    log "installing from $REPO@$BRANCH"
    write_default_config
    prepare_sms_spools
    download_release_files
    install_files
    restart_services

    lan_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
    [ -n "$lan_ip" ] || lan_ip="ROUTER-IP"
    log "installed: http://$lan_ip/sms/"
}

need_root
case "${1:-install}" in
    install|--update|update) install_app ;;
    --remove|remove|uninstall) remove_app ;;
    *)
        echo "Usage: sh install.sh [install|--update|--remove]" >&2
        exit 2
        ;;
esac
