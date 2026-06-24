# GL.iNet SMS Tool Web App

A lightweight web interface for GL.iNet cellular routers that use the built-in `smsd` / smstools spool directories. It reads received messages from the local spool and queues outbound SMS for `smsd` to send.

## Features

- Inbox, storage, sent, and failed SMS folders
- Read SMS metadata and message bodies from `/etc/spool/sms`
- Queue outbound SMS in `/etc/spool/sms/outgoing`
- Optional modem selection: automatic, `GMS1`, or `GMS2`
- Works with the messages already being written by GL.iNet's `smsd` service
- Responsive UI at `http://ROUTER-IP/sms/`
- CGI API at `/cgi-bin/glinet-sms-webapp`
- LuCI **Services → GL.iNet SMS Tool** shortcut when LuCI is installed

## One-line install

```sh
curl -4 -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-SMS-Tool-WebApp/main/install.sh | sh
```

The installer deliberately downloads individual project files rather than a GitHub ZIP archive. That avoids the archive-root-name mismatch that broke prior revisions.

Open:

```text
http://ROUTER-IP/sms/
```

## Update

```sh
curl -4 -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-SMS-Tool-WebApp/main/install.sh | sh -s -- --update
```

## Remove application files

```sh
curl -4 -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-SMS-Tool-WebApp/main/install.sh | sh -s -- --remove
```

Removing the app leaves SMS spool data intact.

## Install directly from an extracted ZIP

Copy the ZIP to the router, extract it, and run:

```sh
sh install-local.sh
```

## SMS spool paths

By default, the app uses:

```text
/etc/spool/sms/incoming
/etc/spool/sms/storage
/etc/spool/sms/sent
/etc/spool/sms/failed
/etc/spool/sms/outgoing
```

Change the base path with UCI when needed:

```sh
uci set glinet_sms_webapp.settings.spool_base='/etc/spool/sms'
uci commit glinet_sms_webapp
```

## API

```text
GET  /cgi-bin/glinet-sms-webapp?action=list&box=incoming
POST /cgi-bin/glinet-sms-webapp?action=send
```

POST form fields:

```text
to=15551234567
text=Hello
modem=GMS1          # optional; omit for automatic/active modem
```

## Security

The UI can send SMS. Keep router administration and this web UI limited to your LAN, Tailscale, WireGuard, or another trusted VPN. Do not expose it directly to the public internet.

## IPK packaging

`package/` contains an architecture-independent OpenWrt package definition. It is a files-only package (`PKGARCH:=all`) and can be compiled with the OpenWrt SDK that matches the target firmware version.
