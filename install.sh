#!/bin/bash

STARTDATE=$(date +"%Y-%m-%dT%H%M")
ERROR_COUNT=0
error() {
  ((ERROR_COUNT++))
  echo "[ERROR] $@"
}

{
set -x

dist=$1
release=$2
collections="base ${@:3}"

if [[ $collections =~ desktop ]]; then
  # Disable logins during installation
  echo "Installation in progress, please wait" > /etc/nologin
fi

if [[ $dist == redhat && $release == centos* ]]; then
  # Stream 8 now EOL
  sed -i -e "s|mirrorlist=|#mirrorlist=|g" -e "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-*
  # Add the EPEL repository
  yum install -y epel-release || error
fi

# Use the WANdisco subversion packages
if [[ $dist == redhat && $release == centos7 ]]; then
  cat  > /etc/yum.repos.d/WANdisco-svn.repo <<EOF
[WANdisco-svn]
name=WANdisco SVN Repo
enabled=1
baseurl=http://opensource.wandisco.com/centos/7/svn-1.10/RPMS/\$basearch/
gpgcheck=1
gpgkey=http://opensource.wandisco.com/RPM-GPG-KEY-WANdisco
EOF
fi

# Get the latest package info and install any updates
if [[ $dist == ubuntu ]]; then
  export DEBIAN_FRONTEND=noninteractive  # Disable user interaction
  apt-get -yq update || error
  apt-get -yq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade || error
elif [[ $dist == redhat ]]; then
  yum update -y || error
fi

# Use dos2unix in case any files have Windows EOL characters
if [[ $dist == ubuntu ]]; then
  apt-get -yq install dos2unix || error
elif [[ $dist == redhat ]]; then
  yum install -y dos2unix || error
fi

for collection in $collections; do
  echo $(date +"%Y-%m-%dT%H%M") - Installing $collection collection ...
  dos2unix -n /vagrant/install-$collection.sh /tmp/install-$collection.sh
  . /tmp/install-$collection.sh
  rm /tmp/install-$collection.sh
done

# Remove python-gi on Ubuntu since it breaks rosie go (not needed unless using GNOME keyring)
if [[ $dist == ubuntu ]]; then
  apt-get remove -q -y --auto-remove --purge python-gi || error
fi

set +x
echo Finished provisioning at $(date +"%Y-%m-%dT%H%M") \(started at $STARTDATE\)
echo

if [[ $ERROR_COUNT != "0" ]]; then
  echo "[ERROR] $ERROR_COUNT errors occurred during installation"
else
  echo "[INFO] No errors detected"
fi

rm -f /etc/nologin
if [[ $collections =~ desktop && ! $collections =~ skip-shutdown ]]; then
  echo Shutting down the system.
  echo Please run vagrant up to restart it.
  sudo shutdown -h now
else
  echo Please run vagrant ssh to connect.
fi

} |& tee -a /var/log/install.log
