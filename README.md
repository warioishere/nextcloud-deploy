# Nextcloud Deploy Scripts

Automated Nextcloud installation scripts for Ubuntu and Debian (x86-64).

Based on nginx, PHP, MariaDB/PostgreSQL, Redis, CrowdSec and ufw.

## Usage

### Ubuntu

```bash
wget https://raw.githubusercontent.com/warioishere/nextcloud-deploy/main/ubuntu/zero.sh
wget https://raw.githubusercontent.com/warioishere/nextcloud-deploy/main/ubuntu/zero.cfg
```

### Debian

```bash
wget https://raw.githubusercontent.com/warioishere/nextcloud-deploy/main/debian/zero.sh
wget https://raw.githubusercontent.com/warioishere/nextcloud-deploy/main/debian/zero.cfg
```

Edit `zero.cfg` to fit your environment, then run:

```bash
chmod +x zero.sh
sudo ./zero.sh
```

## Credits

Based on the excellent work of **Carsten Rieger** — [c-rieger.de](https://www.c-rieger.de)

Adapted by [yourdevice.ch](https://www.yourdevice.ch)
