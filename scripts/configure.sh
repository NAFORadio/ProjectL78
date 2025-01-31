#!/bin/bash

# NAFO Radio Configuration Script
# This script handles post-installation configuration

source $(dirname "$0")/setup.sh

# Function to configure firewall
configure_firewall() {
    log_message "Configuring firewall..."
    
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw enable
    
    log_message "${GREEN}Firewall configured.${NC}"
}

# Function to setup backup jobs
setup_backups() {
    log_message "Setting up automated backups..."
    
    # Create backup script
    cat > /usr/local/bin/nafo_backup.sh << 'EOF'
#!/bin/bash
borg create /storage/backups/daily::$(date +%Y-%m-%d) /storage/library
borg prune -d 7 -w 4 -m 2 /storage/backups/daily
EOF
    
    chmod +x /usr/local/bin/nafo_backup.sh
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/nafo_backup.sh") | crontab -
    
    log_message "${GREEN}Backup configuration complete.${NC}"
}

# Main configuration function
main() {
    check_root
    
    log_message "Starting NAFO Radio configuration..."
    
    configure_firewall
    setup_backups
    
    log_message "${GREEN}NAFO Radio configuration complete!${NC}"
}

# Run main configuration
main "$@" 