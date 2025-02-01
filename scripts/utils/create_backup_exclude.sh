#!/bin/bash

cat > /etc/nafo_backup_exclude.conf << 'EOL'
/proc/*
/sys/*
/dev/*
/run/*
/tmp/*
/var/tmp/*
/var/cache/*
/var/run/*
/media/*
/mnt/*
*.log
*.pid
*.sock
EOL 