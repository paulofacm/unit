Deployment notes — UNIT Relayer

This directory contains example artifacts to deploy the relayer binary on a Linux server.

1) Create system user and directory

```bash
sudo useradd -r -s /usr/sbin/nologin relayer
sudo mkdir -p /opt/unit/relayer
sudo chown relayer:relayer /opt/unit/relayer
```

2) Copy binary and configs

Copy the built binary (e.g. `unit-relayer-linux`) into `/opt/unit/relayer` and make it executable.

3) Systemd service

Install the unit file at `/etc/systemd/system/unit-relayer.service` (this file is provided as a template). Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now unit-relayer.service
sudo journalctl -u unit-relayer -f
```

4) TLS and reverse proxy (recommended)

Use the provided `nginx.conf` as an example to reverse-proxy traffic to the relayer. In production, obtain certificates (Let's Encrypt / ACME) and secure the server.

Security notes:
- Run relayer behind a firewall and TLS termination (NGINX). Add authentication (API keys or mTLS) before exposing to the public internet.
- Configure process supervision (systemd is provided) and logging rotation.
