#!/bin/bash
# Main installation orchestrator script

# Source common functions and variables
source "$(dirname "$0")/common/utils.sh"

# Installation sequence
check_root
create_progress_file
install_base_system
setup_raid_array
configure_network
install_software_packages
setup_directory_structure
configure_services
setup_security
initialize_databases
download_offline_content

log_message "NAFO Radio installation complete!" 