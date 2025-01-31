#!/bin/bash
# Network configuration module

source "$(dirname "$0")/../common/utils.sh"

configure_network() {
    log_message "Configuring network..."
    
    # Install networking tools
    apt-get install -y \
        hostapd \
        dnsmasq \
        bridge-utils
    
    # Configure bridge interface
    cat > /etc/netplan/99-bridge.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
  bridges:
    br0:
      interfaces: [eth0]
      dhcp4: yes
EOF
    
    # Apply network configuration
    netplan apply
    
    # Configure hostapd for WiFi AP
    cat > /etc/hostapd/hostapd.conf << EOF
interface=wlan0
bridge=br0
ssid=NAFO_RADIO
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=nafo_secure_password
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
    
    systemctl enable hostapd
    systemctl start hostapd
    
    log_message "${GREEN}Network configuration complete${NC}"
} 