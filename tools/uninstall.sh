#!/bin/bash

#----------------------------------------------------------#
#                    Variables                               #
#----------------------------------------------------------#

KISSPANEL_DIR="/usr/local/kisspanel"
PANEL_USER="kisspanel"
PANEL_GROUP="kisspanel"

#----------------------------------------------------------#
#                    Functions                               #
#----------------------------------------------------------#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo -e "${GREEN}[$(date +%Y-%m-%d\ %H:%M:%S)]${NC} $1"
}

# Warning logging function
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Error logging function
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Confirm uninstallation
confirm_uninstall() {
    echo -e "${RED}WARNING: This will remove KissPanel and all associated components${NC}"
    echo "This includes:"
    echo "- All panel files and configurations"
    echo "- Panel database"
    echo "- Panel user and group"
    echo "- Installed services (optional)"
    echo
    read -p "Are you sure you want to continue? (y/n): " answer
    if [[ "$answer" != "y" ]]; then
        echo "Uninstallation cancelled"
        exit 0
    fi
}

# Stop services
stop_services() {
    log "Stopping services..."
    
    local services=(
        "nginx"
        "php-fpm"
        "mariadb"
        "mysqld"
        "postgresql"
        "named"
        "bind9"
        "exim"
        "exim4"
        "dovecot"
        "vsftpd"
        "proftpd"
        "fail2ban"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service"
            systemctl disable "$service"
            log "Stopped and disabled $service"
        fi
    done
}

# Remove panel files
remove_panel_files() {
    log "Removing panel files..."
    
    # Remove main directory
    if [ -d "$KISSPANEL_DIR" ]; then
        rm -rf "$KISSPANEL_DIR"
        log "Removed $KISSPANEL_DIR"
    fi
    
    # Remove configuration files
    rm -f /etc/nginx/conf.d/panel.conf
    rm -f /etc/php-fpm.d/panel.conf
    rm -f /etc/cron.d/kisspanel
    rm -f /etc/fail2ban/jail.d/kisspanel.conf
}

# Remove panel user and group
remove_panel_user() {
    log "Removing panel user and group..."
    
    if id "$PANEL_USER" >/dev/null 2>&1; then
        userdel "$PANEL_USER"
        log "Removed user $PANEL_USER"
    fi
    
    if getent group "$PANEL_GROUP" >/dev/null 2>&1; then
        groupdel "$PANEL_GROUP"
        log "Removed group $PANEL_GROUP"
    fi
}

# Remove installed packages
remove_packages() {
    log "Checking for package manager..."
    
    if command -v apt-get >/dev/null 2>&1; then
        # Ubuntu/Debian
        log "Using apt package manager..."
        apt-get -y remove nginx php-fpm mariadb-server postgresql bind9 exim4 dovecot-core vsftpd proftpd fail2ban
        apt-get -y autoremove
        apt-get clean
        
    elif command -v dnf >/dev/null 2>&1; then
        # AlmaLinux/RHEL
        log "Using dnf package manager..."
        dnf -y remove nginx php-fpm mariadb-server postgresql-server bind dovecot exim vsftpd proftpd fail2ban
        dnf -y autoremove
        dnf clean all
    else
        warning "Unknown package manager. Skipping package removal."
    fi
}

# Clean up system files
cleanup_system() {
    log "Cleaning up system files..."
    
    # Remove logs
    rm -f /var/log/kisspanel*
    
    # Remove temp files
    rm -rf /tmp/kisspanel*
    
    # Remove backup files
    rm -rf /backup/kisspanel*
}

#----------------------------------------------------------#
#                    Main Execution                          #
#----------------------------------------------------------#

main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Confirm uninstallation
    confirm_uninstall
    
    # Stop all services
    stop_services
    
    # Remove packages
    read -p "Remove installed packages (nginx, php, etc.)? (y/n): " remove_pkgs
    if [[ "$remove_pkgs" == "y" ]]; then
        remove_packages
    fi
    
    # Remove panel files
    remove_panel_files
    
    # Remove panel user
    remove_panel_user
    
    # Clean up system
    cleanup_system
    
    log "KissPanel has been uninstalled successfully"
    
    if [[ "$remove_pkgs" != "y" ]]; then
        warning "Installed packages were not removed. You may want to remove them manually."
    fi
    
    echo
    echo "Note: Some system changes may still remain. For a complete reset,"
    echo "consider reimaging your server."
}

main "$@"
