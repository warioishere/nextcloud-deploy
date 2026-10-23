#!/bin/bash
##########################################################################################
# Ubuntu 26.04 LTS - amd64 and arm64 (incl. Raspberry Pi 5)
# Nextcloud latest (or older Versions)
# Based on nginx, PHP, MariaDB, Redis, crowdsec, ufw ...
# Optional: ZFS mirror for the data directory, DynDNS via dyndns-api.yourdevice.ch
# Carsten Rieger || https://www.c-rieger.de
# Adapted by yourdevice.ch
##########################################################################################
CONFIGFILE="zero.cfg"
INSTALLATIONFILE="zero.sh"
DYNDNS_API="https://dyndns-api.yourdevice.ch"
#
#########################################################################
### ! DO NOT CHANGE ANYTHING FROM HERE! // KEINE ÄNDERUNGEN AB HIER ! ###
#########################################################################
if [ "$USER" != "root" ]
then
    clear
    echo ""
    echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo ""
    echo -e " » \e[1;31mKEINE ROOT-BERECHTIGUNGEN! | NO ROOT PERMISSIONS!\033[0m"
    echo ""
    echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo " » Bitte starten Sie das Skript als root: 'sudo ./$INSTALLATIONFILE'"
    echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo ""
    exit 1
fi

if [ -f /tmp/installation ]; then
        clear
        clear
        echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        echo -e " » Die Installation war/ist bereits aktiv  - *\e[1;31mABBRUCH\033[0m*"
        echo -e " » Installation is/was already in progress - *\e[1;31mEXIT\033[0m*"
        echo " » "$(ls -lsha /tmp/installation)
	      echo ""
        echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        echo " » Prüfen und entfernen // Verify and remove :"
        echo " » sudo rm -f /tmp/installation"
        echo ""
        echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        exit 1
fi
##################################################
# Konfigurationsdatei einlesen                   #
##################################################
clear
if [ -f "$CONFIGFILE" ]; then
        echo ""
        echo " » Die Konfigurationsdatei '$CONFIGFILE' wird eingelesen."
        . ./$CONFIGFILE
        NCDBNAME="${NCDBNAME,,}"
        NCDBUSER="${NCDBUSER,,}"
        # Defaults for config files that predate these options
        ZFSMIRROR="${ZFSMIRROR:-ask}"
        ZFSPOOL="${ZFSPOOL:-ncpool}"
        NETMODE="${NETMODE:-ask}"
        DYNDNS_ZONE="${DYNDNS_ZONE:-yourdevice-cloud.ch}"
else
        clear
        echo ""
        echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        echo -e " » \e[1;31m'$CONFIGFILE' ist nicht lesbar | '$CONFIGFILE' not readable\033[0m"
        echo ""
        echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo " » Bitte überprüfen Sie die Datei '$CONFIGFILE'"
        echo " +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        exit 1
fi
###########################
# Start/Begin            #
###########################
touch /tmp/installation
clear
start=$(date +%s)
# apt and needrestart must not stop the run with interactive dialogs
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
# D: Linuxbenutzer ermitteln
# E: identify the current user
BENUTZERNAME=$(logname)
###########################
# IPv4 für "APT'          #
###########################
if [ "$APTIP4" == "y" ]
then
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
fi
apt update && apt upgrade -y && apt autoremove -y && apt autoclean -y
# D: Sicherstellen, dass Basissoftware verfügbar ist
# E: Ensure, admin software is available on the server
apt install -y lsb-release curl wget iputils-ping net-tools jq
###########################
# D: Systempfade auslesen #
# E: Read system paths   #
###########################
adduser=$(command -v adduser)
apt=$(command -v apt-get)
aptmark=$(command -v apt-mark)
cat=$(command -v cat)
chmod=$(command -v chmod)
chown=$(command -v chown)
clear=$(command -v clear)
cp=$(command -v cp)
curl=$(command -v curl)
date=$(command -v date)
echo=$(command -v echo)
lsbrelease=$(command -v lsb_release)
ln=$(command -v ln)
mkdir=$(command -v mkdir)
mv=$(command -v mv)
rm=$(command -v rm)
sed=$(command -v sed)
sudo=$(command -v sudo)
su=$(command -v su)
systemctl=$(command -v systemctl)
tar=$(command -v tar)
timedatectl=$(command -v timedatectl)
touch=$(command -v touch)
usermod=$(command -v usermod)
wget=$(command -v wget)
# D: Systemvoraussetzungen prüfen
# E: Check system requirements
. /etc/os-release
ARCH=$(dpkg --print-architecture)
clear
echo "*************************************************"
echo "*  Pre-Installationschecks werden durchgefuehrt *"
echo "*  Pre-Installationschecks are initiated        *"
echo "*************************************************"
echo ""
echo -e "* Test: Root ...............::::::::::::::::\033[32m OK\033[0m *"
echo ""
if [ "$ID" = "ubuntu" ] && [ "$VERSION_ID" = "26.04" ] \
   && { [ "$ARCH" = "amd64" ] || [ "$ARCH" = "arm64" ]; }
then
echo -e "* Test: Ubuntu $VERSION_ID ($ARCH) was found .....::::\033[32m OK\033[0m *"
echo ""
else
clear
echo ""
echo -e " »\e[1;31m"
echo "******************************************************"
echo "*   Sie verwenden kein Ubuntu 26.04 amd64/arm64      *"
echo "*   You aren't operating on Ubuntu 26.04 amd64/arm64 *"
echo "******************************************************"
echo  -e "\033[0m"
echo ""
${rm} -f /tmp/installation
exit 1
fi
##########################
# Re-Install. verhindern #
# Prevent Second Run     #
##########################
if [ -e "/var/www/nextcloud/config/config.php" ] || [ -e /etc/nginx/conf.d/nextcloud.conf ]; then
  clear
  echo "*************************************************"
  echo -e "* Test: Bestehende Installation ....:::::\e[1;31m FAILED\033[0m *"
  echo -e "* Test: Previous installation ......:::::\e[1;31m FAILED\033[0m *"
  echo "*************************************************"
  echo ""
  echo "* Nextcloud ist auf diesem System bereits installiert!"
  echo "* Nextcloud has already been installed on this system!"
  echo ""
  echo "* Bitte setzen Sie den Server ggf. neu auf, bevor Sie mit einer Installation fortfahren."
  echo "* Please re-setup the server again before proceeding to a new installation."
  echo ""
  exit 1
else
  echo "*************************************************"
  echo -e "* Keine bestehende Installation gefunden .::\033[32m OK\033[0m *"
  echo -e "* No previous installation found ......:::::\033[32m OK\033[0m *"
  echo "*************************************************"
  echo ""
fi
###########################
# Prüfe Homeverzeichnis   #
# Verify homedirectory    #
###########################
if [ ! -d "/home/$BENUTZERNAME/" ]; then
  echo -e "* Erstelle:  Benutzerverzeichnis .....::::::\033[32m OK\033[0m *"
  echo -e "* Creating:  Home Directory ..........::::::\033[32m OK\033[0m *"
  mkdir -p /home/"$BENUTZERNAME"/
  echo ""
  else
  echo -e "* Test: Benutzerverzeichnis ........::::::::\033[32m OK\033[0m *"
  echo -e "* Test: Home directory ..........:::::::::::\033[32m OK\033[0m *"
  echo ""
  fi
if [ ! -d "/home/$BENUTZERNAME/Nextcloud-Installationsskript/" ]; then
  echo -e "* Erstelle: Installationsskript-Verzeichnis:\033[32m OK\033[0m *"
  echo -e "* Creating: Install directory .......:::::::\033[32m OK\033[0m *"
  mkdir /home/"$BENUTZERNAME"/Nextcloud-Installationsskript/
  echo ""
  else
  echo -e "* Test: Installationsskript-Verzeichnis ..::\033[32m OK\033[0m *"
  echo -e "* Test: Installscript directory .....:::::::\033[32m OK\033[0m *"
  echo ""
  fi
###########################
# D: Abbruch-Funktion     #
# E: Abort function       #
###########################
function abort() {
  echo ""
  echo -e " » \e[1;31m$1\033[0m"
  echo ""
  ${rm} -f /tmp/installation
  exit 1
  }
