# KissPanel Testing Guide

This document outlines the testing procedures for KissPanel installation and configuration.

## Pre-Installation Requirements

### System Requirements
- AlmaLinux 8 or 9 (fresh installation)
- Minimum 1GB RAM
- 10GB free disk space
- Active internet connection
- Root access
- Valid hostname configured

### Pre-Installation Checks

Verify your system meets all requirements by running these commands:

```bash
# Check OS version
cat /etc/os-release

# Check memory
free -m

# Check disk space
df -h

# Check hostname configuration
hostname -f

# Check internet connectivity
ping -c 4 github.com
```

## Installation Process

### 1. Download and Prepare Installer

```bash
# Download installer
wget https://raw.githubusercontent.com/kisspanel/kisspanel/main/kisspanel-install.sh

# Make executable
chmod +x kisspanel-install.sh

# Verify installer
bash -n kisspanel-install.sh
```