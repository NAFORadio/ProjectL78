# NAFO Radio - Off-Grid Emergency Communications System and Suvival Database

<p align="center">
  <img src="docs/assets/nafo-radio-logo.png" alt="NAFO Radio Logo" width="200"/>
</p>

## 🚨 Project Status: In Development
**NOTE: ALL DETAILS SUBJECT TO CHANGE BASED ON FIELD TESTS!**

NAFO Radio is a comprehensive off-grid emergency communications and monitoring system built for long-term survival scenarios. Every component is designed with solar power capability, redundancy, and offline operation in mind.

## 🎯 Core Features

- **📡 SDR Signal Monitoring & Analysis**
  - Wide-spectrum radio monitoring
  - Aircraft tracking (ADS-B)
  - Weather station data collection
  - Emergency frequency scanning

- **🔐 Security & Surveillance**
  - Solar-powered camera network
  - Night vision capability
  - Motion detection & alerts
  - Secure local storage

- **🌐 Off-Grid Communications**
  - HAM radio integration
  - LoRa mesh networking
  - APRS packet radio
  - Emergency broadcasting

- **🗺️ Navigation & Mapping**
  - Offline map storage
  - GPS tracking
  - Route planning
  - Area monitoring

## 🛠️ Hardware Requirements

### Main Control & Storage Server
- Raspberry Pi 5 (8GB RAM)
- 2x 1TB NVMe SSD (RAID 1)
- NVMe PCIe HAT
- USB 3.0 External SSD Dock (optional)

### SDR Monitoring Station
- Raspberry Pi 5 (4GB RAM)
- Nooelec NESDR SMArTee XTR
- RTL-SDR Blog V4 USB
- Nooelec Ham It Up Upconverter
- Discone Antenna
- USB GPS Receiver (u-blox 9)

### Emergency Communications
- Raspberry Pi 5 (4GB RAM)
- Baofeng UV-5R / Yaesu FT-60R
- SignaLink USB
- LILYGO TTGO LoRa32 V2.1
- RAK2245 Pi HAT

[View complete hardware list](docs/HARDWARE.md)

## 📦 Software Stack

### Core System
- Debian 12 (Raspberry Pi OS 64-bit)
- Docker & Portainer
- RAID 1 Configuration

### Radio & SDR
- Gqrx
- CubicSDR
- Dump1090
- rtl_433
- Direwolf

[View complete software list](docs/SOFTWARE.md)

## ⚡ Power Management

The system is designed for complete off-grid operation using:
- Renogy 100W Solar Panel Kit
- LiFePO4 12V 100Ah Battery
- MPPT Solar Charge Controller
- DC-DC Step-Down Converters

## 🚀 Getting Started

1. [Hardware Assembly Guide](docs/ASSEMBLY.md)
2. [Software Installation](docs/INSTALLATION.md)
3. [Configuration Guide](docs/CONFIGURATION.md)
4. [Operation Manual](docs/OPERATION.md)

## 📝 Documentation

- [System Architecture](docs/ARCHITECTURE.md)
- [Network Setup](docs/NETWORK.md)
- [Security Guidelines](docs/SECURITY.md)
- [Maintenance Procedures](docs/MAINTENANCE.md)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This system is designed for emergency and survival scenarios. Please ensure compliance with all local laws and regulations regarding radio communications and surveillance equipment.

## 🙏 Acknowledgments

Special thanks to the NAFO community and all contributors who have helped make this project possible.

---

<p align="center">
Made with ❤️ by the NAFO Radio Team
</p>

## Overview
NAFO Radio Project is a collection of scripts and tools for knowledge preservation and offline content management. This project focuses on maintaining critical information and content accessibility in austere environments.

## Components

### 1. Primitive Technology Downloader (Added 2024-02-01)
A tool from the Knowledge Acquisition Department for archiving primitive technology educational content.
- Downloads and organizes videos
- Creates searchable indexes
- Generates thumbnails
- Cross-platform support (Linux, macOS, Windows)
- Matrix-themed interface
- Offline-first design

### 2. File Management
- `mac_shorten_names.sh`: Creates MS-DOS compatible filenames
- `scrape_ups_manual.sh`: UPS manual archival tool

### 3. System Management
- `sensors.sh`: Environmental monitoring
- `software.sh`: Package management
- `raid.sh`: Storage redundancy
- `security.sh`: System hardening

## Installation 