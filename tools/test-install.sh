#!/bin/bash

#----------------------------------------------------------#
#                    Test Variables                          #
#----------------------------------------------------------#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

KISSPANEL_DIR="/usr/local/kisspanel"
PANEL_USER="kisspanel"
PANEL_GROUP="kisspanel"

#----------------------------------------------------------#
#                    Test Functions                          #
#----------------------------------------------------------#

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

test_directory_structure() {
    echo "Testing directory structure..."
    
    local dirs=(
        "$KISSPANEL_DIR"
        "$KISSPANEL_DIR/bin"
        "$KISSPANEL_DIR/conf"
        "$KISSPANEL_DIR/data"
        "$KISSPANEL_DIR/logs"
        "$KISSPANEL_DIR/panel"
        "$KISSPANEL_DIR/scripts"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_pass "Directory exists: $dir"
        else
            log_fail "Directory missing: $dir"
        fi
    done
}

test_user_creation() {
    echo "Testing user and group creation..."
    
    if getent group "$PANEL_GROUP" >/dev/null; then
        log_pass "Group exists: $PANEL_GROUP"
    else
        log_fail "Group missing: $PANEL_GROUP"
    fi
    
    if getent passwd "$PANEL_USER" >/dev/null; then
        log_pass "User exists: $PANEL_USER"
    else
        log_fail "User missing: $PANEL_USER"
    fi
}

test_core_services() {
    echo "Testing core services..."
    
    local services=("nginx" "php-fpm")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_pass "Service running: $service"
        else
            log_fail "Service not running: $service"
        fi
    done
}

test_configurations() {
    echo "Testing configurations..."
    
    local configs=(
        "/etc/nginx/conf.d/panel.conf"
        "$KISSPANEL_DIR/conf/nginx/nginx.conf"
        "$KISSPANEL_DIR/conf/php/fpm/php.ini"
        "$KISSPANEL_DIR/conf/panel/config.php"
    )
    
    for config in "${configs[@]}"; do
        if [ -f "$config" ]; then
            log_pass "Config exists: $config"
        else
            log_fail "Config missing: $config"
        fi
    done
}

test_database() {
    echo "Testing database..."
    
    if [ -f "$KISSPANEL_DIR/data/kisspanel.db" ]; then
        log_pass "Database file exists"
        if sqlite3 "$KISSPANEL_DIR/data/kisspanel.db" "SELECT 1;" >/dev/null 2>&1; then
            log_pass "Database is accessible"
        else
            log_fail "Database is not accessible"
        fi
    else
        log_fail "Database file missing"
    fi
}

test_web_access() {
    echo "Testing web access..."
    
    local port=$(grep -r "listen" /etc/nginx/conf.d/panel.conf | grep -oE '[0-9]+' | head -1)
    port=${port:-2006}
    
    if curl -k -s -o /dev/null "https://localhost:$port"; then
        log_pass "Panel is accessible on port $port"
    else
        log_fail "Panel is not accessible on port $port"
    fi
}

#----------------------------------------------------------#
#                    Main Execution                          #
#----------------------------------------------------------#

main() {
    echo "Starting KissPanel Installation Tests"
    echo "======================================"
    echo
    
    FAILED_TESTS=0
    
    # Run tests
    test_directory_structure
    test_user_creation
    test_core_services
    test_configurations
    test_database
    test_web_access
    
    echo
    echo "======================================"
    if [ $FAILED_TESTS -eq 0 ]; then
        echo -e "${GREEN}All tests passed successfully!${NC}"
    else
        echo -e "${RED}$FAILED_TESTS test(s) failed!${NC}"
        exit 1
    fi
}

main "$@"
