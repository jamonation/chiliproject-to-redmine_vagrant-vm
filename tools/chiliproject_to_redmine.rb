# encoding: UTF-8

# Forked from https://gist.github.com/pallan/6663018 - amazing work
# All credit and copyright for this is Peer Allan's

# Chiliproject to Redmine converter
# =================================
#
# This script takes an existing Chiliproject database and
# converts it to be compatible with Redmine (>= v2.3). The
# database is converted in such a way that it can be run multiple
# times against a production Chiliproject install without
# interfering with it's operation. This is done by duplicating
# the entire Chiliproject database into a new database for
# Redmine. All conversions, transformation and adjustments are
# then performed on the new database without touching the
# chiliproject production database in any way.
#
# = Requirements
# * Ruby >= 1.9.3 (this was developed and run using Ruby 2.0)
# * database user has permissions to create/drop databases
# * database user has access to both chiliproject and redmine database
# * Redmine has been setup and fully configured for use
#
# = Notes
#
# == History conversion
# If you previously converted from Redmine to Chiliproject you
# likely have existing issue journal history in the
# `journal_details` table. If so, enter the greatest journal_id
# from this table in the 'journal_start_id' config option. This
# will cause the script to only update history created AFTER the
# transition to Chiliproject. If you did not previously convert,
# then you can leave the value of this option at '0' to convert
# everything.
#
# == Serialization
# If you run this under Ruby 1.9 you may experience issues related
# to the deserialization of the "changes" column from Chiliproject.
# Ruby 2.0 switched to Psych from Syck for YAML serialization. In
# Ruby 1.9 you could configure which YAML encoder to use. In 2.0 you
# cannot. Therefore the Syck gem is included to prevent
# deserialization errors.
#
# == Disclaimer
# This software is provided as-is with no warranty whatsoever. Use at
# your own risk! The developer is not responsible for any damages/
# corruption which may occur to your system.
#
require 'rubygems'
require 'mysql2'
require 'syck'

# configuration
redmine_db        = 'redmine'
journal_start_id  = 0
chili_db          = 'chiliproject'
config =  {
            encoding: 'utf8',
            username: '',
            password: '',
            host: ''
          }

# initialize connection to the server
client = Mysql2::Client.new(config)

# Creates a new redmine database. Any existing
# redmine DB will be dropped and recreated.
puts "== Setup the Redmine database"
puts "    -> Create"
client.query("DROP DATABASE IF EXISTS `#{redmine_db}`")
client.query("CREATE DATABASE `#{redmine_db}`")
client.query("alter database #{redmine_db} DEFAULT CHARACTER SET utf8 collate utf8_general_ci")
client.query("USE `#{chili_db}`")

# Get the full Table list from the chiliproject DB and
# copy each table to the redmine database, making sure
# each table is set to UTF-8 encoding. Follow this by
# copying all the data over
client.query('SHOW TABLES', as: :array).each do |tbl|
  puts "    -> Copying table #{tbl.first}"
  tbl_create = client.query("SHOW CREATE TABLE `#{chili_db}`.`#{tbl.first}`", as: :array).first[1]
  tbl_create.gsub!('CREATE TABLE ', "CREATE TABLE `#{redmine_db}`.")
  client.query(tbl_create)
  client.query("alter table `#{tbl.first}` CONVERT TO CHARACTER SET utf8")
  client.query("INSERT INTO `#{redmine_db}`.`#{tbl.first}` SELECT * FROM `#{chili_db}`.`#{tbl.first}`")
end

# switch to the redmine database for the remainder of
# the script
client.query("USE `#{redmine_db}`")
puts "== Pre-migrations alter queries"
puts "    -> Updating journals created_on"
query = <<-SQL
ALTER TABLE journals
  CHANGE COLUMN created_at created_on DATETIME,
  CHANGE COLUMN journaled_id journalized_id INTEGER(11),
  CHANGE COLUMN activity_type journalized_type VARCHAR(255)
