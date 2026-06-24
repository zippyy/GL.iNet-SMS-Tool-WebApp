#!/bin/sh
# Install directly from an extracted copy of this repository on a GL.iNet/OpenWrt router.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
WEB_DIR="/www/sms"
CGI_DIR="/www/cgi-bin"
CGI_FILE="$CGI_DIR/glinet-sms-webapp"
UCI_CONFIG="/etc/config/glinet_sms_webapp"
SPOOL_BASE="/etc/spool/sms"

[ "$(id -u)" = "0" ] || { echo "Run as root" >&2; exit 1; }
[ -f "$ROOT/www/sms/index.html" ] || { echo "Run from the extracted project directory" >&2; exit 1; }

[ -f "$UCI_CONFIG" ] || {
  mkdir -p /etc/config
  cat > "$UCI_CONFIG" <<EOF_CONFIG
config sms 'settings'
        option spool_base '$SPOOL_BASE'
EOF_CONFIG
}

base="$(uci -q get glinet_sms_webapp.settings.spool_base 2>/dev/null || true)"
[ -n "$base" ] || base="$SPOOL_BASE"
mkdir -p "$base/incoming" "$base/storage" "$base/sent" "$base/failed" "$base/outgoing"

rm -rf "$WEB_DIR"
mkdir -p "$WEB_DIR" "$CGI_DIR"
cp -f "$ROOT/www/sms/index.html" "$WEB_DIR/index.html"
cp -f "$ROOT/www/sms/app.css" "$WEB_DIR/app.css"
cp -f "$ROOT/www/sms/app.js" "$WEB_DIR/app.js"
install -m 0755 "$ROOT/www/cgi-bin/glinet-sms-webapp" "$CGI_FILE"

if [ -d /usr/lib/lua/luci/controller ]; then
  install -m 0644 "$ROOT/luci/glinet_sms_webapp.lua" /usr/lib/lua/luci/controller/glinet_sms_webapp.lua
fi

[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
ip="$(uci -q get network.lan.ipaddr 2>/dev/null || true)"
echo "Installed: http://${ip:-ROUTER-IP}/sms/"
