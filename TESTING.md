# KissPanel Testing Guide

This document outlines the testing procedures for KissPanel installation and configuration.

## Automated Testing

KissPanel provides an automated test suite to verify your installation. This should be your first step in testing a new installation.

### Running the Test Suite

1. Download the test script:
```bash
wget https://raw.githubusercontent.com/kisspanel/kisspanel/main/tools/test-install.sh
chmod +x test-install.sh
```

2. Run the tests:
```bash
./test-install.sh
```

### Test Coverage

The automated test suite verifies:

- Directory Structure
  - Existence of all required directories
  - Proper permissions

- User Management
  - Panel user creation
  - Group creation
  - Proper user permissions

- Core Services
  - Nginx status
  - PHP-FPM status
  - Service configurations

- Configuration Files
  - Presence of all required configs
  - File permissions
  - Basic syntax validation

- Database
  - SQLite database existence
  - Database accessibility
  - Basic query functionality

- Web Access
  - Panel accessibility
  - SSL/TLS configuration
  - Port availability

### Understanding Test Results

Test results are color-coded:
- 🟢 `[PASS]` - Component tested successfully
- 🔴 `[FAIL]` - Component test failed
- 🟡 `[WARN]` - Non-critical issue detected

Example output:
```
Starting KissPanel Installation Tests
======================================
Testing directory structure...
[PASS] Directory exists: /usr/local/kisspanel
[PASS] Directory exists: /usr/local/kisspanel/bin
...
Testing core services...
[PASS] Service running: nginx
[PASS] Service running: php-fpm
...
======================================
All tests passed successfully!
```

## Manual Testing

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

### 2. Basic Installation Test

Run the installer with default settings:

```bash
./kisspanel-install.sh
```

### 3. Advanced Installation Test

Run the installer with specific options:

```bash
./kisspanel-install.sh \
    --port 2006 \
    --hostname panel.yourdomain.com \
    --email admin@yourdomain.com \
    --password "SecurePass123"
```

## Post-Installation Verification

### 1. Directory Structure

Verify the installation created all required directories:

```bash
# Check main directories
ls -la /usr/local/kisspanel/
ls -la /usr/local/kisspanel/conf/
ls -la /usr/local/kisspanel/data/
ls -la /usr/local/kisspanel/logs/
```

### 2. User and Group Creation

Verify the panel user was created correctly:

```bash
# Verify panel user
id kisspanel

# Check user permissions
ls -l /usr/local/kisspanel/data/
```

### 3. Service Status

Check the status of all installed services:

```bash
# Check core services
systemctl status nginx
systemctl status php-fpm
systemctl status kisspanel

# Check optional services (if installed)
systemctl status mariadb
systemctl status named
systemctl status vsftpd
systemctl status fail2ban
```

### 4. Configuration Files

Verify configuration files are present and valid:

```bash
# Check nginx configuration
nginx -t

# Check PHP configuration
php-fpm -t

# Verify config files
ls -la /usr/local/kisspanel/conf/nginx/
ls -la /usr/local/kisspanel/conf/php/
```

### 5. Network and Firewall

Verify network configuration and access:

```bash
# Check listening ports
netstat -tlpn

# Check firewall rules
firewall-cmd --list-all

# Test panel access
curl -Ik https://localhost:2006
```

### 6. Database

Verify database installation and permissions:

```bash
# Check SQLite database
sqlite3 /usr/local/kisspanel/data/kisspanel.db "SELECT sqlite_version();"

# Verify database permissions
ls -l /usr/local/kisspanel/data/kisspanel.db
```

### 7. Log Files

Check installation and service logs:

```bash
# Check installation log
tail -f /usr/local/kisspanel/logs/install.log

# Check nginx access/error logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

## Troubleshooting Guide

### Service Issues

If services fail to start or run properly:

```bash
# Check service status
systemctl status service-name

# View service logs
journalctl -u service-name
```

### Permission Issues

If you encounter permission-related problems:

```bash
# Check file ownership
ls -la /path/to/file

# Verify SELinux context
ls -Z /path/to/file

# Check SELinux status
getenforce
```

### Network Issues

For connectivity problems:

```bash
# Verify port availability
netstat -tlpn

# Check firewall rules
firewall-cmd --list-all

# Test SSL certificates
openssl s_client -connect localhost:2006
```

## Cleanup Procedure

To remove KissPanel for re-testing:

```bash
# Stop services
systemctl stop kisspanel nginx php-fpm

# Remove directories
rm -rf /usr/local/kisspanel

# Remove user and group
userdel kisspanel
groupdel kisspanel

# Remove database
rm -f /usr/local/kisspanel/data/kisspanel.db

# Remove configuration files
rm -f /etc/nginx/conf.d/panel.conf
rm -f /etc/php-fpm.d/panel.conf
```

## Test Results Documentation

For each test iteration, document the following:

1. Installation method used (default/custom)
2. Time taken for installation
3. Any errors or warnings encountered
4. Service status verification results
5. Access verification results
6. Resource usage measurements
7. Issues encountered and resolutions
8. Screenshots of successful installation

## Expected Results

A successful installation should show:

- All services running without errors
- Panel accessible via web browser
- Correct file permissions and ownership
- No SELinux or firewall blocks
- Database accessible and properly configured
- All configuration files in place
- Log files showing normal operation

## Support

If you encounter issues during testing:

1. Check the troubleshooting guide above
2. Review the installation logs
3. Submit an issue on GitHub with:
   - Full error messages
   - System information
   - Installation method used
   - Steps to reproduce the issue
