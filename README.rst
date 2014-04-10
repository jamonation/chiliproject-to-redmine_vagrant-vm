Chiliproject to Redmine Migration environment
=============================================

The purpose of this VM is to provide a mostly consistent environment in which to perform a Chiliproject to Redmine migration.

Background
----------

The Chiliproject fork of Redmine appears to be abandoned leaving most users with no way to move their installations back to Redmine.

There have been various sets of instructions floating around that help in performing this migration, but nothing consistent and stable enough to guarantee successful migrations. This tool by no means guarantees success, but it is tested and works more consistently than others.

Thankfully the work of Peer Allan (https://github.com/pallan) is shared with the community and it is used in this environment to perform the database schema migration. Credit where credit is due: Peer's original script is available here https://gist.github.com/pallan/6663018 and is used in this environment in very slightly modified form only.

Environment Details
-------------------

This environment provides:

#. Ruby 1.9.3
#. Requisite gems - mysql2, bundle, rake 10.1.1, and everything else that bundle installs
#. MySQL 5.5
#. Redmine 2.4.5

Usage
-----
Ok on to how to use this tool. A number of preparation steps are required before SSH'ing in and performing the migration.

0. This tool assumes you have Vagrant installed and working. If not visit http://www.vagrantup.com/ and follow along with the fine instructions there.

1. Clone this repository and ensure you are using ``master`` branch to build the VM.

2. Make a database dump of your MySQL based Chiliproject. Call it ``chiliproject.sql`` and place it in the top level of the checkout. You can also scp/rsync it into the VM once it is running. The intent is to have a file **in** the VM at ``/home/vagrant/migrate/chiliproject.sql``, which contains your complete Chiliproject database copy.

3. Run ``vagrant up --provision`` to download the base Ubuntu 12.04 64 bit image and to run the provision script to install all the goodies like Gem Git Ruby etc.

4. Once the provisioning completes with the message **Provisioning complete. Run 'vagrant ssh' to continue**, do that. Run ``vagrant ssh`` and you will be logged into the virtual machine and are ready to run the conversion.

5. ``cd migrate`` and load your database dump using ``bash tools/load_database.sh``. This script is the one that presumes the existence of ``/home/vagrant/migrate/chiliproject.sql``, which you already created in step #2. 

6. ``cd redmine`` and run the migration script: ``RAILS_ENV=production ruby ../tools/chiliproject_to_redmine.rb``

7. Profit! Your converted (hopefully) Redmine ready database resides in ``/home/vagrant/migrate/redmine.sql.gz``. The VM MySQL instance also contains the converted database named ``redmine``. 

8. Test your migration with Webrick:
  1. ``cd ~/migrate/redmine``
  2. ``rake generate_secret_token``
  3. ``ruby script/rails server webrick -e production``
  4. Browse to http://127.0.0.1:3000 to visit your migrated Redmine instance

Notes
-----

This tool doesn't handle anything with your uploaded files and isn't intended to be a production ready instance of Redmine. It could be with some work, but the intent is merely to do the migration so **do not** rely on this image for anything else.

If you want to SSH using the IP or rsync etc., install your ssh key or set a password for the user in the VM. Then do ``ssh 127.0.0.1 -p 2222`` to connect using the local port forward that is setup by the Vagrant VM.
