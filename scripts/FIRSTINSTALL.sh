#!/bin/bash

# This script is intended to be run on a fresh debian server installation.
# It performs the following tasks:

# Define variables
DOCKER_CORE_PATH="/opt/docker/core"
SSH_PORT=55222
NEW_DOCKER_CORE_PATH=$DOCKER_CORE_PATH

# Check if sudo is installed, otherwise install it
if ! command -v sudo &> /dev/null; then
    echo "sudo is not installed. Installing sudo..."
    apt-get update
    apt-get install -y sudo
else
    echo "sudo is already installed."
fi

#Create a New User
if sudo adduser apps; then
    sudo adduser apps sudo
else
    echo "Failed to create the 'apps' user. Exiting."
    exit 1
fi
else
    sudo adduser apps
fi
sudo adduser apps sudo

#Update the OS
sudo apt update
sudo apt upgrade -y

#Install the Required Packages
#zip and unzip are for compression, net-tools is to check port usage and availability, htop provides a nice UI to see running processes, and ncdu helps visualize disk space usage.#
sudo apt install -y ca-certificates curl gnupg lsb-release htop zip unzip gnupg apt-transport-https net-tools ncdu apache2-utils git acl ufw fail2ban ntp network-manager openssh

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
sudo ufw allow ${SSH_PORT}/tcp
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
# Display the current firewall rules for review
sudo ufw show added

# Prompt the user for confirmation before enabling the firewall
read -p "Are you sure you want to enable the firewall with the above rules? (yes/no): " CONFIRM
if [[ "$CONFIRM" == "yes" ]]; then
    sudo ufw enable
else
    echo "Firewall enabling aborted."
fi
#sudo ufw allow 80/tcp
# Enable the firewall
# Change the SSH port from 22 to 55222
if grep -q "^Port " /etc/ssh/sshd_config; then
    sudo sed -i "s/^Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config
else
    echo "Port ${SSH_PORT}" | sudo tee -a /etc/ssh/sshd_config
fi
sudo ufw status verbose # This should show the rules we just added

#######################################
########## Secure SSH Access ##########
#######################################
# Backup the original sshd_config file
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# Change the SSH port from 22 to 55222
sudo sed -i "s/#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config
# Restart the SSH service to apply the changes
sudo systemctl restart ssh


# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
#sudo usermod -aG docker apps # use intead of sudo adduser apps docker to grant root docker permissions
sudo adduser apps docker # add user to docker group
sudo systemctl enable docker
sudo systemctl start docker

# Check if the docker folder already exists
if [ ! -d "$DOCKER_CORE_PATH" ]; then
    # Create the docker folder
    sudo mkdir -p "$DOCKER_CORE_PATH"
else
    echo "The folder $DOCKER_CORE_PATH already exists."
fi

# Check if the destination folder is empty
if [ "$(ls -A $DOCKER_CORE_PATH 2>/dev/null)" ]; then
    echo "Error: The destination folder $DOCKER_CORE_PATH must be empty."
    exit 1
fi

# Clone the repository into the specified folder
sudo git clone https://github.com/Hades2323/DockerCore.git "$DOCKER_CORE_PATH"

# Set the ownership of the cloned repository to the 'apps' user
sudo chown -R apps:apps "$DOCKER_CORE_PATH"

# Create log folder for traefik 3
sudo mkdir -p "$DOCKER_CORE_PATH/logs/$(hostname)/traefik"

# Secure the secrets folder and .env file
sudo chown root:root "$DOCKER_CORE_PATH/secrets"
sudo chmod 600 "$DOCKER_CORE_PATH/secrets"
sudo chown root:root "$DOCKER_CORE_PATH/.env"
sudo chmod 600 "$DOCKER_CORE_PATH/.env"

# Set the ACL for the docker folder
sudo chmod 775 "$DOCKER_CORE_PATH"
sudo setfacl -Rdm u:apps:rwx "$DOCKER_CORE_PATH"
sudo setfacl -Rm u:apps:rwx "$DOCKER_CORE_PATH"
sudo setfacl -Rdm g:docker:rwx "$DOCKER_CORE_PATH"
sudo setfacl -Rm g:docker:rwx "$DOCKER_CORE_PATH"

sudo mv "$DOCKER_CORE_PATH/docker-compose-vps01.yml" "$DOCKER_CORE_PATH/docker-compose-$(hostname).yml"
sudo mv "$DOCKER_CORE_PATH/appdata/traefik3/rules/vps01" "$DOCKER_CORE_PATH/appdata/traefik3/rules/$(hostname)"
sudo mv "$DOCKER_CORE_PATH/logs/vps01" "$DOCKER_CORE_PATH/logs/$(hostname)"
sudo mv "$DOCKER_CORE_PATH/compose/vps01" "$DOCKER_CORE_PATH/compose/$(hostname)"
sudo chmod 600 "$DOCKER_CORE_PATH/appdata/traefik3/acme/acme.json"
sudo chmod +x "$DOCKER_CORE_PATH/appdata/postgresql/script/*"
sudo chmod +x "$DOCKER_CORE_PATH/appdata/mariadb/script/*"
sudo find "$DOCKER_CORE_PATH" -type f -name "*.sh" -exec chmod +x {} \;

# Mattermost default UID and GID is 2000
# Set the ownership of the mattermost folder to the 'apps' user and group
sudo chown -R 2000:2000 "$DOCKER_CORE_PATH/appdata/mattermost"

