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

# This script creates a new user named 'apps' and adds it to the 'sudo' group.
# The 'apps' user is intended to be used for executing containers.
# During the execution of this script, you will be prompted to set a password for the 'apps' user.
# Create a New User apps
echo -e "\e[1;32mCreating a new user named 'apps' and adding it to the 'sudo' group. Insert password for the user 'apps'\e[0m"
if id "apps" &>/dev/null; then
    echo "User 'apps' already exists. Adding to 'sudo' group and changing password."
    sudo usermod -aG sudo apps
    sudo passwd apps
else
    if sudo adduser apps; then
        sudo adduser apps sudo
        echo "User 'apps' created and added to the 'sudo' group successfully."
    else
        echo "Failed to create user 'apps'."
        exit 1
    fi
fi

#Update the OS
sudo apt update
sudo apt upgrade -y

#Install the Required Packages
sudo apt install -y ca-certificates curl ufw fail2ban gnupg lsb-release htop zip unzip gnupg apt-transport-https net-tools ncdu apache2-utils git acl ntp network-manager openssh-server python3 python3-pip python3-venv
# Uncomment the line above to install all packages at once. Below is an explanation of the packages:
# Required for downloading and verifying software packages.
#sudo apt install -y ca-certificates curl gnupg lsb-release apt-transport-https python3 python3-pip python3-venv
# Install system monitoring and management tools
#sudo apt install -y htop zip unzip net-tools ncdu apache2-utils git acl
# Install security and networking tools
#sudo apt install -y ufw fail2ban ntp network-manager openssh-server

#A few system configuration tweaks to enhance the performance and handling of large list of files (e.g. Plex/Jellyfin metadata)
grep -q "^vm.swappiness=10$" /etc/sysctl.conf || echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
grep -q "^vm.vfs_cache_pressure=50$" /etc/sysctl.conf || echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
grep -q "^fs.inotify.max_user_watches=262144$" /etc/sysctl.conf || echo "fs.inotify.max_user_watches=262144" | sudo tee -a /etc/sysctl.conf
# Apply the changes
sudo sysctl -p

############################################
########## Hostname Configuration ##########
############################################
# Prompt the user to input the new hostname
echo -e "\e[1;32mEnter the new hostname:\e[0m"
while true; do
    read -p "New hostname: " NEW_HOSTNAME
    if [[ "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})*$ ]]; then
        break
    else
        echo "Invalid hostname. Please enter a valid hostname (letters, numbers, hyphens, and dots only)."
    fi
done
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
sudo ufw status verbose # This should show the rules we just added
# Allow all routed connections by default
# This is necessary for Tailscale to work properly
# Validate SSH_PORT is a valid integer within the range 1-65535
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    echo "Error: SSH_PORT must be a valid integer between 1 and 65535."
    exit 1
fi

# Allow SSH connections
sudo ufw allow ${SSH_PORT}/tcp
# Removed duplicate rule to avoid redundancy
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
#sudo ufw allow 443/udp
# Display the current firewall rules for review
sudo ufw show added
while true; do
    read -p "Are you sure you want to enable the firewall with the above rules? (yes/no): " CONFIRM
    CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
    if [[ "$CONFIRM" == "yes" || "$CONFIRM" == "no" ]]; then
        break
    else
        echo "Invalid input. Please enter 'yes' or 'no'."
    fi
done
sudo ufw status verbose # This should show the rules we just added
# Enable the firewall if the user confirms

# Prompt the user for confirmation before enabling the firewall
read -p "Are you sure you want to enable the firewall with the above rules? (yes/no): " CONFIRM

#######################################
########## Secure SSH Access ##########
# Backup the original sshd_config file
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# Change the SSH port from 22 to the specified port
# Ensure only one Port directive exists in /etc/ssh/sshd_config
    if grep -q "^Port " /etc/ssh/sshd_config; then
        sudo sed -i "s/^Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config
    else
        echo "Port ${SSH_PORT}" | sudo tee -a /etc/ssh/sshd_config
    fi
echo "Port ${SSH_PORT}" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    sudo sed -i "s/^Port .*/Port ${SSH_PORT}/" /etc/ssh/sshd_config
# Restart the SSH service to apply the changes
sudo systemctl restart ssh
sudo ufw status verbose # This should show the rules we just added
#######################################
# Change the SSH port from 22 to 55222
sudo sed -i "s/#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config


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
    echo "Please remove any existing files or folders in $DOCKER_CORE_PATH before proceeding."
    exit 1
else
    echo "The destination folder $DOCKER_CORE_PATH is empty. Proceeding with the script."
fi

# Clone the repository into the specified folder
if ! ping -c 1 github.com &> /dev/null; then
    echo "Error: Unable to reach GitHub. Please check your internet connection."
    exit 1
else
    echo "GitHub is reachable. Proceeding with the script."
fi

if ! curl -s --head https://github.com/Hades2323/DockerCore.git | grep "200 OK" &> /dev/null; then
    echo "Error: Repository URL is invalid or inaccessible. Please verify the URL."
if ! sudo git clone https://github.com/Hades2323/DockerCore.git "$DOCKER_CORE_PATH"; then
    echo "Error: Failed to clone the repository. Please check your internet connection or verify the repository URL is valid and accessible."
    exit 1
else
    echo "Repository cloned successfully into $DOCKER_CORE_PATH."
fi
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

if [ -f "$DOCKER_CORE_PATH/docker-compose-vps01.yml" ]; then
    sudo mv "$DOCKER_CORE_PATH/docker-compose-vps01.yml" "$DOCKER_CORE_PATH/docker-compose-$(hostname).yml"
else
    echo "Warning: File $DOCKER_CORE_PATH/docker-compose-vps01.yml does not exist."
fi

if [ -d "$DOCKER_CORE_PATH/appdata/traefik3/rules/vps01" ]; then
    sudo mv "$DOCKER_CORE_PATH/appdata/traefik3/rules/vps01" "$DOCKER_CORE_PATH/appdata/traefik3/rules/$(hostname)"
else
    echo "Warning: Directory $DOCKER_CORE_PATH/appdata/traefik3/rules/vps01 does not exist."
fi

if [ -d "$DOCKER_CORE_PATH/logs/vps01" ]; then
    sudo mv "$DOCKER_CORE_PATH/logs/vps01" "$DOCKER_CORE_PATH/logs/$(hostname)"
else
    echo "Warning: Directory $DOCKER_CORE_PATH/logs/vps01 does not exist."
fi

# Ask and validate the principal public domain name before inserting it into the .env file
while true; do
    read -p "Enter the principal public domain name: " PUBLIC_DOMAIN
    if [[ "$PUBLIC_DOMAIN" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z]{2,})+$ ]]; then
        break
    else
        echo "Invalid domain name. Please enter a valid domain name (e.g., example.com)."
    fi
