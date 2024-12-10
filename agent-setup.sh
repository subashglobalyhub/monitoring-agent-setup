#!/bin/bash
# Grafana Alloy Setup and Configuration Script
# Version: 1.0
# Author: Subash Chaudhary

# Default directories and settings
DEFAULT_ALLOY_CONFIG_DIR="/etc/alloy"
DEFAULT_ALLOY_CONFIG_FILE="config.alloy"
DEFAULT_LOG_RECEIVER_ENDPOINT="http://54.153.173.242:3100/loki/api/v1/push"
SERVER_LOCAL_IP=54.153.173.242
SYSTEM_LOG_FILE1="/var/log/syslog"
SYSTEM_LOG_FILE2="/var/log/php8.0-fpm.log"

# Color codes for output
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# Function to print a separator line
function print_separator {
    printf "\n%s\n" "--------------------------------------------------------------------------------"
}

function print_blue {
    local MESSAGE="$1"
    printf "${COLOR_BLUE}%s${COLOR_RESET}\n" "$MESSAGE"
}

function print_yellow {
    local MESSAGE="$1"
    printf "${COLOR_YELLOW}%s${COLOR_RESET}\n" "$MESSAGE"
}

function print_success {
    local MESSAGE="$1"
    printf "${COLOR_GREEN}%s${COLOR_RESET}\n" "$MESSAGE"
}

function print_fail {
    local MESSAGE="$1"
    printf "${COLOR_RED}%s${COLOR_RESET}\n" "$MESSAGE"
}

function print_green_message {
    local MESSAGE="$1"
    printf "${COLOR_GREEN}%s${COLOR_RESET}\n" "$MESSAGE"
}

user_help_function() {
    printf "\n\n"
    print_yellow "Usage: $0 [-ip <server_ip>] [-port <port>] [-c <config_dir>]"
    echo "Options:"
    echo "  -i, --ip <server_ip>          Required: IP address of the server."
    echo "  -p, --port <port>             Optional: Port number (default: 3100)"
    echo "  -c, --config-dir <config_dir> Optional: Directory for Alloy config (default: $DEFAULT_ALLOY_CONFIG_DIR)"

    printf "\nExamples:\n"
    print_yellow "  $0 -ip 192.168.1.10"
    print_yellow "  $0 -ip 192.168.1.10 -c /custom/config/dir"

    printf "\nContact and Support\n"
    echo -n "   Email:   "
    print_green_message "subash.chaudhary@globalyhub.com"
    echo -n "   Phone:   "
    print_green_message "+977 9823827047"

    exit 1
}


detect_input_values() {
    print_separator
    print_yellow "INPUT DETECTION"

    # Default values
    ALLOY_CONFIG_DIR=$DEFAULT_ALLOY_CONFIG_DIR
    ALLOY_CONFIG_FILE=$DEFAULT_ALLOY_CONFIG_FILE
    SERVER_IP=$SERVER_LOCAL_IP

    # Check if no arguments are provided
    if [[ $# -eq 0 ]]; then
        print_fail "No arguments provided. Server IP is required."
        user_help_function
    fi

    # Parse command-line options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -ip|--ip)
                SERVER_IP="$2"
                shift 2
                ;;
            -e|--env)
                ENV="$2"
                shift 2
                ;;
            -c|--config-dir)
                ALLOY_CONFIG_DIR="$2"
                shift 2
                ;;
            *)
                print_fail "Unknown option: $1"
                user_help_function
                ;;
        esac
    done

    # Explicitly check if SERVER_IP is empty
    if [ -z "$ENV" ]; then
        print_fail "Environment is not provided"
        user_help_function
    fi

    LOG_RECEIVER_ENDPOINT="http://$SERVER_IP:3100/loki/api/v1/push"

    printf "Input values detected:\n"
    printf "  Server IP:      ${COLOR_BLUE}$SERVER_IP${COLOR_RESET}\n"
    printf "  Config Dir:     ${COLOR_YELLOW}$ALLOY_CONFIG_DIR${COLOR_RESET}\n"
    printf "  Log Endpoint:   ${COLOR_YELLOW}$LOG_RECEIVER_ENDPOINT${COLOR_RESET}\n"
}

