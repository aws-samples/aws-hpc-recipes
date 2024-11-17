#!/usr/bin/env bash

# This script downgrades the kernel, usually 
# to bring an OS image into readiness for use 
# with Lustre and/or EFA drivers.
#
# It should be followed by an explicit, managed reboot 
# before installing additional software. 

set -o errexit -o pipefail -o nounset

# Find the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Search for common.sh in the current directory and parent directory
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
    . "${SCRIPT_DIR}/common.sh"
elif [ -f "${SCRIPT_DIR}/../common.sh" ]; then
    . "${SCRIPT_DIR}/../common.sh"
else
    echo "Error: common.sh not found!" >&2
    exit 1
fi

handle_ubuntu_22.04() {
    logger "Updating Ubuntu 22.04" "INFO"
    # 6.5.0-1024-aws is latest suppported by Lustre as of 2024.11.01
    # See https://docs.aws.amazon.com/fsx/latest/LustreGuide/lustre-client-matrix.html for details
    KERNEL_VERSION="6.5.0-1024-aws"
    # Remove the meta packages first
    sudo apt remove -y linux-aws linux-image-aws linux-headers-aws || true
    # Clean up any automatically installed packages no longer needed
    sudo apt autoremove -y
    # Install specific kernel version
    sudo apt update
    sudo apt install -y linux-image-${KERNEL_VERSION} linux-headers-${KERNEL_VERSION}
    # Update GRUB default
    sudo sed -i 's/^GRUB_DEFAULT=.*$/GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux '"${KERNEL_VERSION}"'"/' /etc/default/grub
    # Update GRUB
    sudo update-grub
    # Remove 6.8x kernel
    sudo dpkg -l | grep linux | grep aws | grep "6.8" | awk '{print $2}' | xargs apt remove -y || true

    # Hold kernel packages to prevent updates
    sudo apt-mark hold linux-image-${KERNEL_VERSION} linux-headers-${KERNEL_VERSION}

# Create apt preferences to pin kernel version
sudo cat > /etc/apt/preferences.d/kernel-pin << EOF
Package: linux-image-*
Pin: version 6.5.0*
Pin-Priority: 1001

Package: linux-headers-*
Pin: version 6.5.0*
Pin-Priority: 1001

Package: linux-*aws*
Pin: version 6.5.0*
Pin-Priority: 1001
EOF

}

handle_rhel_9() { 
    logger "Updating RHEL 9" "INFO"
    # No need to do this as of 2024.11.17
}

handle_rocky_9() {
    logger "Updating Rocky Linux 9" "INFO"
    # No need to do this as of 2024.11.17
}

handle_amzn_2() {
    logger "Updating Amazon Linux 2" "INFO"
    # No need to do this as of 2024.11.17
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
