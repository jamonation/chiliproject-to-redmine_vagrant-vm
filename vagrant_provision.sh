#!/bin/bash
# shell script to provision VM, instead of puppet
set -e
set -x

# avoid pesky /dev/tty errors
clean=yes
export DEBIAN_FRONTEND=noninteractive

apt-get update

# generate some mysql passwords
MYSQL_PASS_ROOT=$(cat /dev/urandom| tr -dc 'A-Za-z0-9'| fold -w 16| head -n 1)
MYSQL_PASS_VAGRANT=$(cat /dev/urandom| tr -dc 'A-Za-z0-9'| fold -w 16| head -n 1)

echo "Mysql install"
apt-get -y install mysql-server-5.5

# make databases as root
printf "CREATE DATABASE IF NOT EXISTS redmine; CREATE DATABASE IF NOT EXISTS chiliproject;" |mysql
# add permissions for vagrant user
printf "GRANT ALL ON redmine.* TO vagrant@localhost IDENTIFIED BY \"$MYSQL_PASS_VAGRANT\";" |mysql
printf "GRANT ALL ON chiliproject.* TO vagrant@localhost;" |mysql

# set root mysql password
mysqladmin -u root password $MYSQL_PASS_ROOT
printf "[client]\nuser = root\npassword = $MYSQL_PASS_ROOT\n" > /root/.my.cnf
chmod 400 /root/.my.cnf

# let vagrant user connect to mysql with its permissions
printf "[client]\nuser = vagrant\npassword = $MYSQL_PASS_VAGRANT\n" > /home/vagrant/.my.cnf
chown vagrant /home/vagrant/.my.cnf
chmod 600 /home/vagrant/.my.cnf

# install ruby & dev libraries:
apt-get -y install libmysqlclient-dev ruby1.9.3 libxml2-dev libxslt1-dev libmagickwand-dev git

# gem stuff
gem install rdoc
gem install bundle mysql2 inifile
gem install rake -v '10.1.1' 

# clone redmine repository
cd /home/vagrant/migrate
git remote rm origin
git remote add origin https://github.com/jamonation/chiliproject-to-redmine_vagrant-vm.git
git pull origin master
git submodule update --init --recursive
cd /home/vagrant/migrate/redmine
git checkout master
# make sure to use 2.4.5 from upstream
git branch -D 2.4.5; git checkout tags/2.4.5 -b 2.4.5
bundle install

cat <<EOF > /home/vagrant/migrate/redmine/config/database.yml
production:
  adapter: mysql2
  database: redmine
  host: localhost
  username: vagrant
  password: "$MYSQL_PASS_VAGRANT"
  encoding: utf8
EOF

printf "Provisioning complete. Run 'vagrant ssh' to continue.\n"
