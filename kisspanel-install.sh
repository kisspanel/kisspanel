#!/bin/bash

#----------------------------------------------------------#
#                    KissPanel Installer                     #
#----------------------------------------------------------#

# Version: 0.1.0
# Build Date: 2024-11-24 22:18:27
# Website: https://kisspanel.org
# GitHub: https://github.com/kisspanel/kisspanel


# common functions
#!/bin/bash

#----------------------------------------------------------#
#                    Common Functions                        #
#----------------------------------------------------------#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +%Y-%m-%d\ %H:%M:%S)]${NC} $1"
}

# Error logging function
error() {
    echo -e "${RED}[ERROR][$(date +%Y-%m-%d\ %H:%M:%S)]${NC} $1"
    exit 1
}

# Warning logging function
warning() {
    echo -e "${YELLOW}[WARNING][$(date +%Y-%m-%d\ %H:%M:%S)]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

# Detect and validate OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=${VERSION_ID%.*}  # This will convert "8.10" to "8"
        
        case $OS in
            ubuntu)
                [[ ! "$VERSION_ID" =~ ^(18.04|20.04|22.04|24.04)$ ]] && \
                    error "Unsupported Ubuntu version: $VERSION_ID"
                ;;
            almalinux)
                [[ ! "$VERSION_ID" =~ ^(8|9)$ ]] && \
                    error "Unsupported AlmaLinux version: $VERSION_ID"
                ;;
            *)
                error "Unsupported operating system: $OS. Currently supporting: Ubuntu, AlmaLinux"
                ;;
        esac
        
        log "Detected OS: $OS $VERSION_ID"
    else
        error "Cannot determine OS version"
    fi
}

# Check if required ports are available
check_ports() {
    log "Checking required ports..."
    local ports=(80 443 $PORT 25 110 143 993 995)
    
    for port in "${ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            error "Port $port is already in use"
        fi
    done
}

# Install basic dependencies
install_dependencies() {
    log "Installing basic dependencies..."
    
    case $OS in
        ubuntu|debian)
            $PACKAGE_UPDATE
            install_locale
            $PACKAGE_INSTALL curl wget tar unzip git lsof rsync
            ;;
        almalinux|rocky)
            $PACKAGE_UPDATE
            install_locale
            $PACKAGE_INSTALL curl wget tar unzip git lsof rsync
            ;;
        *)
            error "Unsupported OS for dependency installation"
            ;;
    esac
}

# Check system memory
check_memory() {
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ $total_mem -lt 1024 ]; then
        warning "Only ${total_mem}MB RAM detected. Minimum recommended is 1024MB"
    fi
}

# Check disk space
check_disk_space() {
    local free_space=$(df -m / | awk 'NR==2 {print $4}')
    if [ $free_space -lt 10240 ]; then
        warning "Less than 10GB of free disk space. This might not be sufficient."
    fi
}

# Check CPU cores
check_cpu() {
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 2 ]; then
        warning "Only ${cpu_cores} CPU core(s) detected. Minimum recommended is 2 cores"
    fi
}

# Check if port is available
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        error "Port $port is already in use"
    fi
}

# Validate email address
validate_email() {
    local email=$1
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        error "Invalid email address format"
    fi
}

# Generate random password
generate_password() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9!#$%&*+-=?@^_' < /dev/urandom | head -c "$length"
}

# Backup existing configuration
backup_config() {
    local file=$1
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Download configuration files
download_configs() {
    log "Downloading configuration files..."
    
    local tmp_dir=$(mktemp -d)
    local config_version="0.1.3"
    local config_url="https://github.com/kisspanel/kisspanel/archive/refs/tags/v${config_version}.tar.gz"
    
    log "Downloading from: $config_url"
    if ! curl -sSL "$config_url" -o "$tmp_dir/configs.tar.gz"; then
        rm -rf "$tmp_dir"
        error "Failed to download configuration files from $config_url"
    fi
    
    log "Extracting configuration files..."
    if ! tar xzf "$tmp_dir/configs.tar.gz" -C "$tmp_dir"; then
        rm -rf "$tmp_dir"
        error "Failed to extract configuration files"
    fi
    
    # List extracted contents for debugging
    log "Extracted files:"
    ls -la "$tmp_dir"
    
    # Create configuration directories
    mkdir -p "$KISSPANEL_DIR/conf"
    
    local extract_dir="$tmp_dir/kisspanel-${config_version}"
    
    # Check if configs directory exists
    if [ ! -d "$extract_dir/configs" ]; then
        rm -rf "$tmp_dir"
        error "Configuration directory not found in downloaded package"
    fi
    
    # Copy configurations with verbose logging
    log "Installing configuration files..."
    for dir in nginx php panel system; do
        if [ -d "$extract_dir/configs/$dir" ]; then
            log "Copying $dir configurations..."
            cp -rv "$extract_dir/configs/$dir" "$KISSPANEL_DIR/conf/"
        else
            warning "Directory $dir not found in configurations"
        fi
    done
    
    # Set proper permissions
    chown -R root:root "$KISSPANEL_DIR/conf"
    find "$KISSPANEL_DIR/conf" -type d -exec chmod 755 {} \;
    find "$KISSPANEL_DIR/conf" -type f -exec chmod 644 {} \;
    
    # Cleanup
    rm -rf "$tmp_dir"
    
    log "Configuration files installed successfully"
}

# Check for existing panel installations
check_existing_panel() {
    local panels=("/usr/local/cpanel" "/usr/local/directadmin" "/usr/local/plesk" 
                 "/usr/local/hestia" "/usr/local/vestacp" "/usr/local/cyberpanel")
    
    for panel in "${panels[@]}"; do
        if [ -d "$panel" ]; then
            error "Found existing control panel installation at $panel"
        fi
    done
}

# Check for selinux status
check_selinux() {
    if command -v getenforce >/dev/null 2>&1; then
        if [ "$(getenforce)" = "Enforcing" ]; then
            warning "SELinux is enabled. This might affect panel functionality."
        fi
    fi
}

handle_selinux() {
    if command -v getenforce >/dev/null 2>&1; then
        if [ "$(getenforce)" = "Enforcing" ]; then
            log "SELinux is in enforcing mode. Setting to permissive..."
            setenforce 0
            # Make it permanent
            sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
            log "SELinux set to permissive mode"
        fi
    fi
}

install_locale() {
    log "Setting up system locale..."
    case $OS in
        almalinux|rocky)
            $PACKAGE_INSTALL glibc-langpack-en
            ;;
        ubuntu)
            $PACKAGE_INSTALL locales
            locale-gen en_US.UTF-8
            ;;
    esac
}