done

# Update the .env file with the public domain name
sudo sed -i "s/^DOMAINNAME_00=.*/DOMAINNAME_00=$PUBLIC_DOMAIN/" "$DOCKER_CORE_PATH/.env"

if [ -d "$DOCKER_CORE_PATH/compose/vps01" ]; then
    sudo mv "$DOCKER_CORE_PATH/compose/vps01" "$DOCKER_CORE_PATH/compose/$(hostname)"
else
    echo "Warning: Directory $DOCKER_CORE_PATH/compose/vps01 does not exist."
fi

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
sudo ln -s "$DOCKER_CORE_PATH/appdata/fail2ban/jail.local" /etc/fail2ban/jail.local
#######################################
# Fail2ban is a service that automatically blocks IP addresses that have too many failed login attempts
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
if [ -f "$COMPOSE_UP_SCRIPT" ]; then
    read -p "The file $COMPOSE_UP_SCRIPT already exists. Do you want to overwrite it? (yes/no): " OVERWRITE
    OVERWRITE=$(echo "$OVERWRITE" | tr '[:upper:]' '[:lower:]')
    if [[ "$OVERWRITE" != "yes" ]]; then
        echo "Aborting creation of $COMPOSE_UP_SCRIPT."
        exit 1
    fi
    # Backup the existing file
    BACKUP_FILE="${COMPOSE_UP_SCRIPT}.bak.$(date +%Y%m%d%H%M%S)"
    sudo cp "$COMPOSE_UP_SCRIPT" "$BACKUP_FILE"
    echo "Existing file backed up as $BACKUP_FILE."
fi
    read -p "The file $COMPOSE_UP_SCRIPT already exists. Do you want to overwrite it? (yes/no): " OVERWRITE
    OVERWRITE=$(echo "$OVERWRITE" | tr '[:upper:]' '[:lower:]')
    if [[ "$OVERWRITE" != "yes" ]]; then
        echo "Aborting creation of $COMPOSE_UP_SCRIPT."
        exit 1
    fi
fi
echo "#!/bin/bash" | sudo tee "$COMPOSE_UP_SCRIPT"
echo "sudo docker compose -f $DOCKER_CORE_PATH/docker-compose-$(hostname).yml --profile all --profile core --profile media --profile downloads --profile arrs --profile dbs --profile finance up -d" | sudo tee -a "$COMPOSE_UP_SCRIPT"
# Make the script executable
sudo chmod +x "$COMPOSE_UP_SCRIPT"

# Get the public IP address of the server
PUBLIC_IP=$(curl -s checkip.amazonaws.com)

sudo systemctl enable ufw

echo "================================================================================"
echo "================================================================================"
echo ""
echo "All setup tasks have been successfully completed,"
echo "SSH port: $SSH_PORT"
echo "ssh apps@$PUBLIC_IP -p $SSH_PORT"
echo ""
echo "Set variables in $DOCKER_CORE_PATH/.env file"
echo "Comment/uncomment docker-compose-$(hostname).yml"
echo "Verify or/and set secrets files in $DOCKER_CORE_PATH/secrets"
echo "The most important is the Cloudflare API token: $DOCKER_CORE_PATH/secrets/cf_dns_api_token. This token is critical because it allows the script to manage DNS records for your domain on Cloudflare. It is used to automatically configure DNS settings required for services like Traefik to function properly. Ensure that the token has the necessary permissions (Zone:DNS:Edit and Zone:Zone:Read) for your domain."
echo ""
echo "Create an API token in your Cloudflare account with the following permissions:"
echo "Refer to Cloudflare's documentation for guidance: https://developers.cloudflare.com/api/tokens/create/"
echo "- Zone:DNS:Edit for your domain $PUBLIC_DOMAIN"
echo "- Zone:Zone:Read for your domain $PUBLIC_DOMAIN"
echo ""
# This command starts the Docker containers defined in the compose file
echo "execute the following command to start the containers:"
echo "sudo ./$COMPOSE_UP_SCRIPT"
echo "to start the containers"
echo ""
echo "============================================================================================================================================================="
echo "============================================================================================================================================================="


# Prompt the user to restart the SSH service to apply the changes
read -p "The SSH configuration has been updated. Do you want to restart the SSH service now? (yes/no): " RESTART_SSH
RESTART_SSH=$(echo "$RESTART_SSH" | tr '[:upper:]' '[:lower:]')
if [[ "$RESTART_SSH" == "yes" ]]; then
    # Restart the SSH service to apply the changes
    sudo systemctl restart ssh
    echo "SSH service has been restarted."
else
    echo "Please remember to restart the SSH service later to apply the changes."
fi

# change user to apps
sudo su - apps