# Detect and validate dependencies
function validate_dependencies() {
    print_separator
    print_yellow "DEPENDENCY VALIDATION"

    if ! command -v wget > /dev/null; then
        print_fail "wget is not installed. Please install wget and rerun the script."
        exit 1
    fi

    if ! command -v gpg > /dev/null; then
        print_fail "gpg is not installed. Attempting to install it now..."
        sudo apt install -y gpg || {
            print_fail "Failed to install gpg. Aborting."
            exit 1
        }
        print_success "gpg installed successfully."
    else
        print_success "All dependencies are satisfied."
    fi
}

# Install Grafana Alloy
function install_grafana_alloy() {
    print_separator
    print_yellow "INSTALLING GRAFANA ALLOY"

    # Set up the Grafana APT repository and install Alloy
    sudo mkdir -p /etc/apt/keyrings
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

    sudo apt-get update

    if sudo apt-get install -y alloy; then
        print_success "Grafana Alloy installed successfully."
    else
        print_fail "Failed to install Grafana Alloy."
        exit 1
    fi
}

# Create necessary directories and handle configuration
function checking_old_config() {
    print_separator
    print_yellow "SETTING UP DIRECTORIES AND CONFIG"

    # Ensure config directory exists
    if [ ! -d "$ALLOY_CONFIG_DIR" ]; then
        print_fail "Config directory is missing, creating..."
        sudo mkdir -p "$ALLOY_CONFIG_DIR" || { print_fail "Failed to create config directory."; exit 1; }
        print_success "Created config directory: $ALLOY_CONFIG_DIR"
    else
        printf "Alloy config directory exists: ${COLOR_YELLOW}$ALLOY_CONFIG_DIR${COLOR_RESET}\n"
    fi

    CONFIG_FILE="$ALLOY_CONFIG_DIR/$ALLOY_CONFIG_FILE"

    if ! sudo test -f "$CONFIG_FILE"; then
        print_fail "Config file is missing, creating empty file."
        sudo touch "$CONFIG_FILE" || { print_fail "Failed to create empty config file."; exit 1; }
        print_success "Created config file: $CONFIG_FILE"
    else
        printf "Alloy config already exists. Taking Backup: ${COLOR_YELLOW}$CONFIG_FILE${COLOR_RESET}\n"
        BACKUP_DATE=$(date +"%Y-%m-%d-%H-%M")
        BACKUP_FILE="$CONFIG_FILE.backup.$BACKUP_DATE"

        # Ensure proper ownership and permissions for backup
        sudo cp "$CONFIG_FILE" "$BACKUP_FILE" || {
            print_fail "Failed to create backup of config file."
            exit 1
        }
        print_success "Backup created: $BACKUP_FILE"
    fi

    # Generate default configuration
    generate_default_alloy_config "$CONFIG_FILE"
}