# Get the UID and GID of the 'apps' user and group
APPS_UID=$(id -u apps)
APPS_GID=$(id -g apps)
# Insert the UID and GID into the .env file
sudo sed -i "s/^PUID=.*/PUID=$APPS_UID/" "$DOCKER_CORE_PATH/.env"
sudo sed -i "s/^PGID=.*/PGID=$APPS_GID/" "$DOCKER_CORE_PATH/.env"
# Insert the hostname into the .env file
sudo sed -i "s/^HOSTNAME=.*/HOSTNAME=$(hostname)/" "$DOCKER_CORE_PATH/.env"
# Ask and insert the principal public domain name into the .env file
read -p "Enter the principal public domain name: " PUBLIC_DOMAIN
sudo sed -i "s/^DOMAINNAME_00=.*/DOMAINNAME_00=$PUBLIC_DOMAIN/" "$DOCKER_CORE_PATH/.env"


#######################################
########## Secure SSH Access ##########
#######################################
# Fail2ban is a service that automatically blocks IP addresses that have too many failed login attempts
sudo ln "$DOCKER_CORE_PATH/appdata/fail2ban/jail.local" /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban


# Create external apps mount folders
sudo mkdir -p /mnt/apps /mnt/multimedia /mnt/download /mnt/config /mnt/backup /mnt/log /mnt/books /mnt/fotovideo

# Create the secret for traefik basic auth
echo -e "Create user and password for traefik basic auth: "
read -p "Enter username: " HTTP_USERNAME
read -sp "Enter password: " HTTP_PASSWORD
echo
sudo htpasswd -cBb "$DOCKER_CORE_PATH/secrets/basic_auth_credentials" "$HTTP_USERNAME" "$HTTP_PASSWORD"

# Create the secret for root mariadb user
echo -e "Create root mariadb user password: "
read -sp "Enter password: " MARIADB_ROOT_PASSWORD
echo
echo "$MARIADB_ROOT_PASSWORD" | sudo tee "$DOCKER_CORE_PATH/secrets/mysql_root_password"

# Create the secret for postgres user
echo -e "Create postgres user password: "
read -sp "Enter password: " POSTGRES_ROOT_PASSWORD
echo
echo "$POSTGRES_ROOT_PASSWORD" | sudo tee "$DOCKER_CORE_PATH/secrets/postgres_root_password"

# Create the secret for vnc password
echo -e "Create vnc password: "
read -sp "Enter password: " VNC_PASSWORD
echo
echo "$VNC_PASSWORD" | sudo tee "$DOCKER_CORE_PATH/secrets/vnc_password"

# create the secret for AUTHELIA_JWT_SECRET
AUTHELIA_JWT_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)
echo "$AUTHELIA_JWT_SECRET" | sudo tee "$DOCKER_CORE_PATH/secrets/authelia_jwt_secret"

# create the secret for AUTHELIA_SESSION_SECRET
AUTHELIA_SESSION_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)
echo "$AUTHELIA_SESSION_SECRET" | sudo tee "$DOCKER_CORE_PATH/secrets/authelia_session_secret"

# create the secret for AUTHELIA_STORAGE_ENCRYPTION_KEY
AUTHELIA_STORAGE_ENCRYPTION_KEY=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)
echo "$AUTHELIA_STORAGE_ENCRYPTION_KEY" | sudo tee "$DOCKER_CORE_PATH/secrets/authelia_storage_encryption_key"

# create the secret for vaultwarden_admin_token
VAULTWARDEN_ADMIN_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64)
echo "$VAULTWARDEN_ADMIN_TOKEN" | sudo tee "$DOCKER_CORE_PATH/secrets/vaultwarden_admin_token"

# create the secret for nextcloud_admin_password
NEXTCLOUD_ADMIN_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
echo "$NEXTCLOUD_ADMIN_PASSWORD" | sudo tee "$DOCKER_CORE_PATH/secrets/nextcloud_admin_password"

# create the secret for odoo_password
ODOO_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
echo "$ODOO_PASSWORD" | sudo tee "$DOCKER_CORE_PATH/secrets/odoo_password"

# create the secret for umami_app_secret
UMAMI_APP_SECRET=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
echo "$UMAMI_APP_SECRET" | sudo tee "$DOCKER_CORE_PATH/secrets/umami_app_secret"

# create the secret for umami_admin_password
UMAMI_ADMIN_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
echo "$UMAMI_ADMIN_PASSWORD" | sudo tee "$DOCKER_CORE_PATH/secrets/umami_admin_password"

# Check if DOCKER_CORE_PATH is not /opt/docker/core
if [ "$DOCKER_CORE_PATH" != "/opt/docker/core" ]; then
    # Replace all occurrences of /opt/docker/core with the new path in all files within the DOCKER_CORE_PATH folder and subfolders
    find "$DOCKER_CORE_PATH" -type f -exec sed -i "s|/opt/docker/core|$DOCKER_CORE_PATH|g" {} +
    echo "All occurrences of '/opt/docker/core' have been replaced with '$DOCKER_CORE_PATH' in the DOCKER_CORE_PATH folder and subfolders."
fi


echo -e "=============================================================================================================================================================
\n=============================================================================================================================================================
\n
\n All done,
\n SSH port $SSH_PORT,
\n set variables in .env file,
\n comment/uncomment docker-compose-$(hostname).yml
\n and set secrets files in $DOCKER_CORE_PATH/secrets
\n
\n execute
\n sudo docker compose -f $DOCKER_CORE_PATH/docker-compose-$(hostname).yml --profile all --profile core --profile media --profile downloads --profile arrs --profile dbs --profile finance up -d
\n=============================================================================================================================================================
\n============================================================================================================================================================="

# change user to apps
sudo su - apps