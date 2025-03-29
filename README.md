# Use in a Debian-based distro like... Debian :)

1. **Set Keyboard Layout**
   ```bash
   apt install keyboard-configuration
   ```

# Docker Core Stack Installation

This document describes the steps to download and run the `FIRSTINSTALL.sh` script to set up your Docker Core Stack environment.
Note:
* Make sure you have the necessary permissions to run the commands.
* The script install and configure firewall, fail2ban, Docker; clone the git repository and duplicate some files with the new hostname.
* After running the script, follow the instructions to complete the setup before docker compose execution.

## Steps

1. **Download the `FIRSTINSTALL.sh` script**

   Use the `wget` command to download the `FIRSTINSTALL.sh` script:

   ```bash
   wget -O FIRSTINSTALL.sh https://raw.githubusercontent.com/Hades2323/DockerCore/refs/heads/main/scripts/FIRSTINSTALL.sh
   ```

2. **Make the script executable**
   Change the file permissions to make it executable:
   ```bash
   chmod +x FIRSTINSTALL.sh
   ```

3. **Run the script**
   Run the script to set up your environment:
   ```bash
   ./FIRSTINSTALL.sh
   ```

4. **All-in-one command**
   ```bash
      wget -O FIRSTINSTALL.sh https://raw.githubusercontent.com/Hades2323/DockerCore/refs/heads/main/scripts/FIRSTINSTALL.sh && chmod +x FIRSTINSTALL.sh && bash FIRSTINSTALL.sh
   ```
   *in case of a vps and/or image already sudoed*
   ```bash
      sudo wget -O FIRSTINSTALL.sh https://raw.githubusercontent.com/Hades2323/DockerCore/refs/heads/main/scripts/FIRSTINSTALL.sh && sudo chmod +x FIRSTINSTALL.sh && sudo bash FIRSTINSTALL.sh
   
   ```

### Environments and Secrets

   ```bash
      sudo nano /opt/docker/core/.env
   ```
* change and/or declare
`
  TZ=
  DOMAINNAME_00= 
  CLOUDFLARE_EMAIL=
`

   ```bash
      sudo nano /opt/docker/core/secrets/cf_dns_api_token
   ```
* paste cloudflare api token (permissions: read zone, write dns)

### Docker compose "stack"
  ```bash
    sudo docker compose -f /opt/docker/core/docker-compose-$(hostname).yml --profile all --profile core --profile media --profile downloads --profile arrs --profile dbs up -d
  ```

### [Wiki](https://github.com/Hades2323/DockerCore/wiki)