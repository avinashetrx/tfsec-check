#!/bin/bash

set -exuo pipefail

export TOMCAT_VERSION=9.0.73
export DEBIAN_FRONTEND=noninteractive

# Let the instance finish booting

sleep 5

# Based on the JasperReports Server CP Install Guide for 7.8

# Setup

apt-get update && apt-get upgrade -y
apt-get install wget awscli lsb-release gnupg unzip -y

# Otherwise systemd-resolve blocks .local domains
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

# Block non-root users from accessing the instance metadata service
iptables -A OUTPUT -m owner ! --uid-owner root -d 169.254.169.254 -j DROP
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
apt-get install iptables-persistent -y

# Install Java

apt-get install openjdk-11-jdk -y

# Install Tomcat

rm -rf /opt/tomcat/base
rm -rf /opt/tomcat/apache-tomcat-$${TOMCAT_VERSION}
id -u tomcat &>/dev/null || useradd -m -U -d /opt/tomcat tomcat
sudo -u tomcat mkdir -p /opt/tomcat/base
wget -q "https://archive.apache.org/dist/tomcat/tomcat-9/v$${TOMCAT_VERSION}/bin/apache-tomcat-$${TOMCAT_VERSION}.tar.gz" -P /tmp
sudo -u tomcat tar -xf /tmp/apache-tomcat-$${TOMCAT_VERSION}.tar.gz -C /opt/tomcat/
rm -f /tmp/apache-tomcat-$${TOMCAT_VERSION}.tar.gz
rm -f /opt/tomcat/latest
sudo -u tomcat ln -s /opt/tomcat/apache-tomcat-$${TOMCAT_VERSION} /opt/tomcat/latest

echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" > /etc/profile.d/java-tomcat-vars.sh
echo "export CATALINA_BASE=/opt/tomcat/base" >> /etc/profile.d/java-tomcat-vars.sh
echo "export CATALINA_HOME=/opt/tomcat/latest" >> /etc/profile.d/java-tomcat-vars.sh
source /etc/profile.d/java-tomcat-vars.sh

cp -r $${CATALINA_HOME}/conf/ $${CATALINA_BASE}/conf/
mkdir $${CATALINA_BASE}/webapps/
mkdir $${CATALINA_BASE}/logs
mkdir $${CATALINA_BASE}/temp
mkdir $${CATALINA_BASE}/work
mkdir $${CATALINA_BASE}/lib

# Setup a simple ROOT app that redirects to /jasperserver
mkdir $${CATALINA_BASE}/webapps/ROOT
mkdir $${CATALINA_BASE}/webapps/ROOT/WEB-INF
aws s3 cp --region ${AWS_REGION} s3://${JASPERSOFT_CONFIG_S3_BUCKET}/root_index.jsp $${CATALINA_BASE}/webapps/ROOT/index.jsp
aws s3 cp --region ${AWS_REGION} s3://${JASPERSOFT_CONFIG_S3_BUCKET}/root_web.xml $${CATALINA_BASE}/webapps/ROOT/WEB-INF/web.xml
chown -R tomcat:tomcat $${CATALINA_BASE}

aws s3 cp --region ${AWS_REGION} s3://${JASPERSOFT_CONFIG_S3_BUCKET}/tomcat.service /etc/systemd/system/tomcat.service
systemctl daemon-reload
systemctl enable tomcat

# Download JasperSoft files

aws s3 cp --region ${AWS_REGION} s3://${JASPERSOFT_INSTALL_S3_BUCKET}/js-7.8.1_hotfixed_2022-04-15.zip /tmp
aws s3 cp --region ${AWS_REGION} s3://${JASPERSOFT_CONFIG_S3_BUCKET}/default_master.properties /tmp

echo "Attempting to download keystore, will not exist on initial setup"
set +e
aws s3 cp --region ${AWS_REGION} s3://${JASPERSOFT_CONFIG_S3_BUCKET}/.jrsks /opt/tomcat/.jrsks
aws s3 cp --region ${AWS_REGION} s3://${JASPERSOFT_CONFIG_S3_BUCKET}/.jrsksp /opt/tomcat/.jrsksp
chown tomcat:tomcat /opt/tomcat/.jrsks /opt/tomcat/.jrsksp
chmod 600 /opt/tomcat/.jrsks /opt/tomcat/.jrsksp
set -e

# We may also need to install Chrome, I haven't done this
# > You need to install and configure Chrome/Chromium to export the reports to PDF and other output formats.

# Set up install folder
rm -rf /opt/tomcat/jaspersoft_install
sudo -u tomcat unzip -q /tmp/js-7.8.1_hotfixed_2022-04-15.zip -d /tmp/jaspersoft_install
sudo -u tomcat cp -r /tmp/jaspersoft_install /opt/tomcat/jaspersoft_install
cd /opt/tomcat/jaspersoft_install/buildomatic
set +x
DATABASE_PASSWORD=`aws secretsmanager get-secret-value --region ${AWS_REGION} --secret-id ${DATABASE_PASSWORD_SECRET_ID} --query SecretString --output text`
sed -i "s/RDS_DATABASE_PASSWORD/$${DATABASE_PASSWORD}/" /tmp/default_master.properties
set -x
cp /tmp/default_master.properties ./default_master.properties
chown tomcat:tomcat ./default_master.properties
rm /tmp/default_master.properties

# Run install
if [ -f /opt/tomcat/.jrsks ]; then
    # Keystore already exists, assume we're recreating the instance with an existing database
    su tomcat -c "./js-ant validate-database"
    su tomcat -c "./js-ant deploy-webapp-ce"
else
    # Installing from scratch, creating an empty database
    su tomcat -c "./js-install-ce.sh minimal"
    aws s3 cp --region ${AWS_REGION} /opt/tomcat/.jrsks s3://${JASPERSOFT_CONFIG_S3_BUCKET}/.jrsks
    aws s3 cp --region ${AWS_REGION} /opt/tomcat/.jrsksp s3://${JASPERSOFT_CONFIG_S3_BUCKET}/.jrsksp
fi

# LDAP setup
aws s3 cp --region ${AWS_REGION} s3://${JASPERSOFT_CONFIG_S3_BUCKET}/applicationContext-externalAuth-LDAP.xml $${CATALINA_BASE}/webapps/jasperserver/WEB-INF/applicationContext-externalAuth-LDAP.xml
set +x
LDAP_BIND_PASSWORD=`aws secretsmanager get-secret-value --region ${AWS_REGION} --secret-id ${LDAP_BIND_PASSWORD_SECRET_ID} --query SecretString --output text`
sed -i "s/JASPERSOFT_BIND_USER_PASSWORD/$${LDAP_BIND_PASSWORD}/" $${CATALINA_BASE}/webapps/jasperserver/WEB-INF/applicationContext-externalAuth-LDAP.xml
set -x
chown tomcat:tomcat $${CATALINA_BASE}/webapps/jasperserver/WEB-INF/applicationContext-externalAuth-LDAP.xml

# Fix for invalid CSRF header name, ALB will drop headers with underscores in
sed -i 's/^org.owasp.csrfguard.TokenName=OWASP_CSRFTOKEN/org.owasp.csrfguard.TokenName=OWASPCSRFTOKEN/' $${CATALINA_BASE}/webapps/jasperserver/WEB-INF/csrf/jrs.csrfguard.properties

sudo -u tomcat cp /opt/tomcat/jaspersoft_install/buildomatic/conf_source/db/postgresql/jdbc/postgresql-42.5.0.jar $${CATALINA_BASE}/lib/

systemctl start tomcat

echo "Done"