###########################
# D: ZFS-Mirror: Auswahl  #
# E: ZFS mirror: choice   #
###########################
# The disks holding /, /boot, /boot/firmware or swap are never offered.
function system_disks() {
  local src
  for m in / /boot /boot/firmware; do
    src=$(findmnt -no SOURCE "$m" 2>/dev/null) || continue
    # btrfs reports subvolumes as /dev/sda2[/@]
    src=${src%%\[*}
    lsblk -nrspo NAME,TYPE "$src" 2>/dev/null | awk '$2=="disk" {print $1}'
  done
  for src in $(swapon --show=NAME --noheadings 2>/dev/null); do
    lsblk -nrspo NAME,TYPE "$src" 2>/dev/null | awk '$2=="disk" {print $1}'
  done
  }
# Prints "device size_bytes in_use transport model" for every disk that could
# go into the mirror. in_use is 1 when the disk has partitions or signatures.
function zfs_candidates() {
  local sys name size type tran model used
  sys=" $(system_disks | sort -u | tr '\n' ' ') "
  # JSON keeps empty columns (no transport on virtual disks) from shifting fields.
  while IFS=$'\t' read -r name size type tran model; do
    [ "$type" = "disk" ] || continue
    case "$name" in /dev/loop*|/dev/zram*|/dev/sr*|/dev/fd*|/dev/mmcblk*boot*) continue ;; esac
    [[ "$sys" == *" $name "* ]] && continue
    [ "$size" -gt 0 ] 2>/dev/null || continue
    used=0
    [ "$(lsblk -nrpo NAME "$name" | wc -l)" -gt 1 ] && used=1
    [ -n "$(lsblk -dnro FSTYPE "$name")" ] && used=1
    echo "$name $size $used $tran $model"
  done < <(lsblk -dbpJo NAME,SIZE,TYPE,TRAN,MODEL | jq -r '.blockdevices[]
             | [.name, (.size|tostring), .type, (.tran // "-"), ((.model // "-") | gsub("\\s+"; "_"))] | @tsv')
  }
# Two disks count as the same size when they differ by at most 1 %.
function same_size() {
  local a=$1 b=$2 big=$1
  [ "$b" -gt "$big" ] && big=$b
  [ $(( (a > b ? a - b : b - a) * 100 )) -le "$big" ]
  }
# Resolves a disk to a stable /dev/disk/by-id name, so the pool survives
# changed device names after a reboot.
function disk_id() {
  local link fallback=""
  for link in /dev/disk/by-id/*; do
    [[ "$link" == *-part* ]] && continue
    [ "$(readlink -f "$link")" = "$1" ] || continue
    case "$link" in
      */wwn-*|*/nvme-eui.*) fallback=${fallback:-$link} ;;
      *) echo "$link"; return ;;
    esac
  done
  echo "${fallback:-$1}"
  }
function choose_zfs_mirror() {
  ZFS_DISKS=()
  [ "$ZFSMIRROR" = "n" ] && return
  if [ "$ZFSMIRROR" = "y" ]; then
    # Non-interactive: ZFSDISKS names the two disks.
    read -r -a ZFS_DISKS <<< "$ZFSDISKS"
    [ "${#ZFS_DISKS[@]}" -eq 2 ] || abort "ZFSMIRROR=\"y\" braucht genau zwei Disks in ZFSDISKS | needs exactly two disks in ZFSDISKS"
    local d line
    for d in "${ZFS_DISKS[@]}"; do
      line=$(zfs_candidates | awk -v d="$d" '$1==d')
      [ -n "$line" ] || abort "$d ist keine freie Datendisk | $d is not an eligible data disk"
      if [ "$(echo "$line" | awk '{print $3}')" = "1" ] && [ "$ZFSWIPE" != "y" ]; then
        abort "$d enthält Daten; zum Löschen ZFSWIPE=\"y\" setzen | $d holds data; set ZFSWIPE=\"y\" to wipe it"
      fi
    done
    same_size "$(zfs_candidates | awk -v d="${ZFS_DISKS[0]}" '$1==d {print $2}')" \
              "$(zfs_candidates | awk -v d="${ZFS_DISKS[1]}" '$1==d {print $2}')" \
      || abort "Die Disks in ZFSDISKS sind nicht gleich gross | The disks in ZFSDISKS differ in size"
    return
  fi
  # Interactive ("ask"): offer disks that have at least one partner of the same size.
  local cands=() i j
  mapfile -t cands < <(zfs_candidates)
  local offer=()
  for ((i=0; i<${#cands[@]}; i++)); do
    for ((j=0; j<${#cands[@]}; j++)); do
      [ $i -eq $j ] && continue
      if same_size "$(echo "${cands[$i]}" | awk '{print $2}')" "$(echo "${cands[$j]}" | awk '{print $2}')"; then
        offer+=("${cands[$i]}"); break
      fi
    done
  done
  [ "${#offer[@]}" -lt 2 ] && return
  echo "*************************************************"
  echo "*  ZFS-Mirror für das Nextcloud-Datenverzeichnis *"
  echo "*  ZFS mirror for the Nextcloud data directory   *"
  echo "*************************************************"
  echo ""
  for ((i=0; i<${#offer[@]}; i++)); do
    read -r name size used tran model <<< "${offer[$i]}"
    printf "  [%d] %-14s %6s GB  %-5s %-28s %s\n" $((i+1)) "$name" $((size / 1000000000)) "$tran" \
      "$model" "$([ "$used" = 1 ] && echo '<- ENTHAELT DATEN / HAS DATA')"
  done
  echo ""
  local answer a b
  if [ "${#offer[@]}" -eq 2 ]; then
    read -r -p "* Aus diesen zwei Disks einen ZFS-Mirror anlegen? / Create a ZFS mirror from these two disks? [j/N] " answer
    [[ "$answer" =~ ^[jJyY]$ ]] || return
    a=1; b=2
  else
    read -r -p "* Nummern der zwei Disks (z.B. '1 2'), leer = kein ZFS / Numbers of two disks, empty = no ZFS: " a b
    [ -z "$a" ] && return
    [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ && $a -ne $b && $a -ge 1 && $b -ge 1 && $a -le ${#offer[@]} && $b -le ${#offer[@]} ]] \
      || abort "Ungültige Auswahl | Invalid selection"
    same_size "$(echo "${offer[$((a-1))]}" | awk '{print $2}')" "$(echo "${offer[$((b-1))]}" | awk '{print $2}')" \
      || abort "Die gewählten Disks sind nicht gleich gross | The selected disks differ in size"
  fi
  ZFS_DISKS=("$(echo "${offer[$((a-1))]}" | awk '{print $1}')" "$(echo "${offer[$((b-1))]}" | awk '{print $1}')")
  if echo "${offer[$((a-1))]} ${offer[$((b-1))]}" | awk '{exit !($3==1 || $8==1)}'; then
    echo ""
    echo -e "* \e[1;31mACHTUNG: Alle Daten auf ${ZFS_DISKS[*]} werden gelöscht!\033[0m"
    echo -e "* \e[1;31mWARNING: All data on ${ZFS_DISKS[*]} will be erased!\033[0m"
    read -r -p "* Zum Bestätigen LOESCHEN eingeben / Type LOESCHEN to confirm: " answer
    [ "$answer" = "LOESCHEN" ] || abort "Abgebrochen, keine Disk verändert | Aborted, no disk changed"
  fi
  echo ""
  }
###########################
# D: Erreichbarkeit       #
# E: Reachability         #
###########################
function choose_network() {
  local answer
  if [ "$NETMODE" = "ask" ]; then
    echo "*************************************************"
    echo "*  Öffentliche Erreichbarkeit / Public address  *"
    echo "*************************************************"
    echo "  [1] Feste öffentliche IP, DNS-Eintrag selbst gesetzt / static public IP, own DNS record"
    echo "  [2] DynDNS über dyndns-api.yourdevice.ch / DynDNS via dyndns-api.yourdevice.ch"
    read -r -p "* Auswahl / Choice [1/2]: " answer
    case "$answer" in
      1) NETMODE="static" ;;
      2) NETMODE="dyndns" ;;
      *) abort "Ungültige Auswahl | Invalid selection" ;;
    esac
  fi
  case "$NETMODE" in
    static) return ;;
    dyndns) ;;
    *) abort "NETMODE muss ask, static oder dyndns sein | NETMODE must be ask, static or dyndns" ;;
  esac
  if [ -z "$DYNDNS_HOSTNAME" ]; then
    read -r -p "* DynDNS-Hostname (z.B. kunde1 oder kunde1.$DYNDNS_ZONE): " DYNDNS_HOSTNAME
  fi
  DYNDNS_HOSTNAME="${DYNDNS_HOSTNAME,,}"
  DYNDNS_HOSTNAME="${DYNDNS_HOSTNAME%.}"
  [[ "$DYNDNS_HOSTNAME" == *.* ]] || DYNDNS_HOSTNAME="$DYNDNS_HOSTNAME.$DYNDNS_ZONE"
  [[ "$DYNDNS_HOSTNAME" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$ ]] \
    && [[ "$DYNDNS_HOSTNAME" == *."$DYNDNS_ZONE" ]] \
    || abort "Ungültiger Hostname für Zone $DYNDNS_ZONE | Invalid hostname for zone $DYNDNS_ZONE"
  if [ -z "$DYNDNS_KEY" ]; then
    read -r -s -p "* DynDNS-API-Key (Eingabe unsichtbar / input hidden): " DYNDNS_KEY
    echo ""
  fi
  [[ "$DYNDNS_KEY" =~ ^[0-9a-f]{64}$ ]] || abort "Der API-Key muss aus 64 Hex-Zeichen bestehen | The API key must be 64 hex characters"
  NEXTCLOUDDNS="$DYNDNS_HOSTNAME"
  }
choose_zfs_mirror
choose_network
  echo "*************************************************"
  echo -e "\033[32m*  Pre-Installationschecks erfolgreich!         *\033[0m"
  echo -e "\033[32m*  Pre-Installation checks successfull!         *\033[0m"
  echo "*************************************************"
  echo ""
  if [ "${#ZFS_DISKS[@]}" -eq 2 ]; then
  echo "* ZFS-Mirror: ${ZFS_DISKS[*]} -> $NEXTCLOUDDATAPATH"
  fi
  echo "* Domain: $NEXTCLOUDDNS ($NETMODE)"
  echo ""
  echo -e "* Press Ctrl+C To abort  // Drücke STRG+C um abzubrechen"
  seconds=5
  while [ $seconds -gt 0 ]; do
   echo -ne "* INSTALLATION STARTET IN $seconds\033[0K\r"
   sleep 1
   : $((seconds--))
  done
  echo ""
###########################
# D: Lokale IP ermitteln  #
# E: Identify local ip    #
###########################
IPA=$(hostname -I | awk '{print $1}')
###########################
# Timezone
###########################
${timedatectl} set-timezone "$CURRENTTIMEZONE"
###########################
# D: Hostdatei anpassen   #
# E: Modify host file     #
###########################
${cp} /etc/hosts /etc/hosts.bak
${sed} -i '/127.0.1.1/d' /etc/hosts
${cat} <<EOF >> /etc/hosts
127.0.1.1 $(hostname)
EOF
###########################
# D: Systemeinstellungen  #
# E: System settings      #
###########################
${apt} install -y figlet
figlet=$(command -v figlet)
${touch} /etc/motd
${figlet} Nextcloud > /etc/motd
${cat} <<EOF >> /etc/motd

      (c) yourdevice.ch
           https://www.yourdevice.ch

EOF
###########################
# Logdatei / Logfile      #
# install.log             #
###########################
exec > >(tee -i "/home/$BENUTZERNAME/Nextcloud-Installationsskript/install.log")
exec 2>&1
###########################
# D: Update-Funktion      #
# E: Update-function      #
###########################
function update_and_clean() {
  ${apt} update
  ${apt} upgrade -y
  ${apt} autoclean -y
  ${apt} autoremove -y
  }
###########################
# D: Kosmetische Funktion #
# E: Cosmetical function  #
###########################
CrI() {
  while ps "$!" > /dev/null; do
  echo -n '.'
  sleep '0.5'
  done
  ${echo} ''
  }
#############################
# D: Relevante Software     #
#    wird f. apt geblockt   #
# E: Relevant software will #
#    be blocked for apt     #
#############################
function setHOLD() {
  ${aptmark} hold nginx*
  ${aptmark} hold redis*
  ${aptmark} hold mariadb* mysql*
  ${aptmark} hold php-* php$PHPVERSION-*
  }
###########################
# D: Services neu starten #
# E: Restart services     #
###########################
function restart_all_services() {
  ${systemctl} restart nginx
  ${systemctl} restart mysql
  ${systemctl} restart redis-server php$PHPVERSION-fpm
  }
###########################
# D: NC Daten indizieren  #
# E: NC data index        #
###########################
function nextcloud_scan_data() {
  ${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ files:scan --all
  ${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ files:scan-app-data
  }
###########################
# D: ZFS-Mirror anlegen   #
# E: Create ZFS mirror    #
###########################
function setup_zfs_mirror() {
  [ "${#ZFS_DISKS[@]}" -eq 2 ] || return 0
  ${clear}
  ${echo} "ZFS-Mirror"
  ${echo} ""
  if [ -d "$NEXTCLOUDDATAPATH" ] && [ -n "$(ls -A "$NEXTCLOUDDATAPATH")" ]; then
    abort "$NEXTCLOUDDATAPATH ist nicht leer, ZFS wird nicht darüber gelegt | $NEXTCLOUDDATAPATH is not empty"
  fi
  ${apt} install -y zfsutils-linux
  # The module comes as a separate package: the meta package follows kernel
  # updates, the versioned one covers the kernel that is running right now.
  # A kernel flavour without these packages fails at modprobe below.
  local flavour
  flavour=$(uname -r | ${sed} -E 's/^[0-9.]+-[0-9]+-//')
  if apt-cache show "linux-modules-zfs-$flavour" >/dev/null 2>&1; then
    ${apt} install -y "linux-modules-zfs-$flavour"
    apt-cache show "linux-main-modules-zfs-$(uname -r)" >/dev/null 2>&1 \
      && ${apt} install -y "linux-main-modules-zfs-$(uname -r)"
  fi
  modprobe zfs || abort "Das ZFS-Kernelmodul lässt sich nicht laden, keine Disk verändert | The ZFS kernel module does not load, no disk changed"
  local ids=() d
  for d in "${ZFS_DISKS[@]}"; do
    ids+=("$(disk_id "$d")")
    wipefs -a "$d"
  done
  zpool create -f -o ashift=12 \
    -O compression=lz4 -O atime=off -O xattr=sa -O acltype=posixacl -O normalization=formD \
    -O mountpoint=none -O canmount=off \
    "$ZFSPOOL" mirror "${ids[@]}" || abort "zpool create ist fehlgeschlagen | zpool create failed"
  zfs create -o mountpoint="$NEXTCLOUDDATAPATH" "$ZFSPOOL/ncdata" || abort "zfs create ist fehlgeschlagen | zfs create failed"
  zpool status "$ZFSPOOL"
  }
###########################
# D: DynDNS-Client        #
# E: DynDNS client        #
###########################
function setup_dyndns() {
  [ "$NETMODE" = "dyndns" ] || return 0
  ${clear}
  ${echo} "DynDNS: $DYNDNS_HOSTNAME"
  ${echo} ""
  # Only the key is secret; the service reads it through LoadCredential.
  install -d -m 0755 /etc/yourdevice-dyndns
  ( umask 077; printf '%s' "$DYNDNS_KEY" > /etc/yourdevice-dyndns/key )
  ${cat} <<EOF >/etc/yourdevice-dyndns/dyndns.conf
DYNDNS_API="$DYNDNS_API"
DYNDNS_HOSTNAME="$DYNDNS_HOSTNAME"
DYNDNS_ZONE="$DYNDNS_ZONE"
EOF
  ${cat} <<'EOF' >/usr/local/sbin/yourdevice-dyndns
#!/bin/bash
# Points the DynDNS hostname at this machine's public IPv4. The API takes the
# address from the connection itself, so no IP lookup service is involved.
# The key goes to curl on stdin and never appears on a command line.
set -euo pipefail
. /etc/yourdevice-dyndns/dyndns.conf
key=$(cat "${CREDENTIALS_DIRECTORY:-/etc/yourdevice-dyndns}/key")
printf '{"key":"%s","hostname":"%s","zone":"%s"}' "$key" "$DYNDNS_HOSTNAME" "$DYNDNS_ZONE" \
  | curl -4 -fsS --max-time 30 -H 'Content-Type: application/json' --data-binary @- "$DYNDNS_API/update"
echo
EOF
  ${chmod} 755 /usr/local/sbin/yourdevice-dyndns
  ${cat} <<'EOF' >/etc/systemd/system/yourdevice-dyndns.service
[Unit]
Description=Update the yourdevice DynDNS record
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
# Runs as a throwaway user; systemd hands it the root-only key file.
DynamicUser=yes
LoadCredential=key:/etc/yourdevice-dyndns/key
ExecStart=/usr/local/sbin/yourdevice-dyndns
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes
EOF
  ${cat} <<'EOF' >/etc/systemd/system/yourdevice-dyndns.timer
[Unit]
Description=Update the yourdevice DynDNS record every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF
  ${systemctl} daemon-reload
  local response
  response=$(/usr/local/sbin/yourdevice-dyndns) || abort "DynDNS-Update fehlgeschlagen, Hostname und Key prüfen | DynDNS update failed, check hostname and key"
  ${systemctl} enable --now yourdevice-dyndns.timer
  ${echo} "DynDNS: $DYNDNS_HOSTNAME -> $(echo "$response" | jq -r '.ip // empty')"
  }
###########################
# D: Basissoftware        #
# E: Required software    #
###########################
${clear}
${echo} "Systemaktualisierungen u. Rerepositories"
${echo} "System updates and software repositories"
${echo} ""
sleep 1
${apt} update
${apt} upgrade -y
${apt} install -y apt-transport-https bash-completion bzip2 ca-certificates cron curl dialog dirmngr ffmpeg ghostscript gpg gnupg gnupg2 htop jq \
libfile-fcntllock-perl libfontconfig1 locate npm net-tools rsyslog screen smbclient socat ssl-cert tree unzip wget zip ubuntu-keyring
###########################
# D: Energiesparmodus: aus#
# E: Energy mode: off     #
###########################
${systemctl} mask sleep.target suspend.target hibernate.target hybrid-sleep.target
###########################
# D: ZFS und DynDNS       #
# E: ZFS and DynDNS       #
###########################
setup_zfs_mirror
setup_dyndns
###########################
# NGINX Repositories      #
###########################
${curl} https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu $VERSION_CODENAME nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
${echo} -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | sudo tee /etc/apt/preferences.d/99nginx
###########################
# D: Entfernen Autoupdates#
# E: Remove unatt.upgrades#
###########################
if [ $REMOVEUAU == "y" ]
then
${apt} purge -y unattended-upgrades
fi
###########################
# D: Systemaktualisierung #
# E: System update        #
###########################
update_and_clean
###########################
# D: Bereinigung          #
# E: Clean Up             #
###########################
${apt} remove -y apache2 nginx nginx-common nginx-full --allow-change-held-packages
${rm} -Rf /etc/apache2 /etc/nginx
###########################
# Installation NGINX      #
###########################
${clear}
${echo} "NGINX-Installation"
${echo} ""
sleep 1
${apt} update
${apt} install -y nginx --allow-change-held-packages
${systemctl} enable nginx.service
${mv} /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
${touch} /etc/nginx/nginx.conf
${cat} <<EOF >/etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /var/run/nginx.pid;
events {
  worker_connections 2048;
  multi_accept on;
  use epoll;
  }
http {
  ssl_early_data on;
  server_names_hash_bucket_size 64;
  access_log /var/log/nginx/access.log;
  error_log /var/log/nginx/error.log warn;
  #set_real_ip_from 127.0.0.1;
  real_ip_header X-Forwarded-For;
  real_ip_recursive on;
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  sendfile on;
  send_timeout 3600;
  tcp_nopush on;
  tcp_nodelay on;
  open_file_cache max=500 inactive=10m;
  open_file_cache_errors on;
  keepalive_timeout 65;
  reset_timedout_connection on;
  server_tokens off;
  resolver $RESOLVER valid=30s;
  resolver_timeout 5s;
  include /etc/nginx/conf.d/*.conf;
  }
EOF
###########################
# Neustart/Restart NGINX  #
###########################
systemctl restart nginx.service
###########################
# D: Verzeichnisse anlegen#
# E: Create directories   #
###########################
${mkdir} -p /var/log/nextcloud /var/www/letsencrypt/.well-known/acme-challenge /etc/letsencrypt/rsa-certs /etc/letsencrypt/ecc-certs
${chmod} -R 775 /var/www/letsencrypt
${chmod} -R 770 /etc/letsencrypt
${chown} -R www-data:www-data /var/log/nextcloud /var/www/ /etc/letsencrypt
###########################
# D: Hinzufügen ACME-User #
# E: Create ACME-user     #
###########################
# ${adduser} --system --disabled-login acmeuser
${adduser} acmeuser --gecos "" --disabled-password
${usermod} -aG www-data acmeuser
${touch} /etc/sudoers.d/acmeuser
${cat} <<EOF >/etc/sudoers.d/acmeuser
acmeuser ALL=NOPASSWD: /bin/systemctl reload nginx.service
EOF
${su} - acmeuser -c "/usr/bin/curl https://get.acme.sh | sh"
${su} - acmeuser -c ".acme.sh/acme.sh --upgrade --auto-upgrade"
${su} - acmeuser -c ".acme.sh/acme.sh --set-default-ca --server letsencrypt"
###########################
# Installation PHP        #
###########################
${clear}
${echo} "PHP-Installation"
${echo} ""
sleep 1
${apt} install -y php-{common,fpm,gd,curl,xml,zip,intl,mbstring,bz2,ldap,apcu,bcmath,gmp,imagick,igbinary,redis,smbclient,sqlite3,cli,readline} imagemagick ldap-utils nfs-common cifs-utils --allow-change-held-packages
# The PHP version is the one Ubuntu ships (8.5 on 26.04)
PHPVERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
# The ImageMagick package names carry the library ABI and differ per release
${apt} install -y "$(apt-cache pkgnames libmagickcore | grep -E -- '\.q16-[0-9]+-extra$' | sort | tail -1)" --allow-change-held-packages
IMPOLICY=$(ls /etc/ImageMagick-*/policy.xml | tail -1)
AvailableRAM=$(/usr/bin/awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
${cp} /etc/php/$PHPVERSION/fpm/pool.d/www.conf /etc/php/$PHPVERSION/fpm/pool.d/www.conf.bak
${cp} /etc/php/$PHPVERSION/fpm/php-fpm.conf /etc/php/$PHPVERSION/fpm/php-fpm.conf.bak
${cp} /etc/php/$PHPVERSION/cli/php.ini /etc/php/$PHPVERSION/cli/php.ini.bak
${cp} /etc/php/$PHPVERSION/fpm/php.ini /etc/php/$PHPVERSION/fpm/php.ini.bak
${cp} /etc/php/$PHPVERSION/mods-available/apcu.ini /etc/php/$PHPVERSION/mods-available/apcu.ini.bak
${cp} "$IMPOLICY" "$IMPOLICY.bak"
${sed} -i 's/pm = dynamic/pm = ondemand/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/;env\[HOSTNAME\] = /env[HOSTNAME] = /' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/;env\[TMP\] = /env[TMP] = /' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/;env\[TMPDIR\] = /env[TMPDIR] = /' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/;env\[TEMP\] = /env[TEMP] = /' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/;env\[PATH\] = /env[PATH] = /' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
if [ "$AvailableRAM" -ge "4096" ];then 
${sed} -i 's/pm.max_children =.*/pm.max_children = 200/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/pm.start_servers =.*/pm.start_servers = 100/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/pm.min_spare_servers =.*/pm.min_spare_servers = 60/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/pm.max_spare_servers =.*/pm.max_spare_servers = 140/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/;pm.max_requests =.*/pm.max_requests = 1000/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
else
${sed} -i 's/pm.max_children =.*/pm.max_children = 100/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/pm.start_servers =.*/pm.start_servers = 50/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/pm.min_spare_servers =.*/pm.min_spare_servers = 30/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/pm.max_spare_servers =.*/pm.max_spare_servers = 70/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
${sed} -i 's/;pm.max_requests =.*/pm.max_requests = 1000/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
fi
${sed} -i 's/output_buffering =.*/output_buffering = Off/' /etc/php/$PHPVERSION/cli/php.ini
${sed} -i 's/max_execution_time =.*/max_execution_time = 3600/' /etc/php/$PHPVERSION/cli/php.ini
${sed} -i 's/max_input_time =.*/max_input_time = 3600/' /etc/php/$PHPVERSION/cli/php.ini
${sed} -i 's/post_max_size =.*/post_max_size = 10240M/' /etc/php/$PHPVERSION/cli/php.ini
${sed} -i 's/upload_max_filesize =.*/upload_max_filesize = '$UPLOADSIZE'/' /etc/php/$PHPVERSION/cli/php.ini
${sed} -i 's|;date.timezone.*|date.timezone = '$CURRENTTIMEZONE'|' /etc/php/$PHPVERSION/cli/php.ini
${sed} -i 's/;cgi.fix_pathinfo.*/cgi.fix_pathinfo = 0/' /etc/php/$PHPVERSION/cli/php.ini
${sed} -i 's/memory_limit = 128M/memory_limit = 1G/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's/output_buffering =.*/output_buffering = Off/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's/max_execution_time =.*/max_execution_time = 3600/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's/max_input_time =.*/max_input_time = 3600/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's/post_max_size =.*/post_max_size = 10240M/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's/upload_max_filesize =.*/upload_max_filesize = '$UPLOADSIZE'/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's|;date.timezone.*|date.timezone = '$CURRENTTIMEZONE'|' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's/;session.cookie_secure.*/session.cookie_secure = True/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's/allow_url_fopen =.*/allow_url_fopen = 1/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's/;cgi.fix_pathinfo.*/cgi.fix_pathinfo = 0/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i 's/session.gc_maxlifetime =.*/session.gc_maxlifetime = 36000/' /etc/php/$PHPVERSION/fpm/php.ini
${sed} -i '$aapc.enable_cli=1' /etc/php/$PHPVERSION/mods-available/apcu.ini
# OPcache settings for PHP-FPM in their own file: from PHP 8.5 on OPcache is
# built in and there is no opcache.ini to edit.
${cat} <<EOF >/etc/php/$PHPVERSION/fpm/conf.d/90-nextcloud-opcache.ini
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=100000
opcache.validate_timestamps=1
opcache.revalidate_freq=0
opcache.save_comments=1
opcache.huge_code_pages=0
opcache.jit=1255
opcache.jit_buffer_size=256M
EOF
${sed} -i 's|;emergency_restart_threshold.*|emergency_restart_threshold = 10|g' /etc/php/$PHPVERSION/fpm/php-fpm.conf
${sed} -i 's|;emergency_restart_interval.*|emergency_restart_interval = 1m|g' /etc/php/$PHPVERSION/fpm/php-fpm.conf
${sed} -i 's|;process_control_timeout.*|process_control_timeout = 10|g' /etc/php/$PHPVERSION/fpm/php-fpm.conf
${sed} -i 's/rights=\"none\" pattern=\"PS\"/rights=\"read|write\" pattern=\"PS\"/' "$IMPOLICY"
${sed} -i 's/rights=\"none\" pattern=\"EPS\"/rights=\"read|write\" pattern=\"EPS\"/' "$IMPOLICY"
${sed} -i 's/rights=\"none\" pattern=\"PDF\"/rights=\"read|write\" pattern=\"PDF\"/' "$IMPOLICY"
${sed} -i 's/rights=\"none\" pattern=\"XPS\"/rights=\"read|write\" pattern=\"XPS\"/' "$IMPOLICY"
if [ ! -e "/usr/bin/gs" ]; then
${ln} -s /usr/local/bin/gs /usr/bin/gs
fi
###########################
# Neustart/Restart PHP    #
###########################
${systemctl} restart php$PHPVERSION-fpm
${systemctl} restart nginx
###########################
# Installation DB         #
###########################
${clear}
${echo} "DB-Installation"
${echo} ""
sleep 1
        ${apt} install -y php-mysql libdbd-mysql-perl libmariadb3 mariadb-common mysql-common mariadb-server mariadb-client --allow-change-held-packages
        ${cp} /etc/php/$PHPVERSION/fpm/conf.d/20-mysqli.ini /etc/php/$PHPVERSION/fpm/conf.d/20-mysqli.ini.bak
        ${cat} <<EOF >>/etc/php/$PHPVERSION/fpm/conf.d/20-mysqli.ini
[mysql]
mysql.allow_local_infile=On
mysql.allow_persistent=On
mysql.cache_size=2000
mysql.max_persistent=-1
mysql.max_links=-1
mysql.default_port=3306
mysql.connect_timeout=60
mysql.trace_mode=Off
EOF
        ${systemctl} stop mysql
        # A fresh MariaDB 11.8 lives in /var/lib/mariadb; the package keeps using
        # /var/lib/mysql only when that directory already existed
        MARIADBDATADIR=/var/lib/mysql
        [ -d /var/lib/mariadb ] && MARIADBDATADIR=/var/lib/mariadb
        # InnoDB buffer pool: a quarter of the RAM, between 512 MB and 4 GB, so a
        # Raspberry Pi keeps room for PHP-FPM and Redis
        MARIADBBUFFER=$(/usr/bin/awk '/MemTotal/ {m = int($2 / 1024 / 4); if (m < 512) m = 512; if (m > 4096) m = 4096; print m "M"}' /proc/meminfo)
        ${cp} /etc/mysql/my.cnf /etc/mysql/my.cnf.bak
        ${cat} <<EOF >/etc/mysql/my.cnf
[client]
default-character-set = utf8mb4
port = 3306
socket = /var/run/mysqld/mysqld.sock
[mysqld_safe]
log_error=/var/log/mysql/mysql_error.log
nice = 0
socket = /var/run/mysqld/mysqld.sock
[mysqld]
# performance_schema=ON
basedir = /usr
bind-address = 127.0.0.1
binlog_format = ROW
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
datadir = $MARIADBDATADIR
default_storage_engine = InnoDB
expire_logs_days = 2
slave_connections_needed_for_purge = 0
general_log_file = /var/log/mysql/mysql.log
innodb_buffer_pool_size = $MARIADBBUFFER
innodb_log_buffer_size = 32M
innodb_log_file_size = 512M
innodb_read_only_compressed=OFF
join_buffer_size = 2M
key_buffer_size = 512M
lc_messages_dir = /usr/share/mysql
lc_messages = en_US
log_bin = /var/log/mysql/mariadb-bin
log_bin_index = /var/log/mysql/mariadb-bin.index
log_bin_trust_function_creators = true
log_error = /var/log/mysql/mysql_error.log
log_slow_verbosity = query_plan
log_warnings = 2
long_query_time = 1
max_connections = 100
max_heap_table_size = 64M
max_allowed_packet = 512M
max-binlog-size = 512M
max_binlog_total_size = 2G
myisam_sort_buffer_size = 512M
port = 3306
pid-file = /var/run/mysqld/mysqld.pid
query_cache_limit = 0
query_cache_size = 0 
read_buffer_size = 2M
read_rnd_buffer_size = 2M
skip-name-resolve
socket = /var/run/mysqld/mysqld.sock
sort_buffer_size = 2M
table_open_cache = 400
table_definition_cache = 800
tmp_table_size = 32M
tmpdir = /tmp
transaction_isolation = READ-COMMITTED
user = mysql
wait_timeout = 600
[mariadb-dump]
max_allowed_packet = 512M
quick
quote-names
[isamchk]
key_buffer = 16M
EOF
mkdir -p /var/log/mysql
chown -R mysql:mysql /var/log/mysql
${systemctl} restart mysql || abort "MariaDB startet nicht (journalctl -u mariadb) | MariaDB does not start"
mysql=$(command -v mariadb)
${mysql} -e "CREATE DATABASE ${NCDBNAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
${mysql} -e "CREATE USER ${NCDBUSER}@localhost IDENTIFIED BY '${NCDBPASSWORD}';"
${mysql} -e "CREATE USER ${NCDBUSER}@127.0.0.1 IDENTIFIED BY '${NCDBPASSWORD}';"
${mysql} -e "GRANT ALL PRIVILEGES ON ${NCDBNAME}.* TO '${NCDBUSER}'@'localhost';"
${mysql} -e "GRANT ALL PRIVILEGES ON ${NCDBNAME}.* TO '${NCDBUSER}'@'127.0.0.1';"
${mysql} -e "FLUSH PRIVILEGES;"
mysql_secure_installation=$(command -v mariadb-secure-installation)
cat <<EOF | ${mysql_secure_installation}
\n
n
y
y
y
y
EOF
        mariadb -u root -e "SET PASSWORD FOR root@'localhost' = PASSWORD('$MARIADBROOTPASSWORD'); FLUSH PRIVILEGES;"
###########################
# Installation Redis      #
###########################
${clear}
${echo} "REDIS-Installation"
${echo} ""
${apt} install -y redis-server redis-tools --allow-change-held-packages
${cp} /etc/redis/redis.conf /etc/redis/redis.conf.bak
${sed} -i 's/port 6379/port 0/' /etc/redis/redis.conf
# The commented default path differs between Redis packages; any of them is replaced
${sed} -i 's|^# *unixsocket /.*|unixsocket /var/run/redis/redis-server.sock|' /etc/redis/redis.conf
${sed} -i 's/\# unixsocketperm 700/unixsocketperm 770/' /etc/redis/redis.conf
${sed} -i 's/\# maxclients 10000/maxclients 10240/' /etc/redis/redis.conf
${sed} -i "s/\# requirepass foobared/requirepass $REDISPASSWORD/" /etc/redis/redis.conf
${echo} "vm.overcommit_memory = 1" > /etc/sysctl.d/99-redis.conf
sysctl -q -p /etc/sysctl.d/99-redis.conf
${usermod} -a -G redis www-data
###########################
# Self-Signed-SSL         #
###########################
${apt} install -y ssl-cert
###########################
# NGINX TLS               #
###########################
[ -f /etc/nginx/conf.d/default.conf ] && ${mv} /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
${touch} /etc/nginx/conf.d/default.conf
${touch} /etc/nginx/conf.d/http.conf
${cat} <<EOF >/etc/nginx/conf.d/http.conf
upstream php-handler {
  server unix:/run/php/php$PHPVERSION-fpm.sock;
  }
map \$arg_v \$asset_immutable {
    "" "";
    default "immutable";
}
  server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name cloud.server.io;
    root /var/www;
    location ^~ /.well-known/acme-challenge {
      default_type text/plain;
      root /var/www/letsencrypt;
      }
    location / {
      return 301 https://\$host\$request_uri;
      }
   }
EOF
${cat} <<EOF >/etc/nginx/conf.d/nextcloud.conf
limit_req_zone \$binary_remote_addr zone=NextcloudRateLimit:10m rate=2r/s;
server {
  listen 443 ssl;
  listen [::]:443 ssl;
  http2 on;
  server_name cloud.server.io;
  ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
  ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
  ssl_trusted_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
  #ssl_certificate /etc/letsencrypt/rsa-certs/fullchain.pem;
  #ssl_certificate_key /etc/letsencrypt/rsa-certs/privkey.pem;
  #ssl_certificate /etc/letsencrypt/ecc-certs/fullchain.pem;
  #ssl_certificate_key /etc/letsencrypt/ecc-certs/privkey.pem;
  #ssl_trusted_certificate /etc/letsencrypt/ecc-certs/chain.pem;
  ssl_dhparam /etc/ssl/certs/dhparam.pem;
  ssl_session_timeout 1d;
  ssl_session_cache shared:SSL:50m;
  ssl_session_tickets off;
  ssl_protocols TLSv1.3 TLSv1.2;
  ssl_ciphers 'TLS-CHACHA20-POLY1305-SHA256:TLS-AES-256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384';
  ssl_ecdh_curve X448:secp521r1:secp384r1;
  ssl_prefer_server_ciphers on;
  client_max_body_size 10G;
  client_body_timeout 3600s;
  client_body_buffer_size 512k;
  fastcgi_buffers 64 4K;
  gzip on;
  gzip_vary on;
  gzip_comp_level 4;
  gzip_min_length 256;
  gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
  gzip_types application/atom+xml text/javascript application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/wasm application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;
  add_header Strict-Transport-Security            "max-age=15768000; includeSubDomains; preload;" always;
  add_header Permissions-Policy                   "interest-cohort=()";
  add_header Referrer-Policy                      "no-referrer"   always;
  add_header X-Content-Type-Options               "nosniff"       always;
  add_header X-Download-Options                   "noopen"        always;
  add_header X-Frame-Options                      "SAMEORIGIN"    always;
  add_header X-Permitted-Cross-Domain-Policies    "none"          always;
  add_header X-Robots-Tag                         "noindex, nofollow" always;
  add_header X-XSS-Protection                     "1; mode=block" always;
  fastcgi_hide_header X-Powered-By;
  include mime.types;
  types {
  text/javascript mjs;
	  }
  root /var/www/nextcloud;
  index index.php index.html /index.php\$request_uri;
  location = / {
    if ( \$http_user_agent ~ ^DavClnt ) {
      return 302 /remote.php/webdav/\$is_args\$args;
      }
  }
  location = /robots.txt {
    allow all;
    log_not_found off;
    access_log off;
    }
  location ^~ /.well-known {
    location = /.well-known/carddav { return 301 /remote.php/dav/; }
    location = /.well-known/caldav  { return 301 /remote.php/dav/; }
    location /.well-known/acme-challenge { try_files \$uri \$uri/ =404; }
    location /.well-known/pki-validation { try_files \$uri \$uri/ =404; }
    return 301 /index.php\$request_uri;
    }
  location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)(?:\$|/)  { return 404; }
  location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console)  { return 404; }
  location ~ \.php(?:\$|/) {
    rewrite ^/(?!index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|ocs-provider\/.+|.+\/richdocumentscode\/proxy) /index.php\$request_uri;
    fastcgi_split_path_info ^(.+?\.php)(/.*)\$;
    set \$path_info \$fastcgi_path_info;
    try_files \$fastcgi_script_name =404;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_param PATH_INFO \$path_info;
    fastcgi_param HTTPS on;
    fastcgi_param modHeadersAvailable true;
    fastcgi_param front_controller_active true;
    fastcgi_pass php-handler;
    fastcgi_intercept_errors on;
    fastcgi_request_buffering on;
    fastcgi_read_timeout 3600;
    fastcgi_send_timeout 3600;
    fastcgi_connect_timeout 3600;
    fastcgi_max_temp_file_size 0;
    }
    location ~ \.(?:css|js|mjs|svg|gif|ico|jpg|png|webp|wasm|tflite|map|ogg|flac)$ {
    try_files \$uri /index.php\$request_uri;
    add_header Cache-Control                        "public, max-age=15778463, \$asset_immutable";
    add_header Permissions-Policy                   "interest-cohort=()";
    add_header Referrer-Policy                      "no-referrer"   always;
    add_header X-Content-Type-Options               "nosniff"       always;
    add_header X-Download-Options                   "noopen"        always;
    add_header X-Frame-Options                      "SAMEORIGIN"    always;
    add_header X-Permitted-Cross-Domain-Policies    "none"          always;
    add_header X-Robots-Tag                         "noindex, nofollow" always;
    add_header X-XSS-Protection                     "1; mode=block" always;
    expires 6M;
    access_log off;
    location ~ \.wasm\$ {
      default_type application/wasm;
      }
    }
  location ~ \.(otf|woff2?)$ {
    try_files \$uri /index.php\$request_uri;
    expires 7d;
    access_log off;
    }
  location /remote {
    return 301 /remote.php\$request_uri;
    }
  location /login {
    limit_req zone=NextcloudRateLimit burst=5 nodelay;
    limit_req_status 429;
    try_files \$uri \$uri/ /index.php\$request_uri;
    }    
  location / {
    try_files \$uri \$uri/ /index.php\$request_uri;
    }
}
EOF
${clear}
${echo} "Diffie-Hellman key:"
${echo} ""
/usr/bin/openssl dhparam -dsaparam -out /etc/ssl/certs/dhparam.pem 4096
${echo} ""
sleep 1
###########################
# Hostname                #
###########################
${sed} -i "s/server_name cloud.server.io;/server_name $(hostname) $NEXTCLOUDDNS;/" /etc/nginx/conf.d/http.conf
${sed} -i "s/server_name cloud.server.io;/server_name $(hostname) $NEXTCLOUDDNS;/" /etc/nginx/conf.d/nextcloud.conf
###########################
# Nextcloud-CRON          #
###########################
(/usr/bin/crontab -u www-data -l ; echo "*/5 * * * * /usr/bin/php -f /var/www/nextcloud/cron.php > /dev/null 2>&1") | /usr/bin/crontab -u www-data -
###########################
# Neustart/Restart NGINX  #
###########################
${systemctl} restart nginx
${clear}
###########################
# Herunterladen/Download  #
# Nextcloud               #
###########################
${echo} "Downloading:" $NCRELEASE
${wget} -q https://download.nextcloud.com/server/releases/$NCRELEASE & CrI
#${wget} -q https://download.nextcloud.com/server/releases/$NCRELEASE.md5
${echo} ""
#${echo} "Verify Checksum (MD5):"
#if [ "$(md5sum -c $NCRELEASE.md5 < $NCRELEASE | awk '{ print $2 }')" = "OK" ]
#then
#md5sum -c $NCRELEASE.md5 < $NCRELEASE
#${echo} ""
#else
#${clear}
#${echo} ""
#${echo} "CHECKSUM ERROR => SECURITY ALERT => ABBRUCH!"
#exit 1
#fi
${echo} "Extracting:" $NCRELEASE
${apt} install -y bzip2
${tar} -xjf $NCRELEASE -C /var/www & CrI
${chown} -R www-data:www-data /var/www/
${rm} -f $NCRELEASE $NCRELEASE.md5
restart_all_services
###########################
# Nextcloud Installation  #
###########################
${clear}
${echo} "Nextcloud Installation"
${echo} ""
if [[ ! -e $NEXTCLOUDDATAPATH ]];
then
${mkdir} -p $NEXTCLOUDDATAPATH
fi
${chown} -R www-data:www-data $NEXTCLOUDDATAPATH
${echo} "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""
${echo} "Die Nextcloud wird jetzt 'silent' installiert - bitte haben Sie Geduld!"
${echo} "Your Nextcloud will now be installed silently - please be patient!"
${echo} ""
sudo -u www-data php /var/www/nextcloud/occ maintenance:install --database "mysql" --database-name "${NCDBNAME}" --database-user "${NCDBUSER}" --database-pass "${NCDBPASSWORD}" --admin-user "${NEXTCLOUDADMINUSER}" --admin-pass "${NEXTCLOUDADMINUSERPASSWORD}" --data-dir "${NEXTCLOUDDATAPATH}"
${echo} ""
sleep 1
declare -l YOURSERVERNAME
YOURSERVERNAME=$(hostname)
###########################
# Optimieren/Optimizing   #
# Nextcloud config.php    #
###########################
${sudo} -u www-data ${cp} /var/www/nextcloud/config/config.php /var/www/nextcloud/config/config.php.bak
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set trusted_domains 0 --value="$YOURSERVERNAME"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set trusted_domains 1 --value="$NEXTCLOUDDNS"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set trusted_domains 2 --value="$IPA"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set overwrite.cli.url --value=https://"$NEXTCLOUDDNS"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set overwritehost --value="$NEXTCLOUDDNS"
${echo} ""
${echo} "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${cp} /var/www/nextcloud/.user.ini /usr/local/src/.user.ini.bak
${sudo} -u www-data ${sed} -i 's/output_buffering=.*/output_buffering=0/' /var/www/nextcloud/.user.ini
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ background:cron
${sed} -i '/);/d' /var/www/nextcloud/config/config.php
${cat} <<EOF >>/var/www/nextcloud/config/config.php
  'activity_expire_days' => 14,
  'allow_local_remote_servers' => true,
  'auth.bruteforce.protection.enabled' => true,
  'forbidden_filenames' =>
  array (
    0 => '.htaccess',
    1 => 'Thumbs.db',
    2 => 'thumbs.db',
    ),
    'cron_log' => true,
    'default_phone_region' => '$PHONEREGION',
    'enable_previews' => true,
    'enabledPreviewProviders' =>
        array (
      0 => 'OC\\Preview\\PNG',
      1 => 'OC\\Preview\\JPEG',
      2 => 'OC\\Preview\\GIF',
      3 => 'OC\\Preview\\BMP',
      4 => 'OC\\Preview\\XBitmap',
      5 => 'OC\\Preview\\Movie',
      6 => 'OC\\Preview\\PDF',
      7 => 'OC\\Preview\\MP3',
      8 => 'OC\\Preview\\TXT',
      9 => 'OC\\Preview\\MarkDown',
      10 => 'OC\\Preview\\HEIC',
      11 => 'OC\\Preview\\Movie',
      12 => 'OC\\Preview\\MKV',
      13 => 'OC\\Preview\\MP4',
      14 => 'OC\\Preview\\AVI',
      ),
      'filesystem_check_changes' => 0,
      'filelocking.enabled' => 'true',
      'htaccess.RewriteBase' => '/',
      'integrity.check.disabled' => false,
      'knowledgebaseenabled' => false,
      'log_rotate_size' => '104857600',
      'logfile' => '/var/log/nextcloud/$NEXTCLOUDDNS.log',
      'loglevel' => 2,
      'logtimezone' => '$CURRENTTIMEZONE',
      'remember_login_cookie_lifetime' => 36000,
      'session_lifetime' => 36000,
      'session_keepalive' => true,
      'auto_logout' => true,
      'memcache.local' => '\\\\OC\\\\Memcache\\\\APCu',
      'memcache.locking' => '\\\\OC\\\\Memcache\\\\Redis',
      'minimum.supported.desktop.version' => '4.0.1',
      // 'maximum.supported.desktop.version' => 'x.y.u',
      'overwriteprotocol' => 'https',
      'preview_max_x' => 1024,
      'preview_max_y' => 768,
      'preview_max_scale_factor' => 1,
      'profile.enabled' => false,
      'redis' =>
      array (
        'host' => '/var/run/redis/redis-server.sock',
        'port' => 0,
        'password' => '$REDISPASSWORD',
        'timeout' => 0.5,
        'dbindex' => 1,
        ),
      'quota_include_external_storage' => false,
      'share_folder' => '/Freigaben',
      'skeletondirectory' => '',
      'trashbin_retention_obligation' => 'auto, 7',
      'maintenance_window_start' => 1,
      );
EOF
${sed} -i 's/^[ ]*//' /var/www/nextcloud/config/config.php
###########################
# Nextcloud Berechtigungen#
# Nextcloud Permissions   #
###########################
${chown} -R www-data:www-data /var/www
###########################
# Neustart/Restart        #
###########################
restart_all_services
###########################
###########################
# Installation fail2ban   #
###########################
${clear}
${echo} "fail2ban-Installation"
${echo} ""
sleep 1
${apt} install -y fail2ban --allow-change-held-packages
${touch} /etc/fail2ban/filter.d/nextcloud.conf
${cat} <<EOF >/etc/fail2ban/filter.d/nextcloud.conf
[Definition]
_groupsre = (?:(?:,?\s*"\w+":(?:"[^"]+"|\w+))*)
failregex = ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Login failed:
            ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Two-factor challenge failed:
            ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Trusted domain error.
datepattern = ,?\s*"time"\s*:\s*"%%Y-%%m-%%d[T ]%%H:%%M:%%S(%%z)?"
EOF
${touch} /etc/fail2ban/jail.d/nextcloud.local
${cat} <<EOF >/etc/fail2ban/jail.d/nextcloud.local
[DEFAULT]
maxretry=3
bantime=1800
findtime = 1800
[nextcloud]
backend = auto
enabled = true
port = 80,443
protocol = tcp
filter = nextcloud
maxretry = 5
logpath = /var/log/nextcloud/$NEXTCLOUDDNS.log
[nginx-http-auth]
enabled = true
EOF
${touch} /var/log/nextcloud/$NEXTCLOUDDNS.log
${chown} -R www-data:www-data /var/log/nextcloud/$NEXTCLOUDDNS.log
${systemctl} enable --now fail2ban
${systemctl} restart fail2ban
###########################
# Installation crowdsec   #
###########################
${clear}
echo ""
${echo} " » Crowdsec-Installation"
${echo} ""
sleep 1
# packagecloud has no repository for 26.04; its noble (24.04) packages are used
# (amd64 and arm64).
${curl} -fsSL https://packagecloud.io/crowdsec/crowdsec/gpgkey | gpg --dearmor -o /usr/share/keyrings/crowdsec-archive-keyring.gpg
${echo} "deb [signed-by=/usr/share/keyrings/crowdsec-archive-keyring.gpg] https://packagecloud.io/crowdsec/crowdsec/ubuntu/ noble main" > /etc/apt/sources.list.d/crowdsec.list
${apt} update
${apt} install -y crowdsec
${apt} install -y crowdsec-firewall-bouncer-iptables
${systemctl} reload crowdsec.service
${systemctl} enable crowdsec.service crowdsec-firewall-bouncer.service
${systemctl} restart crowdsec.service crowdsec-firewall-bouncer.service
cscli collections install crowdsecurity/nginx
cscli parsers install crowdsecurity/nginx-logs
cscli scenarios install crowdsecurity/nginx-req-limit-exceeded
cscli collections install crowdsecurity/nextcloud
cscli collections install crowdsecurity/nextcloud
cscli scenarios install crowdsecurity/nextcloud-bf
cscli parsers install crowdsecurity/nextcloud-logs
cscli parsers install crowdsecurity/nextcloud-whitelist
cscli collections install crowdsecurity/sshd
cscli scenarios install crowdsecurity/ssh-bf
cscli scenarios install crowdsecurity/ssh-slow-bf
cscli parsers install crowdsecurity/sshd-success-logs
cscli parsers install crowdsecurity/sshd-logs
${systemctl} reload crowdsec.service
${systemctl} restart crowdsec.service crowdsec-firewall-bouncer.service
${touch} /etc/crowdsec/acquis.d/setup.nextcloud.yaml
${cat} <<EOF >>/etc/crowdsec/acquis.d/setup.nextcloud.yaml
#Nextcloud by c-rieger.de
filenames:
 - /var/log/nextcloud/$NEXTCLOUDDNS.log
labels:
  type: Nextcloud
---
EOF
${systemctl} restart crowdsec.service crowdsec-firewall-bouncer.service
###########################
# Installation ufw        #
###########################
${clear}
${echo} "ufw-Installation"
${echo} ""
sleep 1
${apt} install -y ufw --allow-change-held-packages
ufw=$(command -v ufw)
${ufw} allow 80/tcp comment "LetsEncrypt(http)"
${ufw} allow 443/tcp comment "TLS(https)"
SSHPORT=$(grep -w Port /etc/ssh/sshd_config | awk '/Port / {print $2}')
${ufw} allow "$SSHPORT"/tcp comment "SSH"
${ufw} logging medium && ${ufw} default deny incoming
${cat} <<EOF | ${ufw} enable
y
EOF
${systemctl} restart redis-server.service ufw.service
###########################
# D: Nextcloud Anpassungen#
# E: Nextcloud customizing#
###########################
${clear}
${echo} "Nextcloud-Anpassungen/-Customizing"
${echo} ""
sleep 1
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable app_api
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable survey_client
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable firstrunwizard
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable federation
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable logreader
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:app:set settings profile_enabled_by_default --value="0"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:enable admin_audit
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:app:set files_sharing hide_disabled_user_shares --value yes
if [ $NEXTCLOUDOFFICE == "y" ]
then
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:install richdocuments
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:install richdocumentscode
fi
if [ $ONLYOFFICE == "y" ]
then
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:install documentserver_community
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:install onlyoffice
fi
rediscli=$(command -v redis-cli)
${rediscli} -s /var/run/redis/redis-server.sock <<EOF
FLUSHALL
quit
EOF
${systemctl} stop nginx
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ db:add-missing-primary-keys
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ db:add-missing-indices
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ db:add-missing-columns
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ db:convert-filecache-bigint
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ maintenance:repair --include-expensive
${clear}
nextcloud_scan_data
${systemctl} restart nginx
${echo} ""
${echo} "Systemoptimierungen / System optimizations"
${echo} ""
${echo} "Dieser Vorgang kann mehrere Minuten dauern - bitte haben Sie Geduld!"
${echo} "It will take a few minutes - please be patient!"
${echo} ""
${sudo} -u www-data /usr/bin/php -f /var/www/nextcloud/cron.php & CrI
###########################
# Sperren/Hold Software   #
###########################
setHOLD
###########################
# D: LE-Zertifikate       #
# E: LE certificates      #
###########################
# DynDNS hostnames are validated through DNS (DNS-01): the API sets the TXT
# record, so neither issuing nor renewal needs port 80 to be reachable. The
# acme.sh hook lives next to acme.sh, outside the folders its upgrades replace.
if [ "$NETMODE" == "dyndns" ]
then
${chown} root:acmeuser /etc/yourdevice-dyndns/key
${chmod} 640 /etc/yourdevice-dyndns/key
${cat} <<'EOF' >/home/acmeuser/.acme.sh/dns_yourdevice.sh
#!/usr/bin/env sh
# acme.sh DNS hook: sets the DNS-01 TXT record through the yourdevice DynDNS
# API. The key of this machine is only valid for its own hostname.
dns_yourdevice_add() {
  _yourdevice_acme "$1" "$2" /acme-challenge
}
dns_yourdevice_rm() {
  _yourdevice_acme "$1" "$2" /acme-challenge/delete
}
_yourdevice_acme() {
  . /etc/yourdevice-dyndns/dyndns.conf
  _yd_key=$(cat /etc/yourdevice-dyndns/key) || return 1
  printf '{"key":"%s","hostname":"%s","zone":"%s","value":"%s"}' \
    "$_yd_key" "${1#_acme-challenge.}" "$DYNDNS_ZONE" "$2" \
    | curl -4 -fsS --max-time 30 -H 'Content-Type: application/json' --data-binary @- "$DYNDNS_API$3" >/dev/null
}
EOF
${chown} acmeuser:acmeuser /home/acmeuser/.acme.sh/dns_yourdevice.sh
fi
# The same script can be run again later if issuing fails during installation.
${cat} <<'EOF' >/usr/local/sbin/nextcloud-le-cert
#!/bin/bash
# Requests the RSA and the ECC certificate for the Nextcloud domain from
# Let's Encrypt. nginx serves both, so it switches from the placeholder
# certificate only once both exist; otherwise nginx keeps running unchanged.
DOMAIN="$1"
# The DynDNS hostname is validated via DNS, any other domain via port 80.
CHALLENGE=(-w /var/www/letsencrypt)
if [ -f /etc/yourdevice-dyndns/dyndns.conf ] && . /etc/yourdevice-dyndns/dyndns.conf \
   && [ "$DOMAIN" = "$DYNDNS_HOSTNAME" ]; then
  CHALLENGE=(--dns dns_yourdevice --dnssleep 30)
fi
for spec in "4096 rsa-certs" "ec-384 ecc-certs"; do
  read -r keylength dir <<< "$spec"
  sudo -i -u acmeuser /home/acmeuser/.acme.sh/acme.sh --issue -d "$DOMAIN" --server letsencrypt \
    --keylength "$keylength" "${CHALLENGE[@]}" \
    --key-file "/etc/letsencrypt/$dir/privkey.pem" --ca-file "/etc/letsencrypt/$dir/chain.pem" \
    --cert-file "/etc/letsencrypt/$dir/cert.pem" --fullchain-file "/etc/letsencrypt/$dir/fullchain.pem" \
    --reloadcmd "sudo /bin/systemctl reload nginx.service"
done
CONF=/etc/nginx/conf.d/nextcloud.conf
if [ -s /etc/letsencrypt/rsa-certs/fullchain.pem ] && [ -s /etc/letsencrypt/ecc-certs/fullchain.pem ]; then
  if grep -q ssl-cert-snakeoil "$CONF"; then
    cp "$CONF" "$CONF.placeholder"
    sed -i '/ssl-cert-snakeoil/d' "$CONF"
    sed -i 's/#ssl/ssl/g' "$CONF"
    # Never leave nginx with a configuration it cannot load
    if ! nginx -t || ! systemctl restart nginx; then
      cp "$CONF.placeholder" "$CONF"
      systemctl restart nginx
      echo "Let's Encrypt: nginx lädt die Zertifikate nicht, Platzhalter bleibt aktiv | nginx rejects the certificates" >&2
      exit 1
    fi
  fi
  exit 0
fi
echo "Let's Encrypt: kein Zertifikat für $DOMAIN | no certificate for $DOMAIN" >&2
exit 1
EOF
${chmod} 750 /usr/local/sbin/nextcloud-le-cert
if /usr/local/sbin/nextcloud-le-cert "$NEXTCLOUDDNS"; then
LECERT="ok"
else
LECERT="failed"
fi
###########################
# System information-just #
# for logging purposes    #
###########################
${echo} ""
${echo} "$CURRENTTIMEZONE"
${echo} ""
${date}
${echo} ""
$lsbrelease -ar
###########################
# D: Update-Skript anlegen#
# E: Create Update-Script #
###########################
cd /home/"$BENUTZERNAME"/
${wget} -q https://raw.githubusercontent.com/warioishere/nextcloud-deploy/main/scripts/update.sh
${chmod} +x /home/"$BENUTZERNAME"/update.sh
${sed} -i "s/^PHPVERSION=.*/PHPVERSION=\"$PHPVERSION\"/" /home/"$BENUTZERNAME"/update.sh
###########################
# D: Abschlußbildschirm   #
# E: Final screen         #
###########################
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable support
${clear}
${echo} "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""
${echo} "Server - IP(v4):"
${echo} "----------------"
${echo} "$IPA"
${echo} ""
${echo} "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""
${echo} "Nextcloud:"
${echo} ""
${echo} "https://$NEXTCLOUDDNS oder/or https://$IPA"
${echo} ""
${echo} "*******************************************************************************"
${echo} ""
${echo} "Nextcloud User/Pwd: $NEXTCLOUDADMINUSER // $NEXTCLOUDADMINUSERPASSWORD"
${echo} ""
${echo} "Passwordreset     : sudo -s"
${echo} "                    source /root/.bash_aliases"
${echo} "                    nocc user:resetpassword $NEXTCLOUDADMINUSER"
${echo} ""
${echo} "Nextcloud datapath: $NEXTCLOUDDATAPATH"
if [ "${#ZFS_DISKS[@]}" -eq 2 ]
then
${echo} "ZFS-Mirror        : $ZFSPOOL (${ZFS_DISKS[*]}) - zpool status $ZFSPOOL"
fi
if [ "$NETMODE" == "dyndns" ]
then
${echo} "DynDNS            : $NEXTCLOUDDNS (systemctl status yourdevice-dyndns.timer)"
fi
${echo} ""
if [ "$LECERT" == "ok" ]
then
${echo} "Let's Encrypt     : OK"
else
${echo} -e "\e[1;31mLet's Encrypt     : FEHLGESCHLAGEN / FAILED - Platzhalter-Zertifikat aktiv\033[0m"
if [ "$NETMODE" == "dyndns" ]
then
${echo} "                    DynDNS-Key und Erreichbarkeit von $DYNDNS_API pruefen, dann:"
else
${echo} "                    DNS $NEXTCLOUDDNS -> diese Maschine und Port 80 pruefen, dann:"
fi
${echo} "                    sudo /usr/local/sbin/nextcloud-le-cert $NEXTCLOUDDNS"
fi
${echo} ""
${echo} "Nextcloud DB      : $NCDBNAME"
${echo} "Nextcloud DB-User : $NCDBUSER / $NCDBPASSWORD"
${echo} ""
${echo} "MariaDB-Rootpwd   : $MARIADBROOTPASSWORD"
${echo} ""
${echo} "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""
${cat} /etc/motd
###########################
# Nextcloud-Log           #
###########################
${rm} -f /var/log/nextcloud/$NEXTCLOUDDNS.log
${sudo} -u www-data ${touch} /var/log/nextcloud/$NEXTCLOUDDNS.log
###########################
# occ Aliases (nocc)      #
###########################
if [ ! -f /root/.bash_aliases ]; then touch /root/.bash_aliases; fi
cat <<EOF >> /root/.bash_aliases
alias nocc="sudo -u www-data php /var/www/nextcloud/occ"
EOF
###########################
# Bereinigung/Clean Up    #
###########################
${cat} /dev/null > ~/.bash_history
###########################
# Laufzeit Berechnung     #
# Calculating runtime     #
###########################
${echo} ""
end=$(date +%s)
runtime=$((end-start))
echo ""
if [ "$runtime" -lt 60 ] || [ $runtime -ge "120" ]; then
echo "Installation process completed in $((runtime/60)) minutes and $((runtime%60)) seconds."
else
echo "Installation process completed in $((runtime/60)) minute and $((runtime%60)) seconds."
echo ""
fi
${echo} "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""
exit 0
