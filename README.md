## Overview

This system consists of two main components:

1. A server that automatically compiles the latest TKG kernel and hosts a Pacman repository.
2. A client (your main PC) that installs the kernel from this repository.

The automation script checks for new kernel versions daily, compiles them with TKG patches, and updates the repository accordingly.

## Prerequisites

- A Linux server (preferably Arch-based) with sufficient resources to compile kernels.
- A client PC running Arch Linux or an Arch-based distribution.
- Basic knowledge of Linux system administration and bash scripting.

## Server Setup

1. Install required packages:
   ```bash
   sudo pacman -S base-devel git curl wget nginx cronie
   ```

2. Create a directory for the repository:
   ```bash
   sudo mkdir -p /srv/http/kernel-repo
   sudo chown $USER:$USER /srv/http/kernel-repo
   ```

3. Configure Nginx:
   Edit `/etc/nginx/nginx.conf` and add:
   ```nginx
   server {
       listen 80;
       server_name your-server-ip;  # Replace with your server's IP address
       location /kernel-repo/ {
           root /srv/http;
           autoindex on;
       }
   }
   ```

4. Start and enable Nginx:
   ```bash
   sudo systemctl start nginx
   sudo systemctl enable nginx
   ```

5. Clone this repository, and edit the script for your needs:
   ```bash
   git clone https://github.com/zerschranzer/tkg-kernel-automation.git
   cd tkg-kernel-automation
   ```

6. Set up a cron job to run the script daily at 3 AM:
   ```bash
   crontab -e
   ```
   Add the following line:
   ```bash
   0 3 * * * /path/to/tkg-kernel-automation/build_kernel.sh
   ```
   Ensure that your cron daemon is running (`sudo systemctl enable --now cronie`).

## Client Setup

1. Edit `/etc/pacman.conf` on your client PC and add:
   ```ini
   [customkernel]
   Server = http://your-server-ip/kernel-repo
   SigLevel = Optional TrustAll
   ```

2. Update the package database:
   ```bash
   sudo pacman -Sy
   ```

3. Install the custom kernel (after compiling it on the server), for example:
   ```bash
   sudo pacman -S linux611-tkg-pds
   sudo pacman -S linux611-tkg-pds-headers
   ```

## Script Configuration

The `build_kernel.sh` script contains several variables you can customize:

- `TKG_KERNEL_DIR`: Path to the TKG kernel directory.
- `REPO_DIR`: Path to the repository directory.
- `REPO_NAME`: Name of the repository.
- `KERNEL_TYPE`: Choose between "stable" or "mainline".
- Various kernel configuration options (e.g., `CPUSCHED`, `PROCESSOR_OPT`).

Edit these variables according to your preferences before running the script.

## Usage

The script will automatically run daily at 3 AM (as configured in the cron job). It will:

1. Check for a new kernel version.
2. If a new version is available, download the latest TKG patches.
3. Compile the kernel with your specified options.
4. Move the compiled kernel package to the repository.
5. Update the repository database.

On your client PC, you can update to the latest kernel by running:

```bash
sudo pacman -Syu
```

## Maintenance

- Keep your server and client systems up to date.
- Periodically review and update the kernel configuration options as needed.

## Troubleshooting

- If the kernel fails to compile, check the build logs in the TKG kernel directory.
- If the client can't access the repository, ensure Nginx is running and the firewall allows connections.
