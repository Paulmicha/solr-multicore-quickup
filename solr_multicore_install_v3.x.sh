#!/bin/bash
# -*- coding: UTF8 -*-

##
#   Drupal-friendly, multi-core Apache Solr & Tika installation script
#
#   Prerequisites : a working drupal install with module apachesolr downloaded
#   Tested 2012-10-03 on Linux Debian 6 "Squeeze" with openjdk-6-jdk, apache-solr-3.6.1, and tika-app-1.2.jar
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

#       Variables (edit as needed)
#       @todo implement arguments - as in /usr/share/doc/bash-doc/examples/functions/getoptx.bash of package bash-doc
DRUPAL_SITE_PATH="/var/www/my-website"
TIKA_JAR_PATH="/usr/local/share"
APACHESOLR_DRUPAL_MODULE_PATH="/var/www/my-website/sites/all/modules/contrib/apachesolr"
DEFAULT_CORE_NAME="my-website"


#-----------------------------------------
#       Java

apt-get install openjdk-6-jdk -y


#-----------------------------------------
#       Tika

#       Get latest version + closest mirror
#       @see http://www.apache.org/dyn/closer.cgi/tika
wget http://apache.mirrors.multidist.eu/tika/tika-app-1.2.jar
mv tika-app-1.2.jar $TIKA_JAR_PATH/


#-----------------------------------------
#       Solr

#       Get latest version
#       @see http://ftp.download-by.net/apache/lucene/solr/
wget http://ftp.download-by.net/apache/lucene/solr/3.6.1/apache-solr-3.6.1.tgz
cp apache-solr-3.6.1.tgz /opt
cd /opt
tar -zxvf apache-solr-3.6.1.tgz
rm apache-solr-3.6.1.tgz
mv /opt/apache-solr-3.6.1/example /opt/apache-solr-3.6.1/drupal

#       Schema definitions and configuration found in the apache solr drupal module
cd /opt/apache-solr-3.6.1/drupal/solr/conf
mv schema.xml schema.xml.bak
mv solrconfig.xml solrconfig.xml.bak
cp $APACHESOLR_DRUPAL_MODULE_PATH/solr-conf/schema.xml /opt/apache-solr-3.6.1/drupal/solr/conf
cp $APACHESOLR_DRUPAL_MODULE_PATH/solr-conf/solrconfig.xml /opt/apache-solr-3.6.1/drupal/solr/conf

#       Configure Solr to run multicore
cd /opt/apache-solr-3.6.1/drupal
cp multicore/solr.xml solr/

#       Create a folder for each index
mkdir solr/$DEFAULT_CORE_NAME
cp -rf solr/conf/ solr/$DEFAULT_CORE_NAME

#       Edit solr.xml accordingly
mv /opt/apache-solr-3.6.1/drupal/solr/solr.xml /opt/apache-solr-3.6.1/drupal/solr/solr.xml.bak
echo -n "<?xml version='1.0' encoding='UTF-8' ?>
<solr persistent='false'>
  <cores adminPath='/admin/cores'>
    <core name=\"$DEFAULT_CORE_NAME\" instanceDir=\"$DEFAULT_CORE_NAME\" />
  </cores>
</solr>" > /opt/apache-solr-3.6.1/drupal/solr/solr.xml


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
 
SOLR_DIR="/opt/apache-solr-3.6.1/drupal/"
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
apt-get install sysv-rc-conf -y
sysv-rc-conf --level 2345 apachesolr on


#-----------------------------------------
#       Drupal-specific

cd $DRUPAL_SITE_PATH
drush dl apachesolr -n
drush en apachesolr -y
drush solr-set-env-url "http://localhost:8983/solr/$DEFAULT_CORE_NAME"

#       Building initial index
drush solr-mark-all
drush solr-index