# Generate default Alloy configuration
function generate_default_alloy_config() {
    local CONFIG_FILE="$1"
    HOSTNAME=$(hostname)

    print_separator
    print_blue "GENERATING DEFAULT ALLOY CONFIGURATION"

    # Default Alloy configuration template
    sudo tee "$CONFIG_FILE" > /dev/null << EOL
// Logging Configuration
logging {
  level  = "debug"
  format = "logfmt"
}

// File Matchers for Log Sources
local.file_match "nginx_logs_file" {
  path_targets = [
    { "__path__" = "/var/log/nginx/*.log" },
  ]
  sync_period = "5s"
}


local.file_match "agentcis_backend_composer_logs_file" {
  path_targets = [
    { "__path__" = "/home/agentcis/app/current/storage/logs/*.log" },
  ]
  sync_period = "5s"
}

local.file_match "agentcis_services_log_file" {
  path_targets = [
    { "__path__" = "/var/log/agentcis/*.log" },
  ]
  sync_period = "5s"
}

local.file_match "agentcis_system_log_file" {
  path_targets = [
    { "__path__" = "/var/log/syslog" },
    { "__path__" = "/var/log/php*fpm.log" },
  ]
  sync_period = "5s"
}

// Local Files - Send Logs to Loki
loki.source.file "agentcis_webserver" {
  targets    = local.file_match.nginx_logs_file.targets
  forward_to = [loki.process.add_labels_nginx_logs.receiver]
}

loki.source.file "agentcis_backend_composer" {
  targets    = local.file_match.agentcis_backend_composer_logs_file.targets
  forward_to = [loki.process.add_labels_agentcis_backend_composer.receiver]
}

loki.source.file "agentcis_services" {
  targets    = local.file_match.agentcis_services_log_file.targets
  forward_to = [loki.process.add_labels_agentcis_services.receiver]
}

loki.source.file "agentcis_system_os" {
  targets    = local.file_match.agentcis_system_log_file.targets
  forward_to = [loki.process.add_labels_agentcis_system_log.receiver]
}


// Add Labels for Local Files
loki.process "add_labels_nginx_logs" {
  stage.labels {
    values = {
      "job"          = "agentcis-web-server-logs",
      "service_name" = "nginx-web-server",
    }
  }

  stage.static_labels {
    values = {
      "job"          = "agentcis-web-server-logs",
      "service_name" = "nginx-web-server",
      "env"         = "$ENV",
      "hostname"    = "$HOSTNAME",
      "source"      = "/var/log/nginx/*.log",
    }
  }
  forward_to = [loki.write.local_loki.receiver]
}

loki.process "add_labels_agentcis_backend_composer" {
  stage.labels {
    values = {
      "job"          = "agentcis-backend-logs",
      "service_name" = "composer-logs",
    }
  }

  stage.static_labels {
    values = {
      "job"          = "agentcis-backend-logs",
      "service_name" = "composer-logs",
      "env"         = "$ENV",
      "hostname"    = "$HOSTNAME",
      "source"      = "/home/agentcis/app/current/storage/logs/*.log",
    }
  }
  forward_to = [loki.write.local_loki.receiver]
}


loki.process "add_labels_agentcis_services" {
  stage.labels {
    values = {
      "job"          = "agentcis-internal-services",
      "service_name" = "agentcis-queue-and-recovery-schedule",
    }
  }

  stage.static_labels {
    values = {
      "job"         = "agentcis-internal-services",
      "service_name" = "agentcis-queue-and-recovery-schedule",
      "env"         = "$ENV",
      "hostname"    = "$HOSTNAME",
      "source"      = "/var/log/agentcis/*.log",
    }
  }
  forward_to = [loki.write.local_loki.receiver]
}

loki.process "add_labels_agentcis_system_log" {
  stage.labels {
    values = {
      "job"          = "agentcis-system-os-and-software",
      "service_name" = "agentcis-server-log",
    }
  }

  stage.static_labels {
    values = {
      "job"         = "agentcis-system-os-and-software",
      "service_name" = "agentcis-server-log",
      "env"         = "$ENV",
      "hostname"    = "$HOSTNAME",
      "source"      = "/var/log/syslog-and-fpm",
    }
  }
  forward_to = [loki.write.local_loki.receiver]
}


// Send Logs to Loki Remote API
loki.write "local_loki" {
  endpoint {
    url = "$LOG_RECEIVER_ENDPOINT"
  }
}

EOL

    print_success "Default configuration generated at $CONFIG_FILE"
    print_yellow "Please review and modify the configuration as needed."
}

# Function to restart and enable Grafana Alloy
function restart_and_enable_alloy() {
    print_separator
    print_yellow "RESTARTING AND ENABLING GRAFANA ALLOY SERVICE"

    # Attempt to restart the Alloy service
    if sudo systemctl restart alloy; then
        print_success "Grafana Alloy service restarted successfully."
    else
        print_fail "Failed to restart Grafana Alloy service. Please check the logs for more details."
        exit 1
    fi

    # Enable Alloy service to start on boot
    if sudo systemctl enable alloy; then
        print_success "Grafana Alloy service enabled to start on boot."
    else
        print_fail "Failed to enable Grafana Alloy service. Please check the logs for more details."
        exit 1
    fi
}

post_setup_log_file_permission() {
  print_yellow "Allowing read permission to system log files"
    if sudo chmod +775 "$SYSTEM_LOG_FILE1"; then
      print_success "Read permission updated successfully for $SYSTEM_LOG_FILE1"
    else
      print_error "Failed to update read permission for $SYSTEM_LOG_FILE1"
    fi

    if sudo chmod +775 "$SYSTEM_LOG_FILE2"; then
      print_success "Read permission updated successfully for $SYSTEM_LOG_FILE2"
    else
      print_error "Failed to update read permission for $SYSTEM_LOG_FILE2"
    fi
}

# Main function
function main() {
    # Pass all arguments to detect_input_values
    detect_input_values "$@"
    validate_dependencies
    install_grafana_alloy
    checking_old_config
    restart_and_enable_alloy
    post_setup_log_file_permission
    print_success "Grafana Alloy setup completed successfully."
}

# Ensure the main function receives all arguments
main "$@"

