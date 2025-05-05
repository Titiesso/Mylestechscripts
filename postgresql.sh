#!/bin/bash

# This script will :
#	-Install PostgreSQL server 
#	-Initialize the database
#	-Enable and start the PostgreSQL service
#	-Set up basic security (firewall and local access)
#	-set up local access

# Update system packages

echo "Updating system packages..."
sudo su -c "dnf update -y"
# Check the module
sudo su -c "yum module list | grep postgres"
# Choose the postgreSQL version to install

POSTGRES_VERSION="13" # We can change it to 12, 14 etc. if needed

# Check if PostgreSQL is already installed

rpm -qa | grep -q "postgresql${POSTGRES_VERSION}-server" 

if [ $? -eq 0 ]; then
	echo "PostgreSQL ${POSTGRES_VERSION} is already installed."
	
else

sudo su -c "yum install @postgresql:${POSTGRES_VERSION} -y"	
	
fi	
	echo "Checking if service is running..."

# Check if service is running


if systemctl is-active --quiet postgresql-${POSTGRES_VERSION}; then
	echo "PostgreSQL service is running."
else
	echo "PostgreSQL service is not running."


# Initialize the database

echo "Initializing PostgreSQL database..."

/usr/psql-${POSTGRES_VERSION}/bin/postgresql-${POSTGRES_VERSION}-setup initdb

# Set a password for Postgres User

passwd postgres

sleep 1

#Become the postgres user

sudo -i -u postgres
# Go into database cli

psql

sleep 1

#Create a user in the database

CREATE USER titi WITH PASSWORD 'hello123'

#Check if the user has been created

\du

#Create a database

CREATE DATABASE docdb OWNER titi

\l

#Grant all privileges

GRANT ALL PRIVILEGES ON DATABASE docdb TO titi

\q

# Start and stop PostgreSQL to edit the config files

sudo su -c "systemctl enable postgresql.service"

sleep 2

sudo su -c "sytemctl start postgresql.service"

sleep 2

sudo su -c "systemctl status postgresql.service"

sleep 2

sudo su -c "systemctl stop postgresql.service"

#Edit config file

PG_HBA="/var/lib/pgsql/${POSTGRES_VERSION}/data/pg_hba.conf"

PG_CONF="/var/lib/pgsql/${POSTGRES_VERSION}/data/postgres.conf"

#Take a backup of pg_hba.conf and postgres.conf

cp "$PG_HBA" "PG_HBA-BK"

sleep 1

cp "PG_CONF" "PG_CONF-BK"

#Configure the authentication and listening address

sudo su - postgres

cd /var/lib/pgsql/${POSTGRES_VERSION}/data/postgresql.conf

echo "listen_addresses = '10.10.8.169'" >> /var/lib/pgsql/${POSTGRES_VERSION}/data/postgresql.conf

sleep 2

echo


# Set up basic security ( Configuring firewall)

if systemctl is-active --quiet firewall; then
	echo "Configuring firewall for PostgreSQL..."

sudo su -c "firewall-cmd --zone=public --add-port=5432/tcp --permanent"
sudo su -c "firewall-cmd --add-service=postgresql --permanent"
sudo su -c "firewall-cmd --reload"

fi

# Set up the local access

PG_HBA="/var/lib/pgsql/${POSTGRES_VERSION}/data/pg_hba.conf"
PG_CONF=
echo "Backing up pg_hba.conf..."

cp "$PG_CONFIG" "${PG_CONFIGBK"







