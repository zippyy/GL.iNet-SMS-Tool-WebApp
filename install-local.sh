#!/bin/sh
# GL.iNet SMS Tool Web App — install from an extracted local project copy.
# BusyBox/OpenWrt compatible: no dependency on the unavailable `install` command.

set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
WEB_DIR='/www/sms'
CGI_DIR='/www/cgi-bin'
CGI_FILE="$CGI_DIR/glinet-sms-webapp"
UCI_CONFIG='/etc/config/glinet_sms_webapp'
DEFAULT_SPOOL='/etc/spool/sms'

fail() { echo "[GL.iNet-SMS-Tool-WebApp] ERROR: $*" >&2; exit 1; }
copy_file() {
    source_file="$1"
    target_file="$2"
    file_mode="$3"
    [ -f "$source_file" ] || fail "missing source: $source_file"
    mkdir -p "$(dirname "$target_file")"
    cp -f "$source_file" "$target_file" || fail "could not copy $source_file"
    chmod "$file_mode" "$target_file" || fail "could not set permissions on $target_file"
}

[ "$(id -u)" = '0' ] || fail 'run as root'
[ -f "$ROOT/www/sms/index.html" ] || fail 'run from the extracted project directory'
[ -f "$ROOT/www/cgi-bin/glinet-sms-webapp" ] || fail 'project CGI endpoint is missing'

if [ ! -f "$UCI_CONFIG" ]; then
    mkdir -p /etc/config
    cat > "$UCI_CONFIG" <<EOF_CONFIG
config sms 'settings'
        option spool_base '$DEFAULT_SPOOL'
EOF_CONFIG
fi

base="$(uci -q get glinet_sms_webapp.settings.spool_base 2>/dev/null || true)"
[ -n "$base" ] || base="$DEFAULT_SPOOL"
mkdir -p "$base/incoming" "$base/storage" "$base/sent" "$base/failed" "$base/outgoing" || \
    fail "could not create SMS spool folders under $base"

rm -rf "$WEB_DIR"
mkdir -p "$WEB_DIR" "$CGI_DIR" || fail 'could not create web directories'
copy_file "$ROOT/www/sms/index.html" "$WEB_DIR/index.html" 0644
copy_file "$ROOT/www/sms/app.css" "$WEB_DIR/app.css" 0644
copy_file "$ROOT/www/sms/app.js" "$WEB_DIR/app.js" 0644
copy_file "$ROOT/www/cgi-bin/glinet-sms-webapp" "$CGI_FILE" 0755

if [ -d /usr/lib/lua/luci/controller ] && [ -f "$ROOT/luci/glinet_sms_webapp.lua" ]; then
    copy_file "$ROOT/luci/glinet_sms_webapp.lua" /usr/lib/lua/luci/controller/glinet_sms_webapp.lua 0644
fi

[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
lan_ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
echo "[GL.iNet-SMS-Tool-WebApp] Installed: http://${lan_ip:-ROUTER-IP}/sms/"
