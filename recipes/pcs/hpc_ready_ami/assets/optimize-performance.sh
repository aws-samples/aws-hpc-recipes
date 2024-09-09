#!/usr/bin/env bash

# This script applies performance optimizations to AMIs from 
# operating systems supported by AWS PCS.  Run it at the 
# end of an AMI build pipeline.

set -o errexit -o pipefail -o nounset

if [ -f "common.sh" ]; then . common.sh; fi

handle_ubuntu_22.04() {
    logger "Optimizing Ubuntu 22.04" "INFO"
}

handle_rhel_9() { 
    logger "Optimizing RHEL 9" "INFO"
}

handle_rocky_9() {
    logger "Optimizing Rocky Linux 9" "INFO"
}

handle_amzn_2() {
    logger "Optimizing Amazon Linux 2" "INFO"
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