SQL
client.query(query)

# Need to ensure the new database is up to date with the
# Redmine database migrations.
puts "== Redmine migrations"
`rake db:migrate`

# Modify the imported Chiliproject tables to be Redmine
# compatible
puts "== Post-migrations alter queries"
puts "    -> Updating wiki_contents"
query = <<-SQL
ALTER TABLE wiki_contents
  ADD comments VARCHAR(250) NULL,
  CHANGE COLUMN lock_version version INTEGER(11);
SQL
client.query(query)

puts "    -> Updating journals.journalized_type"
query = <<-SQL
UPDATE journals SET journalized_type='Issue'
WHERE  journalized_type='issues';
SQL
client.query(query)

# Prior to converting history preserve the chili data in a new
# column
puts "    -> Updating journal columns"
query = <<-SQL
ALTER TABLE journals
CHANGE COLUMN changes changes_chili TEXT NULL,
  DROP COLUMN type
SQL
client.query(query)

# Chili stores changes as a serialized column, Redmine has a
# row entry for each change in a separate table. This section of 
# code converts them. If you previously converted from Redmine 
# to ChiliProject you will already have data in the `journal_details` 
# table. Use the journal_start_id to only translate data created 
# after the conversion.
#
# How this works
# 1) Read the chiliproject changes column
# 2) Unserialize the column from YAML using Syck
# 3) Iterate through the keys and build update SQL values strings
# 4) Every 5,000 entries do an insert to the `journal_details` table
#
puts "== Converting journal history"
data = []
client.query("USE `#{redmine_db}`")
results = client.query("SELECT id, changes_chili FROM journals WHERE id > #{journal_start_id} AND version > 1")
results.each do |j|
  next if j['changes_chili'].nil?
  begin
    Syck.load(j['changes_chili']).each do |key, v|
      case key
      when /\Aattachments/
        property = 'attachment'
        prop_key = key.gsub(/[^0-9]/,'')
      when /\Acustom_values/
        property = 'cf'
        prop_key = key.gsub(/[^0-9]/,'')
      else
        property = 'attr'
        prop_key = key
      end
      old_value = v[0].is_a?(String) ? client.escape(v[0]) : v[0]
      new_value = v[1].is_a?(String) ? client.escape(v[1]) : v[1]
      data << "(#{j['id']},'#{property}','#{prop_key}','#{old_value}','#{new_value}')".force_encoding('UTF-8')
    end
    if data.size >= 5_000
      puts "    -> Inserting journal details batch"
      client.query("INSERT INTO `journal_details` (`journal_id`, `property`, `prop_key`, `old_value`, `value`) VALUES #{data.join(',')}")
      data = []
    end
  rescue => e
    puts "   *** Could not parse changes for Journal #{j['id']} (#{e.class}: #{e.message} #{e.backtrace.first})"
  end
end
puts "    -> Inserting journal details batch"
client.query("INSERT INTO `journal_details` (`journal_id`, `property`, `prop_key`, `old_value`, `value`) VALUES #{data.join(',')}")

# After history has been converted, clean up the history and
# drop the now unecessary columns
puts "== Journal history data cleanup"
puts "    -> Clearing empty rows"
query = <<-SQL
delete from journals where (notes is null or notes = '' )
and changes_chili is not null and not exists (
select 1 from journal_details x where x.journal_id=journals.id
)
SQL
client.query(query)
puts "    -> Dropping unnecessary columns"
query = <<-SQL
ALTER TABLE journals
  DROP COLUMN changes_chili,
  DROP COLUMN version
SQL
client.query(query)

# Dump the converted database since that's the whole point of this
puts "\n== Dumping converted database to /home/vagrant/migrate/redmine.sql.gz"
`mysqldump redmine| gzip > /home/vagrant/migrate/redmine.sql.gz`

puts "\n== Done"

