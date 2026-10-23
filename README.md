# Nextcloud Deploy Scripts

Automated Nextcloud installation for Ubuntu 26.04 LTS on amd64 and arm64 (servers and Raspberry Pi 5).

Based on nginx, PHP, MariaDB, Redis, CrowdSec and ufw, with a Let's Encrypt certificate.

Optional:
- **ZFS mirror** for the data directory: free disks of the same size are detected and offered before the installation (SSD, NVMe or USB, the system disk is never offered).
- **DynDNS** via `dyndns-api.yourdevice.ch`: one API key per installation, valid for exactly one hostname. A systemd timer keeps the record pointed at the current public IP. The certificate is validated through DNS, so a DynDNS machine can be set up in any network with internet access and shipped; at its destination it is reachable a few minutes after ports 443 (and 80 for the redirect) are forwarded to it.

## Raspberry Pi 5

Install **Ubuntu Server 26.04 LTS (64-bit)** with the Raspberry Pi Imager (no desktop needed). Ubuntu ships the ZFS kernel module prebuilt for the Raspberry Pi kernel, so nothing is compiled on the Pi.

## Usage

```bash
wget https://raw.githubusercontent.com/warioishere/nextcloud-deploy/main/zero.sh
wget https://raw.githubusercontent.com/warioishere/nextcloud-deploy/main/zero.cfg
```

Edit `zero.cfg` to fit your environment, then run:

```bash
chmod +x zero.sh
sudo ./zero.sh
```

All questions (ZFS mirror, static IP or DynDNS, DynDNS key) are asked at the start; the installation then runs unattended. Every answer can also be preset in `zero.cfg`.

With a static IP and an own domain, the domain must point to the server and port 80 must be reachable from the internet for the certificate. If issuing fails, the installation keeps a placeholder certificate and can be completed later with:

```bash
sudo /usr/local/sbin/nextcloud-le-cert <domain>
```

## Credits

Based on the excellent work of **Carsten Rieger** — [c-rieger.de](https://www.c-rieger.de)

Adapted by [yourdevice.ch](https://www.yourdevice.ch)
