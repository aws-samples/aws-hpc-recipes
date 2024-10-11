#!/usr/bin/env bash

# This script applies generalized performance optimizations
# AMIs built for AWS PCS. It should be run after core system 
# packages are upgradded or installed.

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

disable_select_cron_tasks() {

# Disable cron job tasks man-db and mlocate, which may have a negative impact on node performance. 1496 and 1494
# Ref: https://github.com/aws/aws-parallelcluster-cookbook/pull/1496
# Ref https://github.com/aws/aws-parallelcluster-cookbook/pull/1494

    logger "Disabling select cron tasks" "INFO"

    if [ -d "/etc/cron.daily" ]; then
        for task in man-db man-db.cron mlocate; do
            if [ ! -f "/etc/cron.daily/jobs.deny" ] || ! grep -qxF "$task" "/etc/cron.daily/jobs.deny"; then
               echo "$task" | sudo tee -a "/etc/cron.daily/jobs.deny" > /dev/null
            fi
        done
    fi
    if [ -d "/etc/cron.weekly" ]; then
        for task in man-db; do
            if [ ! -f "/etc/cron.weekly/jobs.deny" ] || ! grep -qxF "$task" "/etc/cron.weekly/jobs.deny"; then
                echo "$task" | sudo tee -a "/etc/cron.weekly/jobs.deny" > /dev/null
            fi
        done
    fi
}

disable_deeper_cstates() {

# Disable deeper C-States in x86_64 official AMIs and AMIs created through build-image command, to guarantee high performance and low latency. - 1386
# Ref: https://github.com/aws/aws-parallelcluster-cookbook/pull/1386

    if [ "${ARCHITECTURE}" == "x86_64" ]; then

        logger "Disabling deeper C-States" "INFO"

        # See https://github.com/aws/aws-parallelcluster-cookbook/commit/1f5911817d10b9ca00a706c94d50ef5e756b81e7
        case "${OS}-${VERSION}" in
            r*-9 )
                sudo grubby --update-kernel=ALL --args="intel_idle.max_cstate=1 processor.max_cstate=1"
                ;;
            ubuntu* )
                sudo sed -i '/^GRUB_CMDLINE_LINUX=".*"$/s/"$/ intel_idle.max_cstate=0 processor.max_cstate=1"/' /etc/default/grub
                sudo /usr/sbin/update-grub
                ;;
            *)
                sudo sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=".*"$/s/"$/ intel_idle.max_cstate=0 processor.max_cstate=1"/' /etc/default/grub
                sudo /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
                ;;
        esac
    else
        logger "Non x86 architecture detected, skipping C-States optimization" "INFO"
    fi

}

custom_sysctl_settings() {

# Configure the following default gc_thresh values for performance at scale.
# - net.ipv4.neigh.default.gc_thresh1 = 0
# - net.ipv4.neigh.default.gc_thresh2 = 15360
# - net.ipv4.neigh.default.gc_thresh3 = 16384
# Ref: https://github.com/aws/aws-parallelcluster-cookbook/pull/1004

    # Define the sysctl values
    declare -A sysctl_values=(
        ["net.ipv4.neigh.default.gc_thresh1"]="0"
        ["net.ipv4.neigh.default.gc_thresh2"]="15360"
        ["net.ipv4.neigh.default.gc_thresh3"]="16384"
    )

    set_sysctl_values() {
        for key in "${!sysctl_values[@]}"; do
            echo "$key = ${sysctl_values[$key]}" | sudo tee -a "$1"
        done
    }

    CONFIG_FILE="/etc/sysctl.d/99-hpc-ready-ami.conf"
    sudo touch "$CONFIG_FILE"
    sudo truncate -s 0 "$CONFIG_FILE"
    set_sysctl_values "$CONFIG_FILE"

    # Apply the changes
    sudo sysctl -p "$CONFIG_FILE"

}

handle_ubuntu_22.04() {
    logger "Optimizing Ubuntu 22.04" "INFO"
    disable_select_cron_tasks
    disable_deeper_cstates
    custom_sysctl_settings
}

handle_rhel_9() { 
    logger "Optimizing RHEL 9" "INFO"
    disable_select_cron_tasks
    disable_deeper_cstates
    custom_sysctl_settings
}

handle_rocky_9() {
    logger "Optimizing Rocky Linux 9" "INFO"
    disable_select_cron_tasks
    disable_deeper_cstates
    custom_sysctl_settings
}

handle_amzn_2() {
    logger "Optimizing Amazon Linux 2" "INFO"
    disable_select_cron_tasks
    disable_deeper_cstates
    custom_sysctl_settings
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
