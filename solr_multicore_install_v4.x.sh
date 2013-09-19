#!/bin/bash
# -*- coding: UTF8 -*-

##
#   Drupal-friendly, multi-core Apache Solr & Tika installation script
#
#   Prerequisites : a working drupal install with module apachesolr downloaded
#
#   NB : for a tomcat-based multi-core installation,
#   @see http://geroldm.com/2012/08/drupal-and-apachesolrtomcat-multi-core-setup-in-debianubuntu/
#   Also note : for geospatial search,
#   @see http://ericlondon.com/posts/250-geospatial-apache-solr-searching-in-drupal-7-using-the-search-api-module-ubuntu-version-part-2
#   
#   This method by Jesper Kristensen does not require tomcat
#   @see http://linuxdev.dk/articles/apache-solr-multicore-drupal-7
#   @author Jesper Kristensen - http://drupal.org/user/697210
#   
#   Tested @ 2013/09/19 15:43:06 on Debian 6 "Squeeze", Drupal 7.23, apachesolr-7.x-1.4
#   

#       Variables (edit as needed)
#       @todo implement arguments - as in /usr/share/doc/bash-doc/examples/functions/getoptx.bash of package bash-doc
DRUPAL_SITE_PATH="/var/www/my-website"
TIKA_JAR_PATH="/usr/local/share"
APACHESOLR_DRUPAL_MODULE_SOLR_CONF_PATH="/var/www/my-website/sites/all/modules/contrib/apachesolr/solr-conf/solr-4.x"
DEFAULT_CORE_NAME="my-website"


#-----------------------------------------
#       Java

aptitude install openjdk-6-jdk -y


#-----------------------------------------
#       Tika

#       Get latest version + closest mirror
#       @see http://www.apache.org/dyn/closer.cgi/tika
cd ~
wget http://mir2.ovh.net/ftp.apache.org/dist/tika/tika-app-1.4.jar
mv tika-app-1.4.jar $TIKA_JAR_PATH/
chmod +x $TIKA_JAR_PATH/tika-app-1.4.jar


#-----------------------------------------
#       Solr

#       Get latest version
#       @see http://www.apache.org/dyn/closer.cgi/lucene/solr/4.4.0
cd ~
wget http://mir2.ovh.net/ftp.apache.org/dist/lucene/solr/4.4.0/solr-4.4.0.tgz
cp solr-4.4.0.tgz /opt
cd /opt
tar -zxvf solr-4.4.0.tgz
rm solr-4.4.0.tgz
mv /opt/solr-4.4.0/example /opt/solr-4.4.0/drupal

#       Schema definitions and configuration found in the apache solr drupal module
cd /opt/solr-4.4.0/drupal/solr/collection1/conf
mv protwords.txt protwords.txt.bak
mv schema.xml schema.xml.bak
mv solrconfig.xml solrconfig.xml.bak
cp $APACHESOLR_DRUPAL_MODULE_SOLR_CONF_PATH/protwords.txt /opt/solr-4.4.0/drupal/solr/collection1/conf
cp $APACHESOLR_DRUPAL_MODULE_SOLR_CONF_PATH/schema.xml /opt/solr-4.4.0/drupal/solr/collection1/conf
cp $APACHESOLR_DRUPAL_MODULE_SOLR_CONF_PATH/solrconfig.xml /opt/solr-4.4.0/drupal/solr/collection1/conf
cp $APACHESOLR_DRUPAL_MODULE_SOLR_CONF_PATH/solrconfig_extra.xml /opt/solr-4.4.0/drupal/solr/collection1/conf
cp $APACHESOLR_DRUPAL_MODULE_SOLR_CONF_PATH/schema_extra_types.xml /opt/solr-4.4.0/drupal/solr/collection1/conf
cp $APACHESOLR_DRUPAL_MODULE_SOLR_CONF_PATH/schema_extra_fields.xml /opt/solr-4.4.0/drupal/solr/collection1/conf

#       Configure Solr to run multicore
cd /opt/solr-4.4.0/drupal
cp multicore/solr.xml solr/

#       Create a folder for each index
mkdir solr/$DEFAULT_CORE_NAME
cp -rf solr/collection1/conf/ solr/$DEFAULT_CORE_NAME

#       Edit solr.xml accordingly
mv /opt/solr-4.4.0/drupal/solr/solr.xml /opt/solr-4.4.0/drupal/solr/solr.xml.bak
echo -n "<?xml version='1.0' encoding='UTF-8' ?>
<solr persistent='false'>
  <cores adminPath='/admin/cores' host='${host:}' hostPort='${jetty.port:8983}' hostContext='${hostContext:solr}'>
    <core name=\"$DEFAULT_CORE_NAME\" instanceDir=\"$DEFAULT_CORE_NAME\" />
  </cores>
</solr>" > /opt/solr-4.4.0/drupal/solr/solr.xml


#-----------------------------------------
#       Automatically start Solr
#       (run-script)

echo -n '#!/bin/sh
### BEGIN INIT INFO
# Provides:            apachesolr
# Required-Start:    $local_fs $remote_fs $network $syslog $named
# Required-Stop:    $local_fs $remote_fs $network $syslog $named
# Default-Start:      2 3 4 5
# Default-Stop:      0 1 6
# X-Interactive:     true
# Short-Description: Start/stop apache sole search framework
### END INIT INFO
 
SOLR_DIR="/opt/solr-4.4.0/drupal/"
JAVA_OPTIONS="-Xmx1024m -DSTOP.PORT=8079 -DSTOP.KEY=stopkey -jar start.jar"
LOG_FILE="/var/log/solr.log"
JAVA="/usr/bin/java"
 
case $1 in
    start)
        echo "Starting Solr"
        cd $SOLR_DIR
        $JAVA $JAVA_OPTIONS 2> $LOG_FILE &
        ;;
    stop)
        echo "Stopping Solr"
        cd $SOLR_DIR
        $JAVA $JAVA_OPTIONS --stop
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}" >&2
        exit 1
        ;;
esac' > /etc/init.d/apachesolr
chmod 755 /etc/init.d/apachesolr
/etc/init.d/apachesolr start

#       Need "sysv-rc-conf" to edit run-levels
aptitude install sysv-rc-conf -y
sysv-rc-conf --level 2345 apachesolr on


#-----------------------------------------
#       Drupal-specific

cd $DRUPAL_SITE_PATH
drush en apachesolr -y
drush solr-set-env-url "http://localhost:8983/solr/$DEFAULT_CORE_NAME"

#       Building initial index
#drush solr-mark-all
#drush solr-index


