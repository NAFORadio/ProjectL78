#!/bin/bash
# Radio configuration module for SDR and HAM radio

source "$(dirname "$0")/../common/utils.sh"

setup_radio() {
    log_message "Setting up radio systems..."
    
    # Install radio packages
    install_radio_packages
    
    # Configure SDR
    setup_sdr
    
    # Configure HAM radio
    setup_ham_radio
    
    # Setup emergency frequencies monitoring
    setup_emergency_monitoring
    
    # Configure LoRa
    setup_lora
    
    log_message "${GREEN}Radio setup complete${NC}"
}

install_radio_packages() {
    apt-get install -y \
        gqrx-sdr \
        rtl-433 \
        dump1090-mutability \
        direwolf \
        wsjtx \
        fldigi \
        multimon-ng
}

setup_sdr() {
    # Create RTL-SDR rules
    cat > /etc/udev/rules.d/20-rtlsdr.rules << EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", GROUP="nafo_admin", MODE="0666"
EOF
    
    # Create automated recording script
    cat > /usr/local/bin/record_frequencies.sh << 'EOF'
#!/bin/bash
FREQS=(
    "162.400" # NOAA Weather
    "121.500" # Aviation Emergency
    "156.800" # Marine Emergency
)

for freq in "${FREQS[@]}"; do
    rtl_fm -f ${freq}M -s 48k | sox -t raw -r 48k -e signed -b 16 -c 1 - \
        "/storage/radio/recordings/freq_${freq}_$(date +%Y%m%d_%H%M).wav"
done
EOF
    
    chmod +x /usr/local/bin/record_frequencies.sh
}

setup_ham_radio() {
    # Configure Direwolf for APRS
    cat > /etc/direwolf.conf << EOF
ADEVICE plughw:1,0
CHANNEL 0
MYCALL NAFO01
MODEM 1200
TXDELAY 30
DWAIT 10
EOF
    
    # Create systemd service for Direwolf
    cat > /etc/systemd/system/direwolf.service << EOF
[Unit]
Description=Direwolf APRS Decoder
After=sound.target

[Service]
ExecStart=/usr/bin/direwolf -t 0
WorkingDirectory=/storage/radio/aprs
User=nafo_admin
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable direwolf
}

setup_emergency_monitoring() {
    # Create emergency frequency scanner service
    cat > /usr/local/bin/emergency_scanner.py << 'EOF'
#!/usr/bin/env python3
import subprocess
import time
import os

EMERGENCY_FREQS = {
    'NOAA': 162.400,
    'AVIATION': 121.500,
    'MARINE': 156.800
}

def scan_frequency(freq, duration=60):
    output_file = f"/storage/radio/emergency/scan_{freq}_{time.strftime('%Y%m%d_%H%M')}.wav"
    subprocess.run([
        'rtl_fm',
        '-f', f'{freq}M',
        '-s', '48k',
        '-g', '50',
        '-l', '0',
        '-E', 'deemp',
        '-E', 'wav',
        output_file
    ])

def main():
    while True:
        for name, freq in EMERGENCY_FREQS.items():
            scan_frequency(freq)
        time.sleep(300)  # Wait 5 minutes between scans

if __name__ == '__main__':
    main()
EOF

    chmod +x /usr/local/bin/emergency_scanner.py
}

setup_lora() {
    # Install LoRa dependencies
    apt-get install -y \
        python3-pip \
        python3-dev
    
    pip3 install \
        RPi.GPIO \
        spidev \
        pyLoRa
    
    # Enable SPI interface
    raspi-config nonint do_spi 0
    
    # Create LoRa service
    cat > /usr/local/bin/lora_node.py << 'EOF'
#!/usr/bin/env python3
from time import sleep
from SX127x.LoRa import *
from SX127x.board_config import BOARD

BOARD.setup()

class LoRaNode(LoRa):
    def __init__(self, verbose=False):
        super(LoRaNode, self).__init__(verbose)
        self.set_mode(MODE.SLEEP)
        self.set_freq(915.0)  # Set frequency to 915MHz

    def on_rx_done(self):
        payload = self.read_payload(nocheck=True)
        print(f"Received: {''.join([chr(c) for c in payload])}")
        self.clear_irq_flags(RxDone=1)
        self.reset_ptr_rx()
        self.set_mode(MODE.RXCONT)

def main():
    node = LoRaNode(verbose=True)
    node.set_mode(MODE.RXCONT)
    while True:
        sleep(1)

if __name__ == '__main__':
    main()
EOF

    chmod +x /usr/local/bin/lora_node.py
} 