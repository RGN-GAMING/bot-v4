# MINE CLOUD VPS Manager — RGN GAMING

## Install

Upload and extract this ZIP on the Linux VPS, then run:

```bash
cd mine-cloud-vps-manager
chmod +x install.sh
sudo bash install.sh
```

The installer interactively asks for the Discord bot token, owner Discord user ID, prefix, bot name, public server IP/domain, optional VPS role ID, storage pool, and Web SSH URL format. It creates the `.env` file automatically; do not create it manually. The bot token is hidden while typing.

## Service commands

```bash
systemctl status mine-cloud-bot
journalctl -u mine-cloud-bot -f
systemctl restart mine-cloud-bot
systemctl stop mine-cloud-bot
```

## Important host requirement

This bot provisions containers through the host's existing LXD/LXC CLI (`lxc`). The installer does not install or reconfigure LXD automatically because host virtualization support and storage/network setup must be verified for each VPS provider. If `lxc` is unavailable or the provider blocks container features, the bot may connect to Discord but VPS deployment commands will not work until a supported LXD/LXC backend is available.

Web SSH is the existing HTTP/Flask terminal included in the supplied bot; no separate WebSocket service has been added. For public access, configure HTTPS/reverse proxy and firewall rules appropriately.

The supplied thumbnail URL is embedded in the generated configuration. Discord attachment URLs containing signed query parameters may expire; if the image later stops loading, provide a permanent image URL and update `BOT_THUMBNAIL_URL` and `BOT_ICON_URL`.
