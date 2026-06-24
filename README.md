# GL.iNet SMS Tool Web App

A lightweight web interface for GL.iNet cellular routers that use the built-in `smsd` / smstools spool directories. It reads received messages from the local spool and queues outbound SMS for `smsd` to send.

## Install

```sh
curl -4 -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-SMS-Tool-WebApp/main/install.sh | sh
```

Then open:

```text
http://ROUTER-IP/sms/
```

### Update

```sh
curl -4 -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-SMS-Tool-WebApp/main/install.sh | sh -s -- --update
```

### Remove application files

```sh
curl -4 -fsSL https://raw.githubusercontent.com/zippyy/GL.iNet-SMS-Tool-WebApp/main/install.sh | sh -s -- --remove
```

Removing the app leaves your SMS spool data intact.

## Router paths

The app reads:

```text
/etc/spool/sms/incoming
/etc/spool/sms/storage
/etc/spool/sms/sent
/etc/spool/sms/failed
```

It queues outgoing messages in:

```text
/etc/spool/sms/outgoing
```

For Puli AX-style dual modem setups, select `GMS1` or `GMS2` in the UI. Leave it on **Automatic / active modem** when the router only exposes one active SMS path.

## API

```text
GET  /cgi-bin/glinet-sms-webapp?action=list&box=incoming
POST /cgi-bin/glinet-sms-webapp?action=send
```

`POST` form fields:

```text
to=15551234567
text=Hello
modem=GMS1       # optional
```

## Security

This interface can send SMS. Keep it on your LAN or a trusted VPN such as Tailscale or WireGuard. Do not publish it directly to the internet.

## IPK

`package/` is an architecture-independent, files-only OpenWrt package definition (`PKGARCH:=all`). Build it with an OpenWrt SDK matching the router firmware, then install the resulting `.ipk` with `opkg install`.

## Version 1.0.1 fix

The installer uses only BusyBox-compatible commands (`cp`, `chmod`, and `mkdir`). It does **not** call the absent GNU/coreutils `install` binary, which was the cause of the prior `sh: install: not found` failure on GL.iNet firmware.