# Verify network configuration
check_network() {
    # Check if hostname resolves
    if ! host "$(hostname)" >/dev/null 2>&1; then
        warning "Hostname does not resolve. DNS might not be configured correctly."
    fi
    
    # Check for valid gateway
    if ! ip route | grep -q default; then
        error "No default gateway configured"
    fi
}

# Check required commands
check_required_commands() {
    local commands=("wget" "curl" "tar" "gzip" "netstat")
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "Required command not found: $cmd"
        fi
    done
}

#----------------------------------------------------------#
#                    Message Functions                       #
#----------------------------------------------------------#

welcome_message() {
    clear
    echo "╔════════════════════════════════════════════════╗"
    echo "║             KissPanel Installer                ║"
    echo "║              Version: $VERSION                  ║"
    echo "╚════════════════════════════════════════════════╝"
    echo
    echo "This will install KissPanel Control Panel on your system."
    echo
    echo "Installation includes:"
    echo "- Nginx (required)"
    echo "- SQLite (required)"
    [ "$APACHE" = "yes" ] && echo "- Apache"
    [ "$PHPFPM" = "yes" ] && echo "- PHP-FPM"
    [ "$MARIADB" = "yes" ] && echo "- MariaDB"
    [ "$MYSQL8" = "yes" ] && echo "- MySQL 8"
    [ "$POSTGRESQL" = "yes" ] && echo "- PostgreSQL"
    [ "$EXIM" = "yes" ] && echo "- Exim Mail Server"
    [ "$DOVECOT" = "yes" ] && echo "- Dovecot IMAP/POP3"
    [ "$SPAMASSASSIN" = "yes" ] && echo "- SpamAssassin"
    [ "$CLAMAV" = "yes" ] && echo "- ClamAV"
    [ "$BIND" = "yes" ] && echo "- BIND DNS Server"
    [ "$VSFTPD" = "yes" ] && echo "- VSFTPD Server"
    [ "$PROFTPD" = "yes" ] && echo "- ProFTPD Server"
    [ "$IPTABLES" = "yes" ] && echo "- Firewall"
    [ "$FAIL2BAN" = "yes" ] && echo "- Fail2ban"
    echo
    echo "System Settings:"
    echo "- Hostname: ${HOSTNAME:-auto}"
    echo "- Panel Port: $PORT"
    echo "- Language: $LANG"
    echo
    if [ "$INTERACTIVE" = "yes" ]; then
        echo "Press ENTER to continue or CTRL+C to abort..."
        read
    fi
    echo "Starting installation..."
    echo
}

show_completion_message() {
    echo
    echo "╔════════════════════════════════════════════════╗"
    echo "║        KissPanel Installation Complete         ║"
    echo "╚════════════════════════════════════════════════╝"
    echo
    echo "Control Panel URL: https://${HOSTNAME}:${PORT}"
    echo "Username: admin"
    if [ -n "$PASSWORD" ]; then
        echo "Password: $PASSWORD"
    else
        echo "Password: [Generated password shown during database creation]"
    fi
    echo
    echo "Installation Log: $KISSPANEL_DIR/logs/install.log"
    echo
    echo "Important Notes:"
    echo "- Please save these credentials"
    echo "- Change the admin password after first login"
    echo "- Configure your firewall to allow port $PORT"
    if [ "$BIND" = "yes" ]; then
        echo "- Update your domain's nameservers if using DNS service"
    fi
    echo
    echo "Documentation: https://docs.kisspanel.org"
    echo "Support: https://forum.kisspanel.org"
    echo
    echo "Thank you for installing KissPanel!"
    echo
}

show_usage() {
    echo "Usage: bash install.sh [options]"
    echo
    echo "KissPanel Control Panel Installer"
    echo
    echo "Options:"
    echo "--port NUMBER         Custom port for panel (default: 8083)"
    echo "--lang LANG          Interface language (default: en)"
    echo "--hostname FQDN      Custom hostname for server"
    echo "--email ADDRESS      Administrator email address"
    echo "--password STRING    Custom admin password"
    echo
    echo "Component Options:"
    echo "--apache [yes|no]    Install Apache (default: yes)"
    echo "--phpfpm [yes|no]    Install PHP-FPM (default: yes)"
    echo "--mariadb [yes|no]   Install MariaDB (default: yes)"
    echo "--mysql8 [yes|no]    Install MySQL 8 (default: no)"
    echo "--postgresql [yes|no] Install PostgreSQL (default: no)"
    echo "--bind [yes|no]      Install BIND DNS server (default: yes)"
    echo "--vsftpd [yes|no]    Install VSFTPD (default: yes)"
    echo
    echo "Installation Mode:"
    echo "--interactive [yes|no] Interactive installation (default: yes)"
    echo "--force [yes|no]     Force installation (default: no)"
    echo
    echo "Example:"
    echo "bash install.sh --port 2083 --hostname panel.domain.com"
    echo
}

# components functions

# components functions

# components functions

# components functions

# components functions

# components functions
#!/bin/bash

