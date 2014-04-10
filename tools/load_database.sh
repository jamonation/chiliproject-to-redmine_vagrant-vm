#!/bin/bash

DB_DUMP=/home/vagrant/migrate/chiliproject.sql

if [[ -e $DB_DUMP ]]; then
    mysql chiliproject < $DB_DUMP
else
    printf "No database dump named /home/vagrant/migrate/chiliproject.sql exists.\n\n"
    printf "Ensure you have copied your Chiliproject MySQL dump to that file.\n"
    printf "Either scp/rsync it into the Vagrant VM, or you can place it in the\n"
    printf "top level of the git clone outside of the VM and it will be shared\n"
    printf "into the VM that way.\n"
fi
