!/bin/bash
#Source variables file
if [ -f "variablesjboss" ]; then
    source variablesjboss
else
    echo "Error: variablesJboss file not found!"
    exit 1
fi

# Set default values if not defined in variables file
USERNAME=${USERNAME:-jbossadmin}
PASSWORD=${PASSWORD:-defaultPassword123}
REALM=${REALM:-ManagementRealm}
JBOSS_HOME=${JBOSS_HOME:-/opt/jboss}
IP_ADD=${IP_ADD:-$(hostname -I | awk '{print $1}')}
LOCAL_H=${LOCAL_H:-127.0.0.1}

# Install Java
echo -e "Installing Java..."
sudo yum install java-17-openjdk -y

# Verify Java installation
if ! java -version &>/dev/null; then
    echo "Error: Java installation failed!"
    exit 1
fi

echo -e "\nInstalling JBoss from the .tar & zip file"

# Create temporary directory and navigate to it
mkdir -p /tmp/jboss-install
cd /tmp/jboss-install

# Extract the compressed file
echo "Extracting JBoss archive..."
if [ -f /tmp/sys-admin/jboss*.tar.gz ]; then
    sudo tar -xzf /tmp/sys-admin/jboss*.tar.gz
elif [ -f /tmp/sys-admin/jboss*.tar ]; then
    sudo tar -xf /tmp/sys-admin/jboss*.tar
else
    echo "Error: JBoss tar file not found in /tmp/sys-admin/"
    exit 1
fi

# Unzip the JBoss file if it exists
if [ -f jboss-eap*.zip ]; then
    echo "Unzipping JBoss EAP..."
    sudo unzip -q jboss-eap*.zip
fi

# Remove the zip file after extraction
if [ -f jboss-eap*.zip ]; then
    sudo rm jboss-eap*.zip
fi

# Copy the JBoss folder to /opt
echo "Moving JBoss to /opt..."
sudo mv jboss-eap-8.0 /opt/

# Create a symlink for JBoss
sudo ln -sf /opt/jboss-eap-8.0 /opt/jboss

echo -e "\n\tJBoss is installed...Thank you!!!"

# Create JBoss admin user and add to sudoers
echo "Creating JBoss admin user: $USERNAME"
sudo adduser $USERNAME

# Add user to wheel group for sudo access
sudo usermod -aG wheel $USERNAME

# Assign password to the user
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Change ownership of JBoss installation
echo "Setting ownership of JBoss files..."
sudo chown -R $USERNAME:$USERNAME /opt/jboss-eap-8.0/
sudo chown -R $USERNAME:$USERNAME /opt/jboss/

### Steps before running JBoss ###

# Navigate to configuration directory
cd /opt/jboss/standalone/configuration

# Take backup of standalone.xml file
echo "Creating backup of standalone.xml..."
sudo cp standalone.xml standalone-bkp.xml

# Configure socket binding (bind application server to network interface)
echo "Configuring network binding..."
sudo sed -i "s/$LOCAL_H/$IP_ADD/g" $JBOSS_HOME/standalone/configuration/standalone.xml

# Configure firewall ports
echo "Configuring firewall..."
sudo firewall-cmd --zone=public --permanent --add-port=8009/tcp  # AJP connector
sudo firewall-cmd --zone=public --permanent --add-port=8080/tcp  # HTTP
sudo firewall-cmd --zone=public --permanent --add-port=8443/tcp  # HTTPS
sudo firewall-cmd --zone=public --permanent --add-port=9990/tcp  # Management console HTTP
sudo firewall-cmd --zone=public --permanent --add-port=9993/tcp  # Management console HTTPS
sudo firewall-cmd --reload

# Display configured ports
echo "Configured firewall ports:"
sudo firewall-cmd --zone=public --list-ports

# Add management user
echo "Adding management user..."
cd $JBOSS_HOME/bin

# Run add-user utility
sudo -u $USERNAME $JBOSS_HOME/bin/add-user.sh \
    -u "$USERNAME" \
    -p "$PASSWORD" \
    -r "$REALM" \
    --silent \
    --enable

# Check if user was added successfully
if [ $? -eq 0 ]; then
    echo "Successfully added management user: $USERNAME"
else
    echo "Failed to add management user. Check permissions or if user already exists."
    exit 1
fi

# Create systemd service file for JBoss
echo "Creating systemd service file..."
sudo tee /etc/systemd/system/jboss.service > /dev/null <<EOF
[Unit]
Description=JBoss EAP 8.0
After=network.target

[Service]
Type=forking
User=$USERNAME
Group=$USERNAME
Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk
Environment=JBOSS_HOME=$JBOSS_HOME
ExecStart=$JBOSS_HOME/bin/standalone.sh -c standalone.xml -b $IP_ADD
ExecStop=$JBOSS_HOME/bin/jboss-cli.sh --connect command=:shutdown
TimeoutStartSec=600
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable JBoss service
sudo systemctl daemon-reload
sudo systemctl enable jboss.service

echo -e "\n=== JBoss Installation Complete ==="
echo "Management Console: http://$IP_ADD:9990"
echo "Application URL: http://$IP_ADD:8080"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo ""
echo "To start JBoss:"
echo "  sudo systemctl start jboss"
echo ""
echo "To check status:"
echo "  sudo systemctl status jboss"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u jboss -f"

# Cleanup temporary files
cd /
rm -rf /tmp/jboss-install

echo "Installation script completed successfully!"
