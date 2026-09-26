# Privacy: traffic monitoring and firewall

Goal: see and control every incoming and outgoing connection, like Little Snitch on macOS.

## Outgoing: ask per application (OpenSnitch + Cutefish Network Monitor)

```
app ──connect()──► kernel ──(eBPF/nfqueue)──► opensnitchd (root, from Ubuntu's opensnitch 1.6.9)
                                                   │ known rule? apply it
                                                   │ unknown?     ask the UI over gRPC
                                                   ▼
                        unix:///tmp/osui.sock ◄── cutefish-netmonitor (user session, Qt6)
                                                   ├─ FishUI prompt: "<app> wants to connect to <host>"
                                                   ├─ records every connection (memory + log file)
                                                   └─ D-Bus com.cutefish.NetMonitor ──► Settings › Network Monitor
```

- **cutefish-netmonitor** (`netmonitor/`) replaces OpenSnitch's Python/PyQt5 UI. It implements OpenSnitch's gRPC `UI` service (`proto/ui.proto` from opensnitch 1.6.9, the version in Ubuntu 26.04) with the archive's `libgrpc++` 1.51 / protobuf 3.21. It starts with the session (`/etc/xdg/autostart/cutefish-netmonitor.desktop`).
- **Prompt** for the first connection of an unknown app:
  - **Apply to:** *this app → this host* (default), *this app → anywhere*, or *any app → this host*.
  - **Remember:** *once*, *until restart*, *forever* (default).
  - **Allow** / **Deny.**
  - No answer within 30 s (or closing the window) means **deny once**, so you get asked again next time.
- **Rules** are stored by the daemon in `/etc/opensnitchd/rules/`. Rules created from the prompt are named `cutefish-<action>-<app>-<hash>`.
- **First boot:** allow rules for system services (NetworkManager, dnsmasq for the hotspot, systemd-resolved/timesyncd, apt, fwupd, avahi, cups-browsed, loopback) are copied into the rules directory on install. The first boot doesn't bombard you with prompts, and your own edits are never overwritten.
- **Live ISO only:** `cutefish-live` adds `/etc/opensnitchd/rules/cutefish-live-installer.json`, which allows the installer (`/usr/bin/calamares`) and anything it runs inside the new system (`/tmp/calamares-root-*/…`, e.g. apt for `ubuntu-drivers`). Without it, the installer's geoip and connectivity checks waited on prompts and were denied after 30 s. The installer purges `cutefish-live` from the installed system, so the rule doesn't stay (decided 2026-09-26).
- **While a prompt is open**, OpenSnitch 1.6.9 doesn't queue further questions. Every other new connection that no rule matches gets the `DefaultAction` right away (`daemon/main.go`: `if uiClient.Connected() == false || uiClient.GetIsAsking() == true { applyDefaultAction(...) }`). With `allow`, that includes the app's own retry. In testing, `curl https://example.com` resolved on its 5-second DNS retry and fetched the page while its first DNS query was still waiting in the prompt. A prompt therefore decides future connections (through the rule it creates) but doesn't reliably stop the one it's asking about. We kept `allow` by choice so that nothing breaks before login. Setting `DefaultAction` to `deny` closes this gap, but then unknown system services are also blocked before login (see [known-issues.md](known-issues.md)).
- **When nobody is logged in** (boot, login screen) there is no UI to ask. OpenSnitch then applies its `DefaultAction`, which we left at Ubuntu's `allow`, and still logs the connection. Otherwise updates and time sync before login would break.
- **Connection log:** the last 5,000 connections in memory, plus a log in `~/.local/share/cutefish/netmonitor/connections.log`. Tab-separated fields: time, action, rule, process, pid, protocol, destination, IP. It rotates once at 20 MB.

## Incoming: default deny, logged

`cutefish-firewall.service` loads `/etc/cutefish-firewall.nft`, an nftables table `inet cutefish_firewall` with input policy **drop**. Accepted:

- replies to connections this machine made (`ct state established,related`);
- loopback and ICMP/ICMPv6 (IPv6 needs neighbour discovery);
- DHCP/DHCPv6 client replies (UDP 68/546) and mDNS (UDP 5353, for printers and local devices);
- DNS/DHCP for Wi-Fi hotspot clients (UDP 53/67, TCP 53). NetworkManager's dnsmasq only listens there while the hotspot is on.

Everything else is dropped and logged to the kernel log with the prefix `cutefish-in:`, rate-limited to 10/s.

To open a port (for example SSH), add a rule to the file and `sudo systemctl restart cutefish-firewall`. To switch the inbound firewall off: `sudo systemctl disable --now cutefish-firewall`.

## Settings › Network Monitor

- A switch for *Ask before apps connect* (OpenSnitch interception on/off, sent to the daemon over the gRPC notification stream), plus totals.
- **Recent outgoing connections:** app, destination, protocol, and allowed (green) or blocked (red).
- **Rules:** change allow/deny, or delete.
- **Blocked incoming connections:** read from `journalctl -k --grep cutefish-in:`. The first user is in group `adm`, which may read the journal.

## Other privacy defaults (`cutefish-privacy`)

- Conflicts with, and so removes: `apport`, `whoopsie`, `ubuntu-report`, `popularity-contest`, `snapd`.
- NetworkManager: no connectivity check (no periodic requests to connectivity-check.ubuntu.com), random MAC while scanning, and a stable random MAC per Wi-Fi network (`/etc/NetworkManager/conf.d/90-cutefish-privacy.conf`).
- `motd-news.timer` masked; Ubuntu Pro "apt news" off.
- Firefox (from Mozilla's APT repo, no snap): telemetry, studies, Pocket and sponsored content off; tracking protection on, including cryptominers and fingerprinters (`/etc/firefox/policies/policies.json`).

## Security notes

- OpenSnitch's UI socket is `/tmp/osui.sock`, OpenSnitch's default. A local program that creates this socket before the Network Monitor starts could answer prompts. This is the same trust model as upstream OpenSnitch on a single-user machine. On shared machines, point `Server.Address` in `/etc/opensnitchd/default-config.json` to a path only the desktop user can create.
- The Network Monitor and Settings never need root. Rule changes go through the daemon, which already runs as root.
