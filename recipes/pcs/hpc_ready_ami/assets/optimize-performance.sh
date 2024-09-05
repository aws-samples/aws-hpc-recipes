#!/usr/bin/env bash

# This script applies performance optimizations to AMIs from 
# operating systems supported by AWS PCS.

set -o errexit -o pipefail -o nounset

OS=""
VERSION=""

# Function to log
logger() {
   local script="$0";
   local log_message="$1";
   local log_level="${2:-INFO}";
   local timestamp=$(date +"%Y-%m-%dT%H:%M:%S.%3N%:z");
   echo "[$timestamp] - $script: $log_level: $log_message";
}

handle_ubuntu_22.04() {
    logger "Updating Ubuntu 22.04" "INFO"
}

handle_rhel_9() { 
    logger "Updating RHEL 9" "INFO"
}

handle_rocky_9() {
    logger "Updating Rocky Linux 9" "INFO"
}

handle_amzn_2() {
    logger "Updating Amazon Linux 2" "INFO"
}

detect_os_version() {

    # Detect the operating system
    if [ -f /etc/os-release ]; then
        # Read the contents of the /etc/os-release file
        # shellcheck disable=SC1091
        . /etc/os-release
        # Extract the operating system ID and version
        OS=$ID
        VERSION=$VERSION_ID
    else
        logger "Unable to detect the operating system." "ERROR"
        exit 1
    fi

    # Verify if the OS is supported
    case "$OS" in
        ubuntu)
            if [ "$VERSION" == "22.04" ]; then
                logger "Detected Ubuntu 22.04"
            else
                logger "Unsupported Ubuntu version: $VERSION" "ERROR"
                exit 1
            fi
            ;;
        rhel)
            if [[ "$VERSION" =~ ^9\.* ]]; then
                logger "Detected RHEL 9"
                VERSION=9
            else
                logger "Unsupported RHEL version: $VERSION" "ERROR" "ERROR"
                exit 1
            fi
            ;;
        rocky)
            if [[ "$VERSION" =~ ^9\.* ]]; then
                logger "Detected Rocky Linux 9"
                VERSION=9
            else
                logger "Unsupported Rocky Linux version: $VERSION" "ERROR"
                exit 1
            fi
            ;;
        amzn)
            if [ "$VERSION" == "2" ]; then
                logger "Detected Amazon Linux 2"
            else
                logger "Unsupported Amazon Linux version: $VERSION" "ERROR"
                exit 1
            fi
            ;;
        *)
            logger "Unsupported operating system: $OS" "ERROR"
            exit 1
            ;;
    esac

}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
