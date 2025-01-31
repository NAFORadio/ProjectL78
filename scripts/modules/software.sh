#!/bin/bash
# Software installation module

source "$(dirname "$0")/../common/utils.sh"

install_software_packages() {
    log_message "Installing software packages..."
    
    # Update system
    apt-get update && apt-get upgrade -y
    
    # Install core packages
    apt-get install -y \
        podman \
        fail2ban \
        ufw \
        nginx \
        python3-pip \
        git \
        vim \
        tmux \
        htop \
        iotop
        
    # Install SDR packages
    apt-get install -y \
        gqrx-sdr \
        rtl-433 \
        dump1090-mutability \
        direwolf
        
    # Install monitoring packages
    apt-get install -y \
        prometheus \
        grafana \
        node-exporter
        
    # Install Python packages
    pip3 install \
        requests \
        pandas \
        numpy \
        matplotlib \
        jupyter
        
    log_message "${GREEN}Software installation complete${NC}"
} 