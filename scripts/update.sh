#!/bin/bash
# Nextcloud-Updateskript 05.11.2025
#
# - Changes: 
# - Ermitteln der Nextcloud Apps ($NEXTCLOUDAPPS)
# - Stoppen, Deaktivieren, Reaktivieren, Starten des Webservers
# - Reaktivieren der vor dem Update aktiven Apps ($NEXTCLOUDAPPS)
#
# ---------------------------------------------------------------
# Bitte setzen Sie diese Parameter entsprechend Ihrer Nextcloud
# ---------------------------------------------------------------
WEBSERVER="nginx"
# alternativ "apache2"

PHPVERSION="8.3"
# alternativ "8.4"

DPATH="/var/www/nextcloud"
# alternativ "/Pfad/zur/Nextcloud-Software"

SPATH="/sicherung/sql"
SNPATH="/sicherung/nextcloud"
# Sicherungverzeichnisse angeben

# --------------------------------------------------------------
# »»» Ab hier KEINE Änderungen mehr vornehmen! «««
# --------------------------------------------------------------
clear
if [ -f /tmp/ncupdateskript ]; then
        echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        echo " » Das Updateskript ist bereits aktiv - *ABBRUCH*"
        echo " » Oder wurde ein vorheriger Prozess abgebrochen?"
	    echo ""
	    echo " » "$(ls /tmp/ncupdateskript)
	    echo ""
        echo " » Entfernen Sie ggf. die Datei mit diesem Befehl:"
        echo " » sudo rm -f /tmp/ncupdateskript"     
        echo ""
        echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        exit 1
fi
if [ "$USER" != "root" ]
then
    echo ""
    echo " » KEINE ROOT-BERECHTIGUNGEN | NO ROOT PERMISSIONS"
    echo ""
    echo "------------------------------------------------------------"
    echo " » Bitte starten Sie das Skript als root: 'sudo ./update.sh'"
    echo " » Please run this script as root using:  'sudo ./update.sh'"
    echo "------------------------------------------------------------"
    echo ""
    exit 1
fi
touch /tmp/ncupdateskript
echo ""
echo " » Die Parameter der Nextcloud werden ermittelt..."
echo ""
NEXTCLOUDVERSION=$(sudo -u www-data php $DPATH/occ config:system:get version)
NEXTCLOUDDATEN=$(sudo -u www-data php $DPATH/occ config:system:get datadirectory)
NEXTCLOUDDBTYPE=$(sudo -u www-data php $DPATH/occ config:system:get dbtype)
NEXTCLOUDDBHOST=$(sudo -u www-data php $DPATH/occ config:system:get dbhost)
NEXTCLOUDDB=$(sudo -u www-data php $DPATH/occ config:system:get dbname)
NEXTCLOUDDBUSER=$(sudo -u www-data php $DPATH/occ config:system:get dbuser)
NEXTCLOUDDBPASSWORD=$(sudo -u www-data php $DPATH/occ config:system:get dbpassword)
NEXTCLOUDDBTYPE=$(sudo -u www-data php $DPATH/occ config:system:get dbtype)
NEXTCLOUDAPPS=$(sudo -u www-data php $DPATH/occ app:list --enabled --output=json | jq -r '.enabled|keys[]' | xargs)
SDATE="nextcloud.sql"
apt update
if [ $NEXTCLOUDDBTYPE = "pgsql" ]; then
    apt-mark unhold pgsql*
    apt-mark unhold postgresql*
    apt-mark unhold postgresql-*
    else
    apt-mark unhold mariadb-*
    apt-mark unhold mysql-*
    apt-mark unhold galera-*
    fi
apt-mark unhold $WEBSERVER* $WEBSERVER-*
apt-mark unhold redis*
apt-mark unhold php-* php$PHPVERSION-*
apt-mark unhold elasticsearch*
apt install -y jq
apt upgrade -V
if [ $NEXTCLOUDDBTYPE = "pgsql" ]; then
    apt-mark hold pgsql*
    apt-mark hold postgresql*
    apt-mark hold postgresql-*
else
    apt-mark hold mariadb-*
    apt-mark hold mysql-*
    apt-mark hold galera-*
    fi
apt-mark hold $WEBSERVER* $WEBSERVER-*
apt-mark hold redis*
apt-mark hold php-* php$PHPVERSION-*
apt-mark hold elasticsearch*
apt autoremove
apt autoclean
# chown -R www-data:www-data $DPATH
# find $DPATH/ -type d -exec chmod 750 {} \;
# find $DPATH/ -type f -exec chmod 640 {} \;
if [ -d "$DPATH/apps/notify_push" ]; then
    sudo chmod ug+x $DPATH/apps/notify_push/bin/x86_64/notify_push
    fi 
echo ""
echo -n " » Soll eine DB- und Nextcloud-Dateisicherung erstellt werden [y|n]?"
read answer
if [ "$answer" != "${answer#[YyjJ]}" ];then
    echo ""
    echo -n " » Sollen die vorherigen Sicherungen gelöscht werden [y|n]?"
    read answer
    if [ "$answer" != "${answer#[YyjJ]}" ];then
    rm -Rf $SPATH-* $SNPATH-*
    fi
    if [ ! -d $SPATH-$NEXTCLOUDVERSION ]; then
        mkdir -p $SPATH-$NEXTCLOUDVERSION
    fi
    if  [ ! -d $SNPATH-$NEXTCLOUDVERSION ]; then
        mkdir -p $SNPATH-$NEXTCLOUDVERSION
    fi
    echo ""
    sudo -u www-data php $DPATH/occ maintenance:mode --on
    echo ""
    echo " » Die Datenbanksicherung wird gestartet..."
    if [ $NEXTCLOUDDBTYPE = "pgsql" ]; then
    	PGPASSWORD="$NEXTCLOUDDBPASSWORD" pg_dump $NEXTCLOUDDB -h $NEXTCLOUDDBHOST -U $NEXTCLOUDDBUSER -f $SPATH-$NEXTCLOUDVERSION/$SDATE
    else
	    mariadb-dump --single-transaction --routines -h $NEXTCLOUDDBHOST -u$NEXTCLOUDDBUSER -p$NEXTCLOUDDBPASSWORD -e $NEXTCLOUDDB > $SPATH-$NEXTCLOUDVERSION/$SDATE
    fi
    echo ""
    echo " » Die Datenbankgröße wird ermittelt..."
    echo -e "\033[32m » $(du -sh $SPATH-$NEXTCLOUDVERSION | awk '{ print $1 }')\033[0m"
    echo ""
    echo " » Das Nextcloudverzeichnis wird gesichert..."
    echo " » $(du -sh $DPATH | awk '{ print $1 }') werden erwartet..."
    rsync -a $DPATH/ $SNPATH-$NEXTCLOUDVERSION
    echo -e "\033[32m » $(du -sh $SNPATH-$NEXTCLOUDVERSION | awk '{ print $1 }')\033[0m wurden gesichert"
    echo ""
    sudo -u www-data php $DPATH/occ maintenance:mode --off
    echo ""
fi
echo ""
echo " » Der Webserver wird deaktiviert..."
systemctl stop $WEBSERVER.service
systemctl disable $WEBSERVER.service
# systemctl status $WEBSERVER.service
echo ""
echo -n " » Nextcloud Updates gewünscht [y|n]?"
read answer
if [ "$answer" != "${answer#[YyjJ]}" ] ;then
    echo ""
    sudo -u www-data php $DPATH/updater/updater.phar --no-backup
    sudo -u www-data php $DPATH/occ status
    sudo -u www-data php $DPATH/occ -V
    sudo -u www-data php $DPATH/occ db:add-missing-primary-keys
    sudo -u www-data php $DPATH/occ db:add-missing-indices
    sudo -u www-data php $DPATH/occ db:add-missing-columns
    sudo -u www-data php $DPATH/occ db:convert-filecache-bigint
    sudo -u www-data php $DPATH/occ maintenance:repair --include-expensive
    sudo -u www-data sed -i "s/output_buffering=.*/output_buffering=0/" $DPATH/.user.ini 
    echo ""
    echo " » Nextcloud Apps ggf. reaktivieren"
    sudo -u www-data php $DPATH/occ app:enable $NEXTCLOUDAPPS
    echo ""
    echo " » Liste zu aktualisierender Apps:"
    echo ""
    sudo -u www-data php $DPATH/occ app:update --showonly -v
    echo ""
    echo -n " » Möchten Sie die Nextcloud Apps aktualisieren [y|n]?"
    read answer
    if [ "$answer" != "${answer#[YyjJ]}" ] ;then
        sudo -u www-data php $DPATH/occ app:update --all -v
        sudo -u www-data php $DPATH/occ app:list | grep -i richdocuments &> /dev/null
        if [ $? -eq 0 ]; then
        sudo -u www-data php $DPATH/occ richdocuments:update-empty-templates
        fi
    else
        echo " » Nextcloud Apps wurden nicht aktualisiert."
        echo ""
    fi
else
    echo " » Nextcloud wurde nicht aktualisiert/überprüft."
    echo ""
fi
echo ""
echo " » Update acme.sh"
su - acmeuser -c ".acme.sh/acme.sh --upgrade --auto-upgrade"
sleep 2
echo ""
echo " » Webserver und Nextcloud Setupcheck gestartet..."
echo ""
systemctl enable --now $WEBSERVER.service
echo ""
sudo -u www-data php $DPATH/occ setupchecks
echo ""
echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo " » Dienste werden neu gestartet..."
echo ""
echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
dpkg -s elasticsearch &> /dev/null  
if [ $? -eq 0 ]; then
echo " » Elasticsearch wird zuerst neu gestartet"
systemctl daemon-reload && systemctl restart elasticsearch.service
else
echo " » Elasticsearch ist nicht installiert!"
fi
echo ""
if [ $NEXTCLOUDDBTYPE = "pgsql" ]; then
    systemctl restart postgresql.service redis-server.service php$PHPVERSION-fpm.service $WEBSERVER.service
else
    systemctl restart mariadb.service redis-server.service php$PHPVERSION-fpm.service $WEBSERVER.service
fi
if [ -e /var/run/reboot-required ]; then
        echo -e " »\e[1;31m ACHTUNG: ES IST EIN SERVERNEUSTART ERFORDERLICH.\033[0m"
        echo ""
        echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
else
        echo -e " »\033[32m KEIN Serverneustart notwendig.\033[0m"
        echo ""
        echo " ++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
fi
echo ""
rm -f /tmp/ncupdateskript
exit 0
# Based on work by Carsten Rieger (https://www.c-rieger.de)
# Adapted by yourdevice.ch