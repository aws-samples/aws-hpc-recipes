#!/usr/bin/env bash

# Usage: pcs_bootstrap_always.sh /etc/amazon/pcs/bootstrap_config.json
#
# This is the second script called by PCS automated bootstrapping.  Currently, it does nothing.

BOOTSTRAP_CONFIG_FILE=$1
REGISTER_NODE_GROUP_INSTANCE_FILE="/etc/amazon/pcs/register_node_group_instance.json"

# Load commomn functions
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

# Currently does nothing.

completed
