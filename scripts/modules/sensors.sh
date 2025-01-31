#!/bin/bash
# Environmental sensor configuration module

source "$(dirname "$0")/../common/utils.sh"

setup_sensors() {
    log_message "Setting up environmental sensors..."
    
    # Install required packages
    apt-get install -y \
        i2c-tools \
        python3-smbus \
        python3-pip
    
    # Install Python libraries
    pip3 install \
        adafruit-circuitpython-bme280 \
        adafruit-circuitpython-pms5003 \
        adafruit-circuitpython-ads1x15
    
    # Enable I2C interface
    raspi-config nonint do_i2c 0
    
    # Create sensor service
    create_sensor_service
    
    # Setup sensor data collection
    setup_data_collection
    
    log_message "${GREEN}Sensor setup complete${NC}"
}

create_sensor_service() {
    # Create sensor monitoring script
    cat > /usr/local/bin/monitor_sensors.py << 'EOF'
#!/usr/bin/env python3
import time
import board
import busio
import adafruit_bme280
import json
from datetime import datetime

def read_sensors():
    i2c = busio.I2C(board.SCL, board.SDA)
    bme280 = adafruit_bme280.Adafruit_BME280_I2C(i2c)
    
    data = {
        "timestamp": datetime.now().isoformat(),
        "temperature": bme280.temperature,
        "humidity": bme280.humidity,
        "pressure": bme280.pressure
    }
    
    return data

def main():
    while True:
        try:
            data = read_sensors()
            with open('/storage/sensors/environmental.json', 'a') as f:
                json.dump(data, f)
                f.write('\n')
        except Exception as e:
            print(f"Error: {e}")
        
        time.sleep(300)  # 5 minute intervals

if __name__ == "__main__":
    main()
EOF

    chmod +x /usr/local/bin/monitor_sensors.py

    # Create systemd service
    cat > /etc/systemd/system/nafo-sensors.service << EOF
[Unit]
Description=NAFO Radio Environmental Sensors
After=network.target

[Service]
ExecStart=/usr/local/bin/monitor_sensors.py
Restart=always
User=nafo_admin

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable nafo-sensors
    systemctl start nafo-sensors
}

setup_data_collection() {
    # Create data directories
    mkdir -p "${STORAGE_ROOT}/sensors"/{air_quality,water_quality,soil_data}
    
    # Set up data rotation
    cat > /etc/logrotate.d/nafo-sensors << EOF
/storage/sensors/environmental.json {
    daily
    rotate 30
    compress
    missingok
    notifempty
}
EOF
} 