#----------------------------------------------------------#
#                    Web Server Functions                    #
#----------------------------------------------------------#

install_nginx() {
    log "Installing Nginx web server..."

    case $OS in
        ubuntu)
            $PACKAGE_UPDATE
            $PACKAGE_INSTALL $NGINX_PACKAGES
            ;;
        almalinux|rocky)
            # Enable EPEL if needed
            if ! rpm -qa | grep -q epel-release; then
                $PACKAGE_INSTALL epel-release
            fi
            $PACKAGE_INSTALL $NGINX_PACKAGES
            ;;
        *)
            error "Unsupported OS for Nginx installation"
            ;;
    esac

    # Create directory structure
    mkdir -p $KISSPANEL_DIR/conf/nginx/conf.d
    mkdir -p $KISSPANEL_DIR/conf/nginx/sites-available
    mkdir -p $KISSPANEL_DIR/conf/nginx/sites-enabled
    mkdir -p /var/log/nginx
    mkdir -p /var/www/html

    # Download configurations first
    log "Downloading configurations..."
    download_configs

    # Now copy from our downloaded configs
    if [ ! -f "$KISSPANEL_DIR/conf/nginx/nginx.conf" ]; then
        error "Nginx configuration files not found after download"
    fi

    # Create symbolic link for Nginx configuration
    if [ -f /etc/nginx/nginx.conf ]; then
        mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.original
    fi
    ln -sf $KISSPANEL_DIR/conf/nginx/nginx.conf /etc/nginx/nginx.conf

    # Configure default website
    ln -sf $KISSPANEL_DIR/conf/nginx/sites-available/default $KISSPANEL_DIR/conf/nginx/sites-enabled/

    # Set proper permissions
    chown -R root:root $KISSPANEL_DIR/conf/nginx
    chmod -R 644 $KISSPANEL_DIR/conf/nginx
    chmod 755 $KISSPANEL_DIR/conf/nginx
    chmod 755 $KISSPANEL_DIR/conf/nginx/{sites-available,sites-enabled,conf.d}

    # Create system user for Nginx if it doesn't exist
    if ! id -u nginx >/dev/null 2>&1; then
        useradd -r -d /var/www -s /sbin/nologin -c "Nginx user" nginx
    fi

    # Set proper permissions for web directories
    chown -R nginx:nginx /var/www/html
    chmod 755 /var/www/html

    # Enable and start Nginx
    $SERVICE_ENABLE nginx
    $SERVICE_START nginx

    # Verify installation
    if ! nginx -t; then
        error "Nginx configuration test failed"
    fi

    log "Nginx installation completed"
}

install_sqlite() {
    log "Installing SQLite..."

    # Install SQLite packages based on OS
    case $OS in
        ubuntu|debian)
            $PACKAGE_INSTALL sqlite3 libsqlite3-dev
            ;;
        centos|rhel|rocky|alma)
            $PACKAGE_INSTALL sqlite sqlite-devel
            ;;
        *)
            error "Unsupported OS for SQLite installation"
            ;;
    esac

    # Create database directory
    mkdir -p $KISSPANEL_DIR/data
    chmod 750 $KISSPANEL_DIR/data

    # Test SQLite installation
    if ! sqlite3 --version >/dev/null 2>&1; then
        error "SQLite installation failed"
    fi

    log "SQLite installation completed"
}

