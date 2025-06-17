#!/bin/bash

# This script will:
#   - Install PostgreSQL server 
#   - Initialize the database
#   - Enable and start the PostgreSQL service
#   - Set up basic security (firewall and local access)
#   - Create database user and database

set -e  # Exit on any error

# Source variables file
if [ -f "variablespostgres" ]; then
    source variablespostgres
else
    echo "Error: variablespostgres file not found!"
    exit 1
fi

# Set default values if not defined in variables file
POSTGRES_VERSION=${version:-15}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-defaultPassword123}
DATABASE_USER=${DATABASE_USER:-appuser}
DBUSER_PASSWORD=${DBUSER_PASSWORD:-userPassword123}
DATABASE_NAME=${DATABASE_NAME:-appdb}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
IP_ADDRESS=${IP_ADDRESS:-$(hostname -I | awk '{print $1}')}

# Set PostgreSQL paths
PG_DATA_DIR="/var/lib/pgsql/${POSTGRES_VERSION}/data"
PG_HBA="${PG_DATA_DIR}/pg_hba.conf"
PG_CONF="${PG_DATA_DIR}/postgresql.conf"

echo "=== PostgreSQL ${POSTGRES_VERSION} Installation Script ==="
echo "Database User: $DATABASE_USER"
echo "Database Name: $DATABASE_NAME"
echo "Server IP: $IP_ADDRESS"
echo ""

# Update system packages
echo "Updating system packages..."
sudo dnf update -y

# Check available PostgreSQL modules
echo "Checking available PostgreSQL modules..."
sudo dnf module list postgresql

# Check if PostgreSQL is already installed
echo "Checking if PostgreSQL ${POSTGRES_VERSION} is already installed..."
if rpm -qa | grep -q "postgresql${POSTGRES_VERSION}-server"; then
    echo "PostgreSQL ${POSTGRES_VERSION} is already installed."
else
    echo "Installing PostgreSQL ${POSTGRES_VERSION}..."
    sudo dnf module enable postgresql:${POSTGRES_VERSION} -y
    sudo dnf install postgresql${POSTGRES_VERSION}-server postgresql${POSTGRES_VERSION} -y
fi

# Check if database is already initialized
if [ ! -f "${PG_DATA_DIR}/PG_VERSION" ]; then
    echo "Initializing PostgreSQL database..."
    sudo /usr/pgsql-${POSTGRES_VERSION}/bin/postgresql-${POSTGRES_VERSION}-setup initdb
else
    echo "PostgreSQL database is already initialized."
fi

# Set password for postgres system user
echo "Setting password for postgres system user..."
echo "postgres:$POSTGRES_PASSWORD" | sudo chpasswd

# Enable and start PostgreSQL service
echo "Enabling and starting PostgreSQL service..."
sudo systemctl enable postgresql-${POSTGRES_VERSION}
sudo systemctl start postgresql-${POSTGRES_VERSION}

# Wait for service to start
sleep 3

# Check if service is running
if systemctl is-active --quiet postgresql-${POSTGRES_VERSION}; then
    echo "PostgreSQL service is running successfully."
else
    echo "Error: PostgreSQL service failed to start."
    sudo systemctl status postgresql-${POSTGRES_VERSION}
    exit 1
fi

# Create database user and database
echo "Creating database user and database..."
sudo -u postgres psql << EOF
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DATABASE_USER') THEN
        CREATE USER $DATABASE_USER WITH PASSWORD '$DBUSER_PASSWORD';
        RAISE NOTICE 'User $DATABASE_USER created successfully';
    ELSE
        RAISE NOTICE 'User $DATABASE_USER already exists';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE $DATABASE_NAME OWNER $DATABASE_USER'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DATABASE_NAME')\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DATABASE_NAME TO $DATABASE_USER;

-- List users and databases
\du
\l

\q
EOF

# Backup configuration files
echo "Backing up configuration files..."
sudo cp "$PG_HBA" "${PG_HBA}.backup"
sudo cp "$PG_CONF" "${PG_CONF}.backup"

# Configure PostgreSQL to listen on all addresses
echo "Configuring PostgreSQL to accept connections..."
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
sudo sed -i "s/#port = 5432/port = $POSTGRES_PORT/" "$PG_CONF"

# Configure authentication in pg_hba.conf
echo "Configuring authentication..."
# Add remote connection rule
sudo bash -c "echo 'host    all             all             0.0.0.0/0               md5' >> $PG_HBA"

# Configure firewall
echo "Configuring firewall for PostgreSQL..."
if systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --zone=public --add-port=$POSTGRES_PORT/tcp --permanent
    sudo firewall-cmd --add-service=postgresql --permanent
    sudo firewall-cmd --reload
    echo "Firewall configured successfully."
else
    echo "Firewalld is not running - skipping firewall configuration."
fi

# Restart PostgreSQL to apply configuration changes
echo "Restarting PostgreSQL to apply configuration changes..."
sudo systemctl restart postgresql-${POSTGRES_VERSION}

# Wait for service to restart
sleep 3

# Verify service is running
if systemctl is-active --quiet postgresql-${POSTGRES_VERSION}; then
    echo "PostgreSQL service restarted successfully."
else
    echo "Error: PostgreSQL service failed to restart."
    exit 1
fi

# Test database connection
echo "Testing database connection..."
if sudo -u postgres psql -d $DATABASE_NAME -c "SELECT version();" > /dev/null 2>&1; then
    echo "Database connection test successful."
else
    echo "Warning: Database connection test failed."
fi

# Display connection information
echo ""
echo "=== PostgreSQL Installation Complete ==="
echo "PostgreSQL Version: $POSTGRES_VERSION"
echo "Service Status: $(systemctl is-active postgresql-${POSTGRES_VERSION})"
echo "Database Name: $DATABASE_NAME"
echo "Database User: $DATABASE_USER"
echo "Server IP: $IP_ADDRESS"
echo "Port: $POSTGRES_PORT"
echo ""
echo "Connection Examples:"
echo "Local connection:"
echo "  sudo -u postgres psql -d $DATABASE_NAME"
echo ""
echo "Remote connection:"
echo "  psql -h $IP_ADDRESS -p $POSTGRES_PORT -U $DATABASE_USER -d $DATABASE_NAME"
echo ""
echo "Service Management:"
echo "  sudo systemctl status postgresql-${POSTGRES_VERSION}"
echo "  sudo systemctl start postgresql-${POSTGRES_VERSION}"
echo "  sudo systemctl stop postgresql-${POSTGRES_VERSION}"
echo "  sudo systemctl restart postgresql-${POSTGRES_VERSION}"
echo ""
echo "Configuration files:"
echo "  PostgreSQL config: $PG_CONF"
echo "  Authentication config: $PG_HBA"
echo "  Backups: ${PG_CONF}.backup, ${PG_HBA}.backup"
echo ""
echo "Installation completed successfully!"
