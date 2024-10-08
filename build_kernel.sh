#!/bin/bash

# Variables for paths
TKG_KERNEL_DIR="/srv/http/tkg/linux-tkg"  # Path to TKG kernel directory
REPO_DIR="/srv/http/kernel-repo"  # Path to repository directory
REPO_NAME="customkernel"  # Name of the repository
CUSTOMIZATION_CFG="$TKG_KERNEL_DIR/customization.cfg"  # Path to customization.cfg file
LAST_KERNEL_FILE="/srv/http/tkg/last_kernel_version.txt"  # File to store the last kernel version

# Variables for settings in customization.cfg
DISTRO="Arch"  # options are "Arch", "Ubuntu", "Debian", "Fedora", "Suse", "Gentoo", "Generic".

FORCE_ALL_THREADS="true"  # options are "true", "false"

MENUNCONFIG="false"  # keep "false", for non interactive installation

CPUSCHED="pds"  # Options are "pds", "bmq", "cacule", "tt", "bore", "bore-eevdf", "echo", "cfs" (linux 6.5-) or "eevdf"

COMPILER="gcc"  # this script just suports "gcc"

# CPU sched_yield_type - Choose what sort of yield sched_yield will perform
# For PDS and MuQSS: 0: No yield. (Recommended option for gaming on PDS and MuQSS)
#                    1: Yield only to better priority/deadline tasks. (Default - can be unstable with PDS on some platforms)
#                    2: Expire timeslice and recalculate deadline. (Usually the slowest option for PDS and MuQSS, not recommended)
# For BMQ:           0: No yield.
#                    1: Deboost and requeue task. (Default)
#                    2: Set rq skip task.
SCHED_YIELD_TYPE="0"

RR_INTERVAL="1"  # Set to "1" for 2ms, "2" for 4ms, "3" for 6ms, "4" for 8ms, or "default" to keep the chosen scheduler defaults.

TICKLESS="1"  # Set to "0" for periodic ticks, "1" to use CattaRappa mode (enabling full tickless) and "2" for tickless idle only.

ACS_OVERRIDE="false"  # options are "true", "false"

# AMD CPUs : "k8" "k8sse3" "k10" "barcelona" "bobcat" "jaguar" "bulldozer" "piledriver" "steamroller" "excavator" "zen" "zen2" "zen3" "zen4" "zen5" (zen3 opt support depends on GCC11) (zen4 opt support depends on GCC13)
#(zen5 opt support depends on GCC14 or CLANG 19.1)
# Intel CPUs : "mpsc"(P4 & older Netburst based Xeon) "atom" "core2" "nehalem" "westmere" "silvermont" "sandybridge" "ivybridge" "haswell" "broadwell" "skylake" "skylakex" "cannonlake" "icelake" "goldmont" "goldmontplus"
#"cascadelake" "cooperlake" "tigerlake" "sapphirerapids" "rocketlake" "alderlake" "raptorlake" "meteorlake" (raptorlake and meteorlake opt support require GCC13)
# Other options :
# - "native_amd" (use compiler autodetection - Selecting your arch manually in the list above is recommended instead of this option)
# - "native_intel" (use compiler autodetection - Selecting your arch manually in the list above is recommended instead of this option)
# - "generic" (kernel's default - to share the package between machines with different CPU µarch as long as they are x86-64)
PROCESSOR_OPT="generic"

# Timer frequency - "100" "250" "300" "500" "750" "1000" ("2000" is available for cacule cpusched only, "625" is available for echo cpusched only)
# More options available in kernel config prompt when left empty depending on selected cpusched with the default option pointed with a ">" (2000 for cacule, 100 for muqss, 625 for echo and 1000 for other cpu schedulers)
TIMER_FREQ="1000"

DEFAULT_CPU_GOV="performance"  # # Default CPU governor - "performance", "ondemand", "schedutil" or leave empty for default (schedutil)

# Set to "true" to enable Binder modules to use Waydroid Android containers
# !!! Not available on Project C schedulers (PDS & BMQ) due to disabled PSI on those !!!
WAYDROID="false"

# compiler optimization level - 1. Optimize for performance (-O2); 2. Optimize harder (-O3); 3. Optimize for size (-Os) - Kernel default is "1"
COMPILER_OPTLEVEL="2"

# TT only - Enable High HZ patch (available for 5.15 only) - Default is "false"
TT_HIGH_HZ="true"

# Use an aggressive ondemand governor instead of default ondemand to improve performance on low loads/high core count CPUs while keeping some power efficiency from frequency scaling.
# It still requires you to either set ondemand as default governor or to select it in some way at runtime.
AGGRESSIVE_ONDEMAND="false"

# [Advanced] Default TCP IPv4 algorithm to use. Options are: "yeah", "bbr", "cubic", "reno", "vegas" and "westwood". Leave empty if unsure.
# This config option will not be prompted
# Can be changed at runtime with the command line `# echo "$name" > /proc/sys/net/ipv4/tcp_congestion_control` where $name is one of the options above.
# Default (empty) and fallback : cubic
TCP_CONG_ALG="bbr"

# You can pass a default set of kernel command line options here - example: "intel_pstate=passive nowatchdog amdgpu.ppfeaturemask=0xfffd7fff mitigations=off"
CUSTOM_COMMANDLINE=""

# Set to "true" to enable support for futex2, a DEPRECATED interface that can be used by proton-tkg and proton 5.13 experimental through Fsync - Can be enabled alongside fsync legacy to use it as a fallback
# https://gitlab.collabora.com/tonyk/linux/-/tree/futex2-dev
# ! Only affect 5.10-5.14 kernel branches. Safely ignored for 5.15 or newer !
# ! required _fsync_backport="false" !
FSYNC_FUTEX2="true"

FSYNC_BACKPORT="true"
FSYNC_LEGACY="true"

# Choice between Stable and Mainline
KERNEL_TYPE="stable"  # Set to "stable" for the latest stable version or "mainline" for the latest mainline version

# Function to get the latest Mainline version from kernel.org
get_latest_mainline_version() {
    curl -s https://www.kernel.org/releases.json | jq -r '.releases[] | select(.moniker=="mainline") | .version' | head -n 1
}

# Function to get the latest Stable version from kernel.org
get_latest_stable_version() {
    curl -s https://www.kernel.org/releases.json | jq -r '.releases[] | select(.moniker=="stable") | .version' | head -n 1
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
    sed -i "s/^_waydroid=.*/_waydroid=\"$WAYDROID\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_compileroptlevel=.*/_compileroptlevel=\"$COMPILER_OPTLEVEL\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_tt_high_hz=.*/_tt_high_hz=\"$TT_HIGH_HZ\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_aggressive_ondemand=.*/_aggressive_ondemand=\"$AGGRESSIVE_ONDEMAND\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_tcp_cong_alg=.*/_tcp_cong_alg=\"$TCP_CONG_ALG\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_custom_commandline=.*/_custom_commandline=\"$CUSTOM_COMMANDLINE\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_fsync_futex2=.*/_fsync_futex2=\"$FSYNC_FUTEX2\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_fsync_backport=.*/_fsync_backport=\"$FSYNC_BACKPORT\"/" $CUSTOMIZATION_CFG
    sed -i "s/^_fsync_legacy=.*/_fsync_legacy=\"$FSYNC_LEGACY\"/" $CUSTOMIZATION_CFG

    # Change to TKG kernel directory
    cd $TKG_KERNEL_DIR

    # Compile kernel (don't install)
    nice -n 19 makepkg -s

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