configure_nginx() {
    log "Configuring Nginx..."

    # Basic Nginx configuration
    cat > $KISSPANEL_DIR/conf/nginx/nginx.conf <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    include $KISSPANEL_DIR/conf/nginx/conf.d/*.conf;
    include $KISSPANEL_DIR/conf/nginx/sites-enabled/*;
}
EOF

    # Configure default virtual host
    cat > $KISSPANEL_DIR/conf/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    # Create default index page
    cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to KissPanel</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>Welcome to KissPanel</h1>
    <p>If you see this page, the web server is successfully installed and working.</p>
</body>
</html>
EOF

    # Test configuration
    nginx -t || error "Nginx configuration test failed"
    
    # Reload Nginx
    $SERVICE_RESTART nginx

    log "Nginx configuration completed"
}

#----------------------------------------------------------#
#                    Apache Functions                        #
#----------------------------------------------------------#

install_apache() {
    if [ "$APACHE" != "yes" ]; then
        return
    fi

    log "Installing Apache web server..."

    # Install Apache packages based on OS
    case $OS in
        ubuntu|debian)
            $PACKAGE_INSTALL $APACHE_PACKAGES
            a2enmod rewrite
            a2enmod ssl
            a2enmod proxy
            a2enmod proxy_fcgi
            a2enmod headers
            ;;
        centos|rhel|rocky|alma)
            $PACKAGE_INSTALL $APACHE_PACKAGES
            # Enable required modules through configuration
            ;;
        *)
            error "Unsupported OS for Apache installation"
            ;;
    esac

    # Create directory structure
    mkdir -p $KISSPANEL_DIR/conf/apache/conf.d
    mkdir -p $KISSPANEL_DIR/conf/apache/sites-available
    mkdir -p $KISSPANEL_DIR/conf/apache/sites-enabled

    # Configure Apache to work with Nginx
    configure_apache_nginx

    # Set proper permissions
    chown -R root:root $KISSPANEL_DIR/conf/apache
    chmod -R 644 $KISSPANEL_DIR/conf/apache
    chmod 755 $KISSPANEL_DIR/conf/apache
    chmod 755 $KISSPANEL_DIR/conf/apache/{sites-available,sites-enabled,conf.d}

    # Enable and start Apache
    $SERVICE_ENABLE $APACHE_SERVICE
    $SERVICE_START $APACHE_SERVICE

    log "Apache installation completed"
}

configure_apache_nginx() {
    log "Configuring Apache to work with Nginx..."

    # Configure Apache to listen on alternate port
    case $OS in
        ubuntu|debian)
            sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
            ;;
        centos|rhel|rocky|alma)
            echo "Listen 8080" > /etc/httpd/conf.d/ports.conf
            ;;
    esac

    # Configure Nginx to proxy to Apache
    cat > $KISSPANEL_DIR/conf/nginx/conf.d/apache_proxy.conf <<EOF
upstream apache_backend {
    server 127.0.0.1:8080;
    keepalive 32;
}
EOF

    log "Apache-Nginx configuration completed"
}

#----------------------------------------------------------#
#                    PHP Functions                           #
#----------------------------------------------------------#

install_php() {
    if [ "$PHPFPM" != "yes" ]; then
        return
    fi

    log "Installing PHP-FPM..."

    # Install PHP repository based on OS
    case $OS in
        ubuntu|debian)
            $PACKAGE_INSTALL software-properties-common
            add-apt-repository -y ppa:ondrej/php
            $PACKAGE_UPDATE
            ;;
        centos|rhel|rocky|alma)
            $PACKAGE_INSTALL epel-release
            $PACKAGE_INSTALL https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %{rhel}).rpm
            $PACKAGE_INSTALL yum-utils
            dnf module reset php
            dnf module enable php:remi-$PHP_VERSION
            ;;
    esac

    # Install PHP packages
    $PACKAGE_INSTALL $PHP_PACKAGES

    # Create PHP-FPM configuration directories
    mkdir -p $KISSPANEL_DIR/conf/php/fpm/pool.d
    mkdir -p $KISSPANEL_DIR/conf/php/cli

    # Configure PHP
    configure_php

    # Enable and start PHP-FPM
    $SERVICE_ENABLE $PHP_SERVICE
    $SERVICE_START $PHP_SERVICE

    log "PHP-FPM installation completed"
}

configure_php() {
    log "Configuring PHP..."

    # Basic PHP configuration
    cat > $KISSPANEL_DIR/conf/php/fpm/php.ini <<EOF
[PHP]
memory_limit = 128M
max_execution_time = 30
max_input_time = 60
post_max_size = 64M
upload_max_filesize = 64M
date.timezone = UTC
expose_php = Off

[Session]
session.gc_maxlifetime = 1440
session.save_handler = files
session.save_path = /var/lib/php/sessions
session.cookie_secure = On
session.cookie_httponly = On

[opcache]
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 4000
opcache.revalidate_freq = 60
opcache.fast_shutdown = 1
opcache.enable_cli = 1
EOF

    # Configure PHP-FPM pool
    cat > $KISSPANEL_DIR/conf/php/fpm/pool.d/www.conf <<EOF
[www]
user = nginx
group = nginx
listen = 127.0.0.1:9000
listen.allowed_clients = 127.0.0.1
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
php_admin_value[error_log] = /var/log/php-fpm/www-error.log
php_admin_flag[log_errors] = on
EOF

    log "PHP configuration completed"
}

#----------------------------------------------------------#
#                    Multi-PHP Functions                     #
#----------------------------------------------------------#

install_multiphp() {
    if [ "$MULTIPHP" != "yes" ]; then
        return
    fi

    log "Installing multiple PHP versions..."

    # Define PHP versions to install
    PHP_VERSIONS="5.6 7.0 7.1 7.2 7.3 7.4 8.0 8.1 8.2"

    for version in $PHP_VERSIONS; do
        install_php_version "$version"
    done

    log "Multiple PHP versions installation completed"
}

install_php_version() {
    local version=$1
    log "Installing PHP $version..."

    case $OS in
        ubuntu|debian)
            $PACKAGE_INSTALL php${version}-fpm php${version}-common php${version}-cli \
                php${version}-mysql php${version}-pgsql php${version}-gd \
                php${version}-curl php${version}-xml php${version}-mbstring \
                php${version}-zip php${version}-bz2 php${version}-intl
            ;;
        centos|rhel|rocky|alma)
            dnf module reset php
            dnf module enable php:remi-${version} -y
            $PACKAGE_INSTALL php-fpm php-common php-cli php-mysqlnd \
                php-pgsql php-gd php-curl php-xml php-mbstring \
                php-zip php-bz2 php-intl
            ;;
    esac

    # Configure this PHP version
    configure_php_version "$version"
}

configure_php_version() {
    local version=$1
    log "Configuring PHP $version..."

    # Create configuration directories
    mkdir -p $KISSPANEL_DIR/conf/php/${version}/fpm/pool.d

    # Configure PHP-FPM pool for this version
    cat > $KISSPANEL_DIR/conf/php/${version}/fpm/pool.d/www.conf <<EOF
[www-php${version}]
user = nginx
group = nginx
listen = 127.0.0.1:90${version//./}
listen.allowed_clients = 127.0.0.1
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500
php_admin_value[error_log] = /var/log/php-fpm/www-php${version}-error.log
php_admin_flag[log_errors] = on
EOF

    # Enable and start this PHP-FPM version
    case $OS in
        ubuntu|debian)
            $SERVICE_ENABLE php${version}-fpm
            $SERVICE_START php${version}-fpm
            ;;
        centos|rhel|rocky|alma)
            $SERVICE_ENABLE php-fpm
            $SERVICE_START php-fpm
            ;;
    esac
}

# interactive functions
#!/bin/bash

#----------------------------------------------------------#
#                    Interactive Setup                       #
#----------------------------------------------------------#

interactive_setup() {
    log "Starting interactive setup..."
    
    # Hostname
    if [ -z "$HOSTNAME" ]; then
        read -p "Enter hostname (default: $(hostname)): " input_hostname
        HOSTNAME=${input_hostname:-$(hostname)}
    fi
    
    # Port
    if [ -z "$PORT" ]; then
        read -p "Enter panel port (default: 8083): " input_port
        PORT=${input_port:-8083}
    fi
    
    # Email
    if [ -z "$EMAIL" ]; then
        default_email="root@$HOSTNAME"
        read -p "Enter admin email (default: $default_email): " input_email
        EMAIL=${input_email:-$default_email}
    fi
    
    # Password - only generate if not provided via CLI
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(generate_password 16)
        log "Generated admin password: $PASSWORD"
        log "Please save this password!"
    fi
    
    log "Interactive setup completed"
}

#----------------------------------------------------------#
#                    OS-Specific Functions                   #
#----------------------------------------------------------#


#----------------------------------------------------------#
#                    Base OS Variables                       #
#----------------------------------------------------------#

# Package Management
PACKAGE_INSTALL=""
PACKAGE_UPDATE=""
PACKAGE_REMOVE=""
PACKAGE_QUERY=""

# Service Management
SERVICE_START="systemctl start"
SERVICE_STOP="systemctl stop"
SERVICE_RESTART="systemctl restart"
SERVICE_RELOAD="systemctl reload"  # Added this from my version
SERVICE_ENABLE="systemctl enable"
SERVICE_DISABLE="systemctl disable"

# Web Server
NGINX_SERVICE="nginx"
NGINX_CONF_DIR="/etc/nginx"
APACHE_SERVICE=""
APACHE_CONF_DIR=""

# PHP
PHP_SERVICE=""
PHP_CONF_DIR=""
PHP_VERSION="8.2"

# Database
MYSQL_SERVICE=""
MYSQL_CONF_DIR=""
PGSQL_SERVICE="postgresql"
PGSQL_CONF_DIR=""

# Mail
EXIM_SERVICE="exim4"
EXIM_CONF_DIR="/etc/exim4"
DOVECOT_SERVICE="dovecot"
DOVECOT_CONF_DIR="/etc/dovecot"

# DNS
BIND_SERVICE="named"
BIND_CONF_DIR="/etc/bind"

# FTP
VSFTPD_SERVICE="vsftpd"
VSFTPD_CONF_DIR="/etc/vsftpd"
PROFTPD_SERVICE="proftpd"
PROFTPD_CONF_DIR="/etc/proftpd"

# Security
FIREWALL_SERVICE=""
FIREWALL_CONF_DIR=""
FAIL2BAN_SERVICE="fail2ban"
FAIL2BAN_CONF_DIR="/etc/fail2ban"

# System Paths
SYSTEM_CONF_DIR="/etc"
SYSTEM_USER_HOME="/home"
SYSTEM_LOG_DIR="/var/log"
SYSTEM_SERVICE_DIR="/etc/systemd/system"
# ubuntu specific functions

#----------------------------------------------------------#
#                    Ubuntu Specific                         #
#----------------------------------------------------------#

# Source base variables

# Package Management
PACKAGE_INSTALL="apt-get -y install"
PACKAGE_UPDATE="apt-get update"
PACKAGE_REMOVE="apt-get -y remove"
PACKAGE_QUERY="dpkg -l"

# Web Server
NGINX_SERVICE="nginx"
NGINX_CONF_DIR="/etc/nginx"
APACHE_SERVICE="apache2"
APACHE_CONF_DIR="/etc/apache2"

# PHP
PHP_SERVICE="php${PHP_VERSION}-fpm"
PHP_CONF_DIR="/etc/php/${PHP_VERSION}"

# Database
MYSQL_SERVICE="mysql"
MYSQL_CONF_DIR="/etc/mysql"
PGSQL_SERVICE="postgresql"
PGSQL_CONF_DIR="/etc/postgresql"

# Mail
EXIM_SERVICE="exim4"
EXIM_CONF_DIR="/etc/exim4"
DOVECOT_SERVICE="dovecot"
DOVECOT_CONF_DIR="/etc/dovecot"

# DNS
BIND_SERVICE="bind9"
BIND_CONF_DIR="/etc/bind"

# FTP
VSFTPD_SERVICE="vsftpd"
VSFTPD_CONF_DIR="/etc/vsftpd"
PROFTPD_SERVICE="proftpd"
PROFTPD_CONF_DIR="/etc/proftpd"

# Security
FIREWALL_SERVICE="ufw"
FIREWALL_CONF_DIR="/etc/ufw"
FAIL2BAN_SERVICE="fail2ban"
FAIL2BAN_CONF_DIR="/etc/fail2ban"

#----------------------------------------------------------#
#                    Package Names                           #
#----------------------------------------------------------#

# Web Packages
APACHE_PACKAGES="apache2 apache2-utils"
NGINX_PACKAGES="nginx"
PHP_PACKAGES="php${PHP_VERSION}-fpm php${PHP_VERSION}-common php${PHP_VERSION}-cli \
    php${PHP_VERSION}-mysql php${PHP_VERSION}-pgsql php${PHP_VERSION}-gd \
    php${PHP_VERSION}-curl php${PHP_VERSION}-xml php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-zip php${PHP_VERSION}-bz2 php${PHP_VERSION}-intl \
    php${PHP_VERSION}-soap php${PHP_VERSION}-ldap php${PHP_VERSION}-imap"

# Database Packages
MYSQL_PACKAGES="mysql-server mysql-client"
PGSQL_PACKAGES="postgresql postgresql-contrib"

# Mail Packages
EXIM_PACKAGES="exim4 exim4-daemon-heavy"
DOVECOT_PACKAGES="dovecot-core dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-pgsql"

# DNS Packages
BIND_PACKAGES="bind9 bind9utils bind9-dnsutils"

# FTP Packages
VSFTPD_PACKAGES="vsftpd"
PROFTPD_PACKAGES="proftpd-basic proftpd-mod-mysql"

# Security Packages
FIREWALL_PACKAGES="ufw"
FAIL2BAN_PACKAGES="fail2ban"

# Additional Required Packages
ADDITIONAL_PACKAGES="curl wget tar unzip git lsof rsync rpl ca-certificates \
    apt-transport-https software-properties-common gnupg2 debconf-utils"

#----------------------------------------------------------#
#                    System Functions                        #
#----------------------------------------------------------#

# Pre-installation setup
ubuntu_setup_repositories() {
    # Add necessary repositories
    add-apt-repository -y universe
    add-apt-repository -y multiverse
    
    # Add PHP repository
    add-apt-repository -y ppa:ondrej/php
    
    # Update package lists
    $PACKAGE_UPDATE
}

# Install basic requirements
ubuntu_install_requirements() {
    $PACKAGE_INSTALL $ADDITIONAL_PACKAGES
}

# System-specific validation
ubuntu_validate_system() {
    # Check if running on supported Ubuntu version
    if [[ ! "$VERSION_ID" =~ ^(18.04|20.04|22.04|24.04)$ ]]; then
        error "Unsupported Ubuntu version: $VERSION_ID"
    fi
}
# almalinux specific functions

#----------------------------------------------------------#
#                   AlmaLinux Specific                       #
#----------------------------------------------------------#

# Source base variables

# Package Management
PACKAGE_INSTALL="dnf -y install"
PACKAGE_UPDATE="dnf -y update"
PACKAGE_REMOVE="dnf -y remove"
PACKAGE_QUERY="rpm -qa"

# Web Server
NGINX_SERVICE="nginx"
NGINX_CONF_DIR="/etc/nginx"
APACHE_SERVICE="httpd"
APACHE_CONF_DIR="/etc/httpd"

# PHP
PHP_SERVICE="php-fpm"
PHP_CONF_DIR="/etc/php-fpm.d"

# Database
MYSQL_SERVICE="mysqld"
MYSQL_CONF_DIR="/etc/my.cnf.d"
PGSQL_SERVICE="postgresql"
PGSQL_CONF_DIR="/var/lib/pgsql/data"

# Mail
EXIM_SERVICE="exim"
EXIM_CONF_DIR="/etc/exim"
DOVECOT_SERVICE="dovecot"
DOVECOT_CONF_DIR="/etc/dovecot"

# DNS
BIND_SERVICE="named"
BIND_CONF_DIR="/etc/named"

# FTP
VSFTPD_SERVICE="vsftpd"
VSFTPD_CONF_DIR="/etc/vsftpd"
PROFTPD_SERVICE="proftpd"
PROFTPD_CONF_DIR="/etc/proftpd"

# Security
FIREWALL_SERVICE="firewalld"
FIREWALL_CONF_DIR="/etc/firewalld"
FAIL2BAN_SERVICE="fail2ban"
FAIL2BAN_CONF_DIR="/etc/fail2ban"

#----------------------------------------------------------#
#                    Package Names                           #
#----------------------------------------------------------#

# Web Packages
APACHE_PACKAGES="httpd httpd-tools mod_ssl"
NGINX_PACKAGES="nginx"
PHP_PACKAGES="php php-fpm php-common php-cli php-mysqlnd php-pgsql php-gd \
    php-curl php-xml php-mbstring php-zip php-bz2 php-intl \
    php-soap php-ldap php-imap"

# Database Packages
MYSQL_PACKAGES="mysql-server mysql"
PGSQL_PACKAGES="postgresql-server postgresql-contrib"

# Mail Packages
EXIM_PACKAGES="exim"
DOVECOT_PACKAGES="dovecot dovecot-mysql dovecot-pgsql"

# DNS Packages
BIND_PACKAGES="bind bind-utils"

# FTP Packages
VSFTPD_PACKAGES="vsftpd"
PROFTPD_PACKAGES="proftpd proftpd-mysql"

# Security Packages
FIREWALL_PACKAGES="firewalld"
FAIL2BAN_PACKAGES="fail2ban"

# Additional Required Packages
ADDITIONAL_PACKAGES="curl wget tar unzip git lsof rsync dnf-utils \
    ca-certificates epel-release"

#----------------------------------------------------------#
#                    System Functions                        #
#----------------------------------------------------------#

# Pre-installation setup
almalinux_setup_repositories() {
    # Enable EPEL repository
    $PACKAGE_INSTALL epel-release
    
    # Enable PowerTools/CRB repository for additional dependencies
    if [ "$VERSION_ID" = "8" ]; then
        dnf config-manager --set-enabled powertools
    else
        dnf config-manager --set-enabled crb
    fi
    
    # Enable Remi repository for PHP
    $PACKAGE_INSTALL https://rpms.remirepo.net/enterprise/remi-release-${VERSION_ID}.rpm
    
    # Enable PHP module
    dnf module reset php -y
    dnf module enable php:remi-${PHP_VERSION} -y
    
    # Update package lists
    $PACKAGE_UPDATE
}

# Install basic requirements
almalinux_install_requirements() {
    $PACKAGE_INSTALL $ADDITIONAL_PACKAGES
}

# System-specific validation
almalinux_validate_system() {
    # Check if running on supported AlmaLinux version
    if [[ ! "$VERSION_ID" =~ ^(8|9)$ ]]; then
        error "Unsupported AlmaLinux version: $VERSION_ID"
    fi
}
# Dispatch OS-specific functions
# Dispatch OS-specific functions
dispatch_os_function() {
    local func_name=$1
    shift
    
    case $OS in
        ubuntu)
            ubuntu_${func_name} "$@"
            ;;
        almalinux)
            almalinux_${func_name} "$@"
            ;;
        *)
            error "Unsupported operating system: $OS. Currently supporting: Ubuntu, AlmaLinux"
            ;;
    esac
}

# Wrapper functions
install_requirements() {
    dispatch_os_function "install_requirements"
}

setup_repositories() {
    dispatch_os_function "setup_repositories"
}

validate_system() {
    dispatch_os_function "validate_system"
}

validate_os_requirements() {
    dispatch_os_function "validate_os_requirements"
}

#----------------------------------------------------------#
#                    00-header                    #
#----------------------------------------------------------#

#!/bin/bash

#----------------------------------------------------------#
#                    KissPanel Installer                     #
#----------------------------------------------------------#

# Version
VERSION="0.1.0"

# Set default locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Set working directory
INSTALLER_DIR=$(dirname $(readlink -f $0))
KISSPANEL_DIR="/usr/local/kisspanel"

#----------------------------------------------------------#
#                    01-defaults                    #
#----------------------------------------------------------#

#----------------------------------------------------------#
#                    Default Values                          #
#----------------------------------------------------------#

# System Configuration
PORT="2006"
LANG="en"
HOSTNAME=""
EMAIL=""
PASSWORD=""

# Panel User
PANEL_USER="kisspanel"
PANEL_GROUP="kisspanel"

# Web Server
APACHE="yes"
PHPFPM="yes"
MULTIPHP="no"

# Database
MARIADB="yes"
MYSQL8="no"
POSTGRESQL="no"

# Mail
EXIM="yes"
DOVECOT="yes"
SIEVE="no"
CLAMAV="yes"
SPAMASSASSIN="yes"

# Security
IPTABLES="yes"
FAIL2BAN="yes"
QUOTA="no"

# FTP
VSFTPD="yes"
PROFTPD="no"

# DNS
BIND="yes"

# Installation Mode
API="yes"
INTERACTIVE="yes"
FORCE="no"

# Config Download Settings
CONFIG_VERSION="$VERSION"
CONFIG_REPO="kisspanel/kisspanel-configs"
CONFIG_URL="https://github.com/${CONFIG_REPO}/releases/download/v${CONFIG_VERSION}/configs.tar.gz"

#----------------------------------------------------------#
#                    Include Functions                       #
#----------------------------------------------------------#


#----------------------------------------------------------#
#                    02-arguments                    #
#----------------------------------------------------------#

#----------------------------------------------------------#
#                    Argument Parsing                        #
#----------------------------------------------------------#

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                if [[ "$2" =~ ^[2-9][0-9]{3}$ ]] && [ "$2" -le 9999 ]; then
                    PORT="$2"
                else
                    error "Port must be between 2000-9999"
                fi
                shift 2
                ;;
            --lang)
                if [[ "$2" =~ ^(en|es)$ ]]; then
                    LANG="$2"
                else
                    error "Supported languages: en, es"
                fi
                shift 2
                ;;
            --hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --email)
                EMAIL="$2"
                shift 2
                ;;
            --password)
                if [[ "$2" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] && \
                   [[ "$2" =~ [A-Z] ]] && \
                   [[ "$2" =~ [a-z] ]] && \
                   [[ "$2" =~ [0-9] ]]; then
                    PASSWORD="$2"
                else
                    error "Password must start with letter and include upper, lower, and number"
                fi
                shift 2
                ;;
            # Web Server Options
            --apache|--phpfpm|--multiphp)
                var_name=${1#--}
                var_name=${var_name^^}
                if [[ "$2" =~ ^(yes|no)$ ]]; then
                    eval "$var_name=$2"
                else
                    error "Value for $1 must be 'yes' or 'no'"
                fi
                shift 2
                ;;
            # Database Options
            --mariadb|--mysql8|--postgresql)
                var_name=${1#--}
                var_name=${var_name^^}
                if [[ "$2" =~ ^(yes|no)$ ]]; then
                    eval "$var_name=$2"
                else
                    error "Value for $1 must be 'yes' or 'no'"
                fi
                shift 2
                ;;
            # Mail Options
            --exim|--dovecot|--sieve|--clamav|--spamassassin)
                var_name=${1#--}
                var_name=${var_name^^}
                if [[ "$2" =~ ^(yes|no)$ ]]; then
                    eval "$var_name=$2"
                else
                    error "Value for $1 must be 'yes' or 'no'"
                fi
                shift 2
                ;;
            # Security Options
            --iptables|--fail2ban|--quota)
                var_name=${1#--}
                var_name=${var_name^^}
                if [[ "$2" =~ ^(yes|no)$ ]]; then
                    eval "$var_name=$2"
                else
                    error "Value for $1 must be 'yes' or 'no'"
                fi
                shift 2
                ;;
            # FTP Options
            --vsftpd|--proftpd)
                var_name=${1#--}
                var_name=${var_name^^}
                if [[ "$2" =~ ^(yes|no)$ ]]; then
                    eval "$var_name=$2"
                else
                    error "Value for $1 must be 'yes' or 'no'"
                fi
                shift 2
                ;;
            # DNS Options
            --bind)
                if [[ "$2" =~ ^(yes|no)$ ]]; then
                    BIND="$2"
                else
                    error "Value for --bind must be 'yes' or 'no'"
                fi
                shift 2
                ;;
            # Installation Mode Options
            --api|--interactive|--force)
                var_name=${1#--}
                var_name=${var_name^^}
                if [[ "$2" =~ ^(yes|no)$ ]]; then
                    eval "$var_name=$2"
                else
                    error "Value for $1 must be 'yes' or 'no'"
                fi
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
}

#----------------------------------------------------------#
#                    03-functions                    #
#----------------------------------------------------------#

#!/bin/bash

#----------------------------------------------------------#
#                    Installation Functions                  #
#----------------------------------------------------------#

pre_install() {
    log "Starting pre-installation checks..."
    check_root
    detect_os
    check_memory
    check_disk_space
    check_cpu
    check_network
    handle_selinux
    check_existing_panel
    check_ports
    create_directories
    install_dependencies
    log "Pre-installation completed successfully"
}

create_directories() {
    log "Creating directory structure..."
    
    # Create main directories
    mkdir -p $KISSPANEL_DIR/{bin,conf,data,logs,panel,scripts}
    mkdir -p $KISSPANEL_DIR/conf/{nginx,apache,php,mysql,postgresql,mail,dns}
    mkdir -p $KISSPANEL_DIR/conf/panel/ssl
    mkdir -p $KISSPANEL_DIR/{tmp,backups}
    
    # Set proper permissions
    chown -R root:root $KISSPANEL_DIR
    chmod 755 $KISSPANEL_DIR
}

install_core_components() {
    log "Installing core components..."
    install_nginx
    configure_nginx
    install_sqlite
    create_system_database
    log "Core components installed successfully"
}

install_selected_components() {
    # Web Stack
    [ "$APACHE" = "yes" ] && install_apache && configure_apache
    [ "$PHPFPM" = "yes" ] && install_php && configure_php
    [ "$MULTIPHP" = "yes" ] && install_multiphp

    # Databases
    [ "$MARIADB" = "yes" ] && install_mariadb && configure_mariadb
    [ "$MYSQL8" = "yes" ] && install_mysql8 && configure_mysql8
    [ "$POSTGRESQL" = "yes" ] && install_postgresql && configure_postgresql

    # Mail
    [ "$EXIM" = "yes" ] && install_exim && configure_exim
    [ "$DOVECOT" = "yes" ] && install_dovecot && configure_dovecot
    [ "$SPAMASSASSIN" = "yes" ] && install_spamassassin
    [ "$CLAMAV" = "yes" ] && install_clamav

    # DNS
    [ "$BIND" = "yes" ] && install_bind && configure_bind

    # FTP
    [ "$VSFTPD" = "yes" ] && install_vsftpd && configure_vsftpd
    [ "$PROFTPD" = "yes" ] && install_proftpd && configure_proftpd

    # Security
    [ "$IPTABLES" = "yes" ] && install_firewall && configure_firewall
    [ "$FAIL2BAN" = "yes" ] && install_fail2ban && configure_fail2ban
}

post_install() {
    log "Running post-installation tasks..."
    
    # Setup basic security
    [ "$IPTABLES" = "yes" ] && configure_firewall_rules
    [ "$FAIL2BAN" = "yes" ] && configure_fail2ban_rules
    
    # Verify installation
    verify_installation
    
    log "Post-installation completed successfully"
}

verify_installation() {
    log "Verifying installation..."
    
    # Check if main services are running
    for service in nginx php-fpm kisspanel; do
        if ! systemctl is-active --quiet $service; then
            error "Service $service is not running"
        fi
    done
    
    # Check if panel is accessible
    if ! curl -k -s -o /dev/null "https://localhost:$PORT"; then
        error "Panel is not accessible on port $PORT"
    fi
    
    # Check database
    if ! sqlite3 $KISSPANEL_DIR/data/kisspanel.db "SELECT 1;" >/dev/null 2>&1; then
        error "Database is not accessible"
    fi
    
    log "Installation verified successfully"
}

#----------------------------------------------------------#
#                    04-panel                    #
#----------------------------------------------------------#

#!/bin/bash

#----------------------------------------------------------#
#                    Panel Installation                      #
#----------------------------------------------------------#

create_panel_user() {
    log "Creating panel user and group..."
    
    # Create group if it doesn't exist
    if ! getent group $PANEL_GROUP >/dev/null; then
        groupadd $PANEL_GROUP
    fi
    
    # Create user if it doesn't exist
    if ! getent passwd $PANEL_USER >/dev/null; then
        useradd -r -g $PANEL_GROUP -d $KISSPANEL_DIR -s /sbin/nologin $PANEL_USER
    fi
}

install_panel_configs() {
    log "Installing panel configurations..."
    
    # Download and install configurations
    download_configs
    
    # Create symbolic links for configurations
    ln -sf $KISSPANEL_DIR/conf/panel/nginx.conf /etc/nginx/conf.d/panel.conf
    ln -sf $KISSPANEL_DIR/conf/panel/php-fpm.conf /etc/php-fpm.d/panel.conf
    
    # Install systemd service
    ln -sf $KISSPANEL_DIR/conf/panel/systemd.conf /etc/systemd/system/kisspanel.service
    systemctl daemon-reload
}

initialize_database() {
    log "Initializing panel database..."
    
    # Create database directory if it doesn't exist
    mkdir -p $KISSPANEL_DIR/data
    chown $PANEL_USER:$PANEL_GROUP $KISSPANEL_DIR/data
    chmod 750 $KISSPANEL_DIR/data
    
    # Initialize database
    sqlite3 $KISSPANEL_DIR/data/kisspanel.db < $KISSPANEL_DIR/conf/panel/schema.sql
    
    # Set proper permissions
    chown $PANEL_USER:$PANEL_GROUP $KISSPANEL_DIR/data/kisspanel.db
    chmod 640 $KISSPANEL_DIR/data/kisspanel.db
}

start_panel_services() {
    log "Starting panel services..."
    
    # Reload web services
    systemctl reload nginx
    systemctl reload php-fpm
    
    # Enable and start panel service
    systemctl enable kisspanel
    systemctl start kisspanel
}

#----------------------------------------------------------#
#                    05-main                    #
#----------------------------------------------------------#

#!/bin/bash

#----------------------------------------------------------#
#                    Main Installation                       #
#----------------------------------------------------------#

main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Show welcome message
    welcome_message

    # Run interactive setup if enabled
    [ "$INTERACTIVE" = "yes" ] && interactive_setup

    # Start installation sequence
    pre_install

    # Install core components (required)
    install_core_components

    # Create panel user and setup directories
    create_panel_user
    create_directories

    # Install selected components
    install_selected_components

    # Configure panel
    install_panel_configs
    initialize_database

    # Start services
    start_panel_services

    # Run post-installation tasks
    post_install

    # Show completion message
    show_completion_message
}

#----------------------------------------------------------#
#                    Start Installation                      #
#----------------------------------------------------------#

main "$@"

