#!/bin/bash
# shell script to provision VM, instead of puppet
set -e
set -x

# avoid pesky /dev/tty errors
clean=yes

# generate some mysql passwords
MYSQL_PASS_ROOT=$(cat /dev/urandom| tr -dc 'A-Za-z0-9'| fold -w 16| head -n 1)
MYSQL_PASS_VAGRANT=$(cat /dev/urandom| tr -dc 'A-Za-z0-9'| fold -w 16| head -n 1)

apt-get update

sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_PASS_ROOT"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_PASS_ROOT"

echo "Mysql install"
apt-get -y install mysql-server-5.5

# set root mysql password
printf "[client]\nuser = root\npassword = $MYSQL_PASS_ROOT\n" > /root/.my.cnf
# make databases as root
printf "CREATE DATABASE redmine; CREATE DATABASE chiliproject;" |mysql
# add permissions for vagrant user
printf "GRANT ALL ON redmine.* TO vagrant@localhost IDENTIFIED BY \"$MYSQL_PASS_VAGRANT\";" |mysql
printf "GRANT ALL ON chiliproject.* TO vagrant@localhost;" |mysql

# let vagrant user connect to mysql with its permissions
printf "[client]\nuser = root\npassword = $MYSQL_PASS_VAGRANT\n" > /home/vagrant/.my.cnf

# install ruby & dev libraries:
apt-get -y install libmysqlclient-dev ruby1.9.3 libxml2-dev libxslt1-dev libmagickwand-dev git

# gem stuff
gem install database_cleaner
gem install mysql2
gem install rake -v '10.1.1'

# clone redmine repository
cd /home/vagrant/migrate
git pull
git submodule update --init --recursive
cd /home/vagrant/redmine
git checkout -b 2.4.5 2.4.5
bundle install
