# Use in a Debian-based distro

1. **Set Keyboard Layout**
   ```bash
   apt install keyboard-configuration
   ```

# Docker Core Stack Installation

This document describes the steps to download and run the `FIRSTINSTALL.sh` script to set up your Docker Core Stack environment.

## Steps

1. **Download the `FIRSTINSTALL.sh` script**

   Use the `wget` command to download the `FIRSTINSTALL.sh` script:

   ```bash
   wget -O FIRSTINSTALL.sh https://raw.githubusercontent.com/Hades2323/docker_core/refs/heads/main/scripts/FIRSTINSTALL.sh
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
   wget -O FIRSTINSTALL.sh https://raw.githubusercontent.com/Hades2323/DockerCore/refs/heads/main/scripts/FIRSTINSTALL.sh && chmod +x FIRSTINSTALL.sh && ./FIRSTINSTALL.sh
   ```

Note:
Make sure you have the necessary permissions to run the commands with sudo.
The script will configure the firewall, install Docker, and clone the Docker Core Stack repository.
After running the script, follow the final instructions to complete the setup.
