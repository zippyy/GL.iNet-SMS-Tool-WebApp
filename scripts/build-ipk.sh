#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$ROOT_DIR/package"
FILES_DIR="$PKG_DIR/files"
MAKEFILE="$PKG_DIR/Makefile"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
PACKAGE_NAME="glinet-sms-tool-webapp"

version="$(sed -n 's/^PKG_VERSION:=//p' "$MAKEFILE" | head -n1)"
release="$(sed -n 's/^PKG_RELEASE:=//p' "$MAKEFILE" | head -n1)"

[[ -n "$version" ]] || { echo 'PKG_VERSION not found in package/Makefile' >&2; exit 1; }
[[ -n "$release" ]] || { echo 'PKG_RELEASE not found in package/Makefile' >&2; exit 1; }
[[ -d "$FILES_DIR" ]] || { echo 'package/files is missing' >&2; exit 1; }

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
control_dir="$work_dir/control"
data_dir="$work_dir/data"
mkdir -p "$control_dir" "$data_dir" "$OUTPUT_DIR"

# Package every file below package/files exactly where OpenWrt expects it.
cp -a "$FILES_DIR/." "$data_dir/"

# GL.iNet's nginx builds commonly use index.htm for a directory request.
if [[ -f "$data_dir/www/sms/index.html" ]]; then
  cp "$data_dir/www/sms/index.html" "$data_dir/www/sms/index.htm"
fi
chmod 0755 "$data_dir/www/cgi-bin/glinet-sms-webapp"

installed_size="$(du -sk "$data_dir" | awk '{print $1}')"
cat > "$control_dir/control" <<EOF
Package: $PACKAGE_NAME
Version: ${version}-${release}
Architecture: all
Installed-Size: $installed_size
Section: utils
Priority: optional
Maintainer: zippyy
Description: GL.iNet SMS Tool Web App
 A web interface and CGI endpoint for reading SMS and queueing outgoing
 messages through GL.iNet's smstools-compatible SMS spool directories.
EOF

cat > "$control_dir/conffiles" <<'EOF'
/etc/config/glinet_sms_webapp
EOF

cat > "$control_dir/postinst" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0

SPOOL_BASE="$(uci -q get glinet_sms_webapp.settings.spool_base 2>/dev/null || true)"
[ -n "$SPOOL_BASE" ] || SPOOL_BASE='/etc/spool/sms'
mkdir -p "$SPOOL_BASE/incoming" "$SPOOL_BASE/storage" "$SPOOL_BASE/sent" \
         "$SPOOL_BASE/failed" "$SPOOL_BASE/outgoing"

[ -x /etc/init.d/nginx ] && /etc/init.d/nginx restart >/dev/null 2>&1 || true
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
exit 0
EOF
chmod 0755 "$control_dir/postinst"

printf '2.0\n' > "$work_dir/debian-binary"
(
  cd "$control_dir"
  tar --owner=0 --group=0 --numeric-owner -czf "$work_dir/control.tar.gz" .
)
(
  cd "$data_dir"
  tar --owner=0 --group=0 --numeric-owner -czf "$work_dir/data.tar.gz" .
)

ipk="$OUTPUT_DIR/${PACKAGE_NAME}_${version}-${release}_all.ipk"
rm -f "$ipk"
(
  cd "$work_dir"
  ar r "$ipk" debian-binary control.tar.gz data.tar.gz
)

echo "Built $ipk"
