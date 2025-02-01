#!/bin/bash

# Add hourly backup job
echo "0 * * * * root /usr/local/bin/backup_system.sh" > /etc/cron.d/nafo_backup

# Copy scripts to system location
cp backup_system.sh /usr/local/bin/
cp recover_system.sh /usr/local/bin/

# Make scripts executable
chmod +x /usr/local/bin/backup_system.sh
chmod +x /usr/local/bin/recover_system.sh 