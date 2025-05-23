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

source variablespostgres

POSTGRES_VERSION=$version

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

echo "postgres:$POSTGRES_PASSWORD" | sudo chpasswd

sleep 1

#Become the postgres user

sudo -i -u postgres
# Go into database cli

psql

sleep 1

#Create a user in the database

CREATE USER $DATABASE_USER WITH PASSWORD $DBUSER_PASSWORD

#Check if the user has been created

\du

#Create a database

CREATE DATABASE $DATABASE_NAME OWNER $DATABASE_USER

\l

#Grant all privileges

GRANT ALL PRIVILEGES ON DATABASE $DATABASE_NAME TO $DATABASE_USER

\q

# Start and stop PostgreSQL to edit the config files

sudo su -c "systemctl enable postgresql.service"

sleep 2

sudo su -c "sytemctl start postgresql.service"

sleep 2

sudo su -c "systemctl status postgresql.service"

sleep 2

sudo su -c "systemctl stop postgresql.service"

#Take a backup and edit the config file 


#Take a backup of pg_hba.conf and postgres.conf

cp $PG_HBA $PG_HBA-BK

sleep 1

cp $PG_CONF $PG_CONF-BK

#Configure the authentication and listening address

sudo su - postgres

cd $DATABASE_HOME/${POSTGRES_VERSION}/data/postgresql.conf

echo "$IP_address" >> $DATABASE_HOME/${POSTGRES_VERSION}/data/postgresql.conf

sleep 2

echo


# Set up basic security ( Configuring firewall)

if systemctl is-active --quiet firewall; then
	echo "Configuring firewall for PostgreSQL..."

sudo su -c "firewall-cmd --zone=public --add-port=$POSTGRES_PORT/tcp --permanent"
sudo su -c "firewall-cmd --add-service=postgresql --permanent"
sudo su -c "firewall-cmd --reload"
sudo su -c "systemctl restart postgresql.service"
fi

# Set up the local access

echo "Backing up pg_hba.conf..."

cp "${PG_CONFIG}" "${PG_CONFIGBK}"

cp "${PG_HBA}" "${PG_HBABK}"

sudo su -c "systemctl stop postgresql.service"

sudo su -c echo "listen_addresses = '*'" > ${DATABASE_HOME}/data/postgresql.conf

sudo su -c echo "host    all             all             $IP_address/32          md5" > $DATABASE_HOME/data/pg_hba.conf

sudo su -c "systemctl restart postgresql.service"


                                         






