#!/bin/bash

# Variables for paths
TKG_KERNEL_DIR="/srv/http/tkg/linux-tkg"  # Path to TKG kernel directory
REPO_DIR="/srv/http/kernel-repo"  # Path to repository directory
REPO_NAME="customkernel"  # Name of the repository
KERNEL_ORG_URL="https://www.kernel.org"  # URL of kernel.org
CUSTOMIZATION_CFG="$TKG_KERNEL_DIR/customization.cfg"  # Path to customization.cfg file
LAST_KERNEL_FILE="/srv/http/tkg/last_kernel_version.txt"  # File to store the last kernel version

# Variables for settings in customization.cfg
DISTRO="Arch"
FORCE_ALL_THREADS="true"
MENUNCONFIG="false"
CPUSCHED="pds"
COMPILER="gcc"
SCHED_YIELD_TYPE="0"
RR_INTERVAL="2"
TICKLESS="2"
ACS_OVERRIDE="false"
PROCESSOR_OPT="zen4"
TIMER_FREQ="1000"
DEFAULT_CPU_GOV="ondemand"

# Choice between Stable and Mainline
KERNEL_TYPE="mainline"  # Set to "stable" for the latest stable version or "mainline" for the latest mainline version

# Function to get the latest Mainline version from kernel.org
get_latest_mainline_version() {
    curl -s $KERNEL_ORG_URL | grep -A1 'mainline:' | grep -oP '(?<=<strong>)[0-9.]+(?=</strong>)'
}

# Function to get the latest Stable version from kernel.org
get_latest_stable_version() {
    curl -s $KERNEL_ORG_URL | grep -A1 'stable:' | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1
}

# Check which kernel type should be used
if [ "$KERNEL_TYPE" == "mainline" ]; then
    LATEST_KERNEL=$(get_latest_mainline_version)
elif [ "$KERNEL_TYPE" == "stable" ]; then
    LATEST_KERNEL=$(get_latest_stable_version)
else
    echo "Invalid KERNEL_TYPE. Set it to 'mainline' or 'stable'."
    exit 1
fi

# Get current and stored kernel version
if [ -f "$LAST_KERNEL_FILE" ]; then
    LAST_KERNEL=$(cat $LAST_KERNEL_FILE)
else
    LAST_KERNEL="none"
fi

# If a new kernel version is found
if [ "$LATEST_KERNEL" != "$LAST_KERNEL" ]; then
    echo "New kernel version $LATEST_KERNEL found. Downloading the latest TKG patches and compiling the kernel..."

    # Download latest TKG patches from GitHub
    if [ -d "$TKG_KERNEL_DIR" ]; then
        rm -rf "$TKG_KERNEL_DIR"
    fi
    git clone https://github.com/Frogging-Family/linux-tkg.git $TKG_KERNEL_DIR

    # Adjust customization.cfg
    sed -i "s/^_distro=.*/_distro=\"$DISTRO\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_version=.*/_version=\"$LATEST_KERNEL\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_force_all_threads=.*/_force_all_threads=\"$FORCE_ALL_THREADS\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_menunconfig=.*/_menunconfig=\"$MENUNCONFIG\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_cpusched=.*/_cpusched=\"$CPUSCHED\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_compiler=.*/_compiler=\"$COMPILER\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_sched_yield_type=.*/_sched_yield_type=\"$SCHED_YIELD_TYPE\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_rr_interval=.*/_rr_interval=\"$RR_INTERVAL\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_tickless=.*/_tickless=\"$TICKLESS\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_acs_override=.*/_acs_override=\"$ACS_OVERRIDE\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_processor_opt=.*/_processor_opt=\"$PROCESSOR_OPT\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_timer_freq=.*/_timer_freq=\"$TIMER_FREQ\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_default_cpu_gov=.*/_default_cpu_gov=\"$DEFAULT_CPU_GOV\"/" $CUSTOMIZATION_CFG

    # Change to TKG kernel directory
    cd $TKG_KERNEL_DIR

    # Compile kernel (don't install)
    makepkg -s

    # Check if compilation was successful
    if [ $? -eq 0 ]; then
        echo "Kernel successfully compiled."

        # Move package to repository
        mv *.pkg.tar.zst $REPO_DIR

        # Update repository database
        repo-add $REPO_DIR/$REPO_NAME.db.tar.gz $REPO_DIR/*.pkg.tar.zst

        # Save the new kernel version
        echo $LATEST_KERNEL > $LAST_KERNEL_FILE

        echo "Kernel package moved to repository and repository updated."
    else
        echo "Error compiling the kernel."
        exit 1
    fi
else
    echo "No new kernel version available. Last version: $LAST_KERNEL"
fi
