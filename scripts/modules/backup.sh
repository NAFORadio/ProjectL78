#!/bin/bash
# Backup systems configuration module

source "$(dirname "$0")/../common/utils.sh"

setup_backup_system() {
    log_message "Setting up backup systems..."
    
    # Install backup tools
    install_backup_packages
    
    # Configure BorgBackup
    setup_borg
    
    # Configure database backups
    setup_db_backup
    
    # Setup backup rotation
    setup_backup_rotation
    
    # Configure backup monitoring
    setup_backup_monitoring
    
    log_message "${GREEN}Backup system setup complete${NC}"
}

install_backup_packages() {
    apt-get install -y \
        borgbackup \
        rsync \
        rclone \
        duplicity \
        postgresql-client
}

setup_borg() {
    # Initialize Borg repository
    mkdir -p "${STORAGE_ROOT}/backups/borg"
    
    # Create backup script
    cat > /usr/local/bin/nafo_backup.sh << 'EOF'
#!/bin/bash

# Environment variables for Borg
export BORG_REPO="/storage/backups/borg"
export BORG_PASSPHRASE="secure_passphrase_here"

# Create backup
borg create \
    --verbose \
    --filter AME \
    --list \
    --stats \
    --show-rc \
    --compression lz4 \
    --exclude-caches \
    ::'{hostname}-{now}' \
    /storage/library \
    /storage/sensors \
    /storage/radio \
    /opt/nafo_radio \
    /etc/nafo_radio

# Prune old backups
borg prune \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 6
EOF

    chmod +x /usr/local/bin/nafo_backup.sh
    
    # Create systemd timer for automated backups
    cat > /etc/systemd/system/nafo-backup.timer << EOF
[Unit]
Description=NAFO Radio Daily Backup Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    cat > /etc/systemd/system/nafo-backup.service << EOF
[Unit]
Description=NAFO Radio Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nafo_backup.sh
User=nafo_admin

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable nafo-backup.timer
    systemctl start nafo-backup.timer
}

setup_db_backup() {
    # Create database backup script
    cat > /usr/local/bin/db_backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="${STORAGE_ROOT}/backups/database"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Backup PostgreSQL databases
databases=$(psql -U nafo_admin -l -t | cut -d'|' -f1 | sed -e 's/ //g' -e '/^$/d')

for db in $databases; do
    if [ "$db" != "template0" ] && [ "$db" != "template1" ]; then
        pg_dump -U nafo_admin "$db" | gzip > "${BACKUP_DIR}/${db}_${TIMESTAMP}.sql.gz"
    fi
done

# Backup Redis
redis-cli save
cp /var/lib/redis/dump.rdb "${BACKUP_DIR}/redis_${TIMESTAMP}.rdb"

# Clean old backups (keep last 30 days)
find "$BACKUP_DIR" -type f -mtime +30 -delete
EOF

    chmod +x /usr/local/bin/db_backup.sh
    
    # Create systemd timer for database backups
    cat > /etc/systemd/system/nafo-db-backup.timer << EOF
[Unit]
Description=NAFO Radio Database Backup Timer

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    cat > /etc/systemd/system/nafo-db-backup.service << EOF
[Unit]
Description=NAFO Radio Database Backup Service
After=postgresql.service redis.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/db_backup.sh
User=nafo_admin

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable nafo-db-backup.timer
    systemctl start nafo-db-backup.timer
}

setup_backup_rotation() {
    # Create backup rotation script
    cat > /usr/local/bin/rotate_backups.sh << 'EOF'
#!/bin/bash

# Backup directory structure
BACKUP_ROOT="${STORAGE_ROOT}/backups"
DAILY_DIR="${BACKUP_ROOT}/daily"
WEEKLY_DIR="${BACKUP_ROOT}/weekly"
MONTHLY_DIR="${BACKUP_ROOT}/monthly"

# Create backup directories if they don't exist
mkdir -p "$DAILY_DIR" "$WEEKLY_DIR" "$MONTHLY_DIR"

# Rotate daily backups to weekly (every Sunday)
if [ $(date +%u) -eq 7 ]; then
    latest_daily=$(ls -t "$DAILY_DIR" | head -1)
    if [ ! -z "$latest_daily" ]; then
        cp -al "${DAILY_DIR}/${latest_daily}" "${WEEKLY_DIR}/week_$(date +%Y%m%d)"
    fi
fi

# Rotate weekly backups to monthly (first day of month)
if [ $(date +%d) -eq 01 ]; then
    latest_weekly=$(ls -t "$WEEKLY_DIR" | head -1)
    if [ ! -z "$latest_weekly" ]; then
        cp -al "${WEEKLY_DIR}/${latest_weekly}" "${MONTHLY_DIR}/month_$(date +%Y%m)"
    fi
fi

# Clean up old backups
find "$DAILY_DIR" -type f -mtime +7 -delete
find "$WEEKLY_DIR" -type f -mtime +30 -delete
find "$MONTHLY_DIR" -type f -mtime +365 -delete
EOF

    chmod +x /usr/local/bin/rotate_backups.sh
}

setup_backup_monitoring() {
    # Create backup monitoring script
    cat > /usr/local/bin/monitor_backups.py << 'EOF'
#!/usr/bin/env python3
import os
import time
from datetime import datetime, timedelta
from prometheus_client import start_http_server, Gauge

# Define metrics
backup_age = Gauge('nafo_backup_age_hours', 'Age of latest backup in hours')
backup_size = Gauge('nafo_backup_size_bytes', 'Size of latest backup in bytes')
backup_success = Gauge('nafo_backup_success', 'Success status of last backup')

def check_backups():
    while True:
        try:
            # Check Borg backups
            borg_dir = "/storage/backups/borg"
            if os.path.exists(borg_dir):
                latest_backup = max(
                    (os.path.join(borg_dir, f) for f in os.listdir(borg_dir)),
                    key=os.path.getctime
                )
                age = (time.time() - os.path.getctime(latest_backup)) / 3600
                size = os.path.getsize(latest_backup)
                
                backup_age.set(age)
                backup_size.set(size)
                backup_success.set(1 if age < 24 else 0)
            
        except Exception as e:
            print(f"Error monitoring backups: {e}")
            backup_success.set(0)
        
        time.sleep(300)  # Check every 5 minutes

if __name__ == '__main__':
    start_http_server(9102)
    check_backups()
EOF

    chmod +x /usr/local/bin/monitor_backups.py
    
    # Create systemd service for backup monitoring
    cat > /etc/systemd/system/nafo-backup-monitor.service << EOF
[Unit]
Description=NAFO Radio Backup Monitoring
After=network.target

[Service]
ExecStart=/usr/local/bin/monitor_backups.py
Restart=always
User=nafo_admin

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable nafo-backup-monitor
    systemctl start nafo-backup-monitor
} 