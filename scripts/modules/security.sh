#!/bin/bash
# Security configuration module

source "$(dirname "$0")/../common/utils.sh"

setup_security() {
    log_message "Configuring system security..."
    
    # Install security packages
    apt-get install -y \
        fail2ban \
        ufw \
        rkhunter \
        lynis \
        aide \
        auditd
    
    # Configure firewall
    configure_firewall
    
    # Setup fail2ban
    configure_fail2ban
    
    # Configure SSH hardening
    harden_ssh
    
    # Setup system auditing
    configure_audit
    
    # Initialize AIDE database
    initialize_aide
    
    log_message "${GREEN}Security configuration complete${NC}"
}

configure_firewall() {
    log_message "Setting up firewall..."
    
    # Reset UFW
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (rate limited)
    ufw limit 22/tcp
    
    # Allow web interface
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Enable firewall
    ufw --force enable
}

configure_fail2ban() {
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
EOF

    systemctl restart fail2ban
}

harden_ssh() {
    cat > /etc/ssh/sshd_config << EOF
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers nafo_admin
EOF

    systemctl restart sshd
}

configure_audit() {
    cat > /etc/audit/rules.d/audit.rules << EOF
# Delete all existing rules
-D

# Buffer Size
-b 8192

# Failure Mode
-f 1

# Monitor sudo usage
-w /etc/sudoers -p wa -k sudo_changes
-w /etc/sudoers.d/ -p wa -k sudo_changes

# Monitor SSH keys
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /root/.ssh -p wa -k root_ssh
EOF

    systemctl restart auditd
}

initialize_aide() {
    # Initialize AIDE database
    aideinit
    
    # Setup daily integrity check
    cat > /etc/cron.daily/aide-check << EOF
#!/bin/bash
/usr/bin/aide --check | mail -s "AIDE Integrity Check" root
EOF
    
    chmod +x /etc/cron.daily/aide-check
} 