#!/bin/bash

# install sudo
apt-get update
apt-get install -y sudo

#Create a New User
sudo adduser apps
sudo adduser apps sudo

#Update the OS
sudo apt update
sudo apt upgrade -y

#Install the Required Packages
#zip and unzip are for compression, net-tools is to check port usage and availability, htop provides a nice UI to see running processes, and ncdu helps visualize disk space usage.#
sudo apt install -y ca-certificates curl gnupg lsb-release htop zip unzip gnupg apt-transport-https net-tools ncdu apache2-utils git acl ufw fail2ban ntp network-manager

#Perform Server Tweaks
#A few system configuration tweaks to enhance the performance and handling of large list of files (e.g. Plex/Jellyfin metadata)
# Add the following lines to the end of /etc/sysctl.conf
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=262144" | sudo tee -a /etc/sysctl.conf
# Apply the changes
sudo sysctl -p

############################################
########## Hostname Configuration ##########
############################################
# Prompt the user to input the new hostname
read -p "Enter the new hostname: " NEW_HOSTNAME
# Backup the current hostname files
sudo cp /etc/hostname /etc/hostname.bak
sudo cp /etc/hosts /etc/hosts.bak
# Change the hostname
echo "$NEW_HOSTNAME" | sudo tee /etc/hostname
# Update the /etc/hosts file
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
# Apply the changes
sudo hostnamectl set-hostname "$NEW_HOSTNAME"
# Verify the changes
echo "The hostname has been changed to: $(hostname)"


############################################
########## Firewall Configuration ##########
############################################
# Block all incoming connections by default
sudo ufw default deny incoming
# Allow all outgoing connections by default
sudo ufw default allow outgoing
# Allow all routed connections by default
# This is necessary for Tailscale to work properly
sudo ufw default allow routed
# Allow connections from all private networks
sudo ufw allow from 10.0.0.0/8
sudo ufw allow from 172.16.0.0/12
sudo ufw allow from 192.168.0.0/16
# Allow connections from the Tailscale network (default range)
sudo ufw allow from 100.64.0.0/10
# Allow SSH connections
sudo ufw allow 55222/tcp
# Allow HTTP and HTTPS connections
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
# Allow connections to qbitorrent
sudo ufw allow 54321/tcp
sudo ufw allow 54321/udp
# Allow connections to rustdesk
#sudo ufw allow 21114/tcp #used for web console, only available in Pro version hbbs
sudo ufw allow 21115/tcp #relay ports used for the NAT type test hbbs
sudo ufw allow 21116/tcp #relay ports is used for TCP hole punching and connection service hbbs
sudo ufw allow 21117/tcp #relay service hbbr 
sudo ufw allow 21118/tcp #WebSocket ports used to support web clients hbbs
sudo ufw allow 21119/tcp #WebSocket ports used to support web clients hbbr
sudo ufw allow 21116/udp #relay ports used for the ID registration and heartbeat service
# Allow connections to Lyrion Music Server (if needed)
#sudo ufw allow 9090/tcp
#sudo ufw allow 3483/tcp
#sudo ufw allow 3483/udp
# Allow Docker connections (if needed)
#sudo ufw allow 2375/tcp
# Allow connections to the Docker API (if needed)
#sudo ufw allow 2376/tcp
# Allow connections to the Docker Swarm API (if needed)
#sudo ufw allow 7946/tcp
# Allow connections to the Docker Overlay Network (if needed)
#sudo ufw allow 4789/udp
# Allow connections to the Docker Container Network (if needed)
#sudo ufw allow 7946/udp
# Allow connections to the DNS (if needed)
sudo ufw allow 53/tcp
sudo ufw allow 853/tcp
# Allow connections to the Docker Registry (if needed)
#sudo ufw allow 5000/tcp
# Allow connections to the Docker Volume (if needed)
#sudo ufw allow 8080/tcp
# Allow connections to the Docker Network (if needed)
#sudo ufw allow 8080/udp
# Allow connections to the Docker Bridge Network (if needed)
#sudo ufw allow 80/udp
# Allow connections to the Docker Host Network (if needed)
#sudo ufw allow 443/udp
# Allow connections to the Docker Macvlan Network (if needed)
#sudo ufw allow 80/tcp
# Enable the firewall
sudo ufw enable
# Check the status of the firewall
sudo ufw status verbose # This should show the rules we just added

#######################################
########## Secure SSH Access ##########
#######################################
# Backup the original sshd_config file
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# Change the SSH port from 22 to 55222
sudo sed -i 's/#Port 22/Port 55222/' /etc/ssh/sshd_config
# Restart the SSH service to apply the changes
sudo systemctl restart ssh


# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
#sudo usermod -aG docker apps # use intead of sudo adduser apps docker to grant root docker permissions
sudo adduser apps docker # add user to docker group
sudo systemctl enable docker
sudo systemctl start docker

# Create the docker folder
sudo mkdir -p /opt/docker/core

# Clone the repository into the specified folder
sudo git clone https://github.com/Hades2323/DockerCore.git /opt/docker/core

# Set the ownership of the cloned repository to the 'apps' user
sudo chown -R apps:apps /opt/docker/core

# Create log folder for traefik 3
sudo mkdir -p /opt/docker/core/logs/$(hostname)/traefik

# secure the secrets folder and .env file
sudo chown root:root /opt/docker/core/secrets
sudo chmod 600 /opt/docker/core/secrets
sudo chown root:root /opt/docker/core/.env
sudo chmod 600 /opt/docker/core/.env

# Set the acl for the docker folder
sudo chmod 775 /opt/docker/core
sudo setfacl -Rdm u:apps:rwx /opt/docker/core
sudo setfacl -Rm u:apps:rwx /opt/docker/core
sudo setfacl -Rdm g:docker:rwx /opt/docker/core
sudo setfacl -Rm g:docker:rwx /opt/docker/core

sudo cp /opt/docker/core/docker-compose-vps01.yml /opt/docker/core/docker-compose-$(hostname).yml
sudo cp -r /opt/docker/core/appdata/traefik3/rules/vps01/ /opt/docker/core/appdata/traefik3/rules/$(hostname)
sudo cp -r /opt/docker/core/logs/vps01/ /opt/docker/core/logs/$(hostname)
sudo cp -r /opt/docker/core/compose/vps01/ /opt/docker/core/compose/$(hostname)
sudo chmod 600 /opt/docker/core/appdata/traefik3/acme/acme.json
sudo chmod +x /opt/docker/core/appdata/postgresql/script/*
sudo chmod +x /opt/docker/core/appdata/mariadb/script/*

# mattermost default uid and gid is 2000
# Set the ownership of the mattermost folder to the 'apps' user and group
sudo chown -R 2000:2000 /opt/docker/core/appdata/mattermost

# Get the UID and GID of the 'apps' user and group
APPS_UID=$(id -u apps)
APPS_GID=$(id -g apps)
# Insert the UID and GID into the .env file
sudo sed -i "s/^PUID=.*/PUID=$APPS_UID/" /opt/docker/core/.env
sudo sed -i "s/^PGID=.*/PGID=$APPS_GID/" /opt/docker/core/.env
# Insert the hostname into the .env file
sudo sed -i "s/^HOSTNAME=.*/HOSTNAME=$(hostname)/" /opt/docker/core/.env


#######################################
########## Secure SSH Access ##########
#######################################
# Fail2ban is a service that automatically blocks IP addresses that have too many failed login attempts
sudo ln /opt/docker/core/appdata/fail2ban/jail.local /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban


# Create external apps mount folders
sudo mkdir -p /mnt/apps /mnt/multimedia /mnt/download /mnt/config /mnt/backup /mnt/log /mnt/books /mnt/fotovideo

# Create the secret for traefik basic auth
echo -e "Create user and password for traefik basic auth: "
read -p "Enter username: " HTTP_USERNAME
read -sp "Enter password: " HTTP_PASSWORD
echo
sudo htpasswd -cBb /opt/docker/core/secrets/basic_auth_credentials "$HTTP_USERNAME" "$HTTP_PASSWORD"

# Create the secret for root mariadb user
echo -e "Create root mariadb user password: "
read -sp "Enter password: " MARIADB_ROOT_PASSWORD
echo
echo "$MARIADB_ROOT_PASSWORD" | sudo tee /opt/docker/core/secrets/mysql_root_password

# Create the secret for postgres user
echo -e "Create postgres user password: "
read -sp "Enter password: " POSTGRES_ROOT_PASSWORD
echo
echo "$POSTGRES_ROOT_PASSWORD" | sudo tee /opt/docker/core/secrets/postgres_root_password

# Create the secret for vnc password
echo -e "Create vnc password: "
read -sp "Enter password: " VNC_PASSWORD
echo
echo "$VNC_PASSWORD" | sudo tee /opt/docker/core/secrets/vnc_password

echo -e "=============================================================================================================================================================
\n=============================================================================================================================================================
\n
\n All done,
\n SSH port 55222,
\n set variables in .env file,
\n comment/uncomment docker-compose-$(hostname).yml
\n and set secrets files in /opt/docker/core/secrets
\n
\n execute
\n sudo docker compose -f /opt/docker/core/docker-compose-$(hostname).yml --profile all --profile core --profile media --profile downloads --profile arrs --profile dbs up -d
\n=============================================================================================================================================================
\n============================================================================================================================================================="

# change user to apps
sudo su - apps