#!/bin/bash

# Install Java

echo -e "Installing java" 
#sudo yum install java-17-openjdk -y
 

# Install Jboss

echo -e "\nInstalling Jboss from the .tar & zip file"

# extract the compressed file
sudo su -c "tar -xvf /tmp/sys-admin/jboss*" >> class


# Unzip the jboss file
sudo su -c "unzip jboss-eap*" >> classzip


# Remove the unzip file

# rm jboss-eap-8-0.0.zip

# Copy the jboss folder to /opt

sudo su -c "mv jboss-eap-8.0 /opt"

# Create a symlink for jboss 

sudo su -c "ln -s /opt/jboss-eap-8.0 /opt/jboss"

echo -e "\n\tjboss is installed...Thank you!!!"
echo -e "\n"

# Create a user jbossadmin and add him to the sudoers

sudo su -c "adduser jbossadmin"
sudo su -c "usermod -aG wheel jbossadmin"

# Assign a password to jbossadmin

echo "jbossadmin:passwd123" | sudo chpasswd

# Change the ownership of the file jboss

sudo su -c "chown -R jbossadmin:jbossadmin /opt/jboss*"
 

### steps before running Jboss###


#---- step1 ---- get into the folder

cd /opt/jboss/standalone/configuration

#---- steps2---- switch user and take a backup of standalone.xml file

cp standalone.xml standalone-bkp.xml



#---- step3 ---- socket-binding ( or bind the application server to network and interface)

sed -i 's/127.0.0.1/10.10.8.169/g' /opt/jboss/standalone/configuration/standalone.xml
#sudo su -c "sed -i 's/127.0.0.1/`hostname -i`/g' /opt/jboss/standalone/standalone.xml"
			
			#### explanation ####  
			---------------------


# sed = stream editor

# -i = means "in-place"

# s/ = substitute (search and replace)

# g = global ( replace all occurences in the file,not just first one per line).

#---- step4 ---- Allows port

sudo firewall-cmd --zone=public --permanent --add-port=8009/tcp

sudo firewall-cmd --zone=public --permanent --add-port=8080/tcp

sudo firewall-cmd --zone=public --permanent --add-port=9990/tcp

sudo firewall-cmd --reload

sudo firewall-cmd --zone=public --list-port

			
			#### explanation #####
			----------------------
#port 8009 = AJP(Apache JServ Protocol) connector, typically used for integrating with Apache HTTPD (mod_jk/mod_proxy_ajp).In need by Webserver to forward requests to Jboss/Wildfly

#port 8843 = (Secure web traffic) is the default HTTPS port in Jboss/Wildfly.

#port 9990 = For Management Console. It is the default port for JBoss/Wildfly Managemnet interface. Used for Admin access via web browser or for jboss-cli.sh for remote management.

#port 8080 = Default port for HTTP web applications ( unencrypted traffic).

#port 9993 = Managemnet console HTTPS, for Secure Admin access. 

#----step5---- add management user

cd ../../bin
JBOSS_HOME="/opt/jboss"
USERNAME="jbossadmin"
PASSWORD="hello123"
REALM="ManagementRealm"

### Run add-user utility ###

$JBOSS_HOME/bin/add-user.sh \
-u "$USERNAME" \
-p "$PASSWORD" \
-r "$REALM" \
--silent \
--enable \

#  Check if user was added 


if [ $? -eq 0 ]; then
	echo "well done,sucessfully added management user: $USERNAME"
else
	echo "Failed to add management user. Check permissions or if user already exists."
	exit 1
fi

---- step6---- start jboss-eap-8.0

# ./standalone.sh

bash -xxx /opt/jboss/bin/standalone.sh -c standalone.xml -Djboss.server.base.dir=/opt/jboss/standalone & 


