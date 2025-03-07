#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# Service Manager Script
# ─────────────────────────────────────────────────────────────────
# This script helps manage the main services for Greats Language Center
# It provides commands to start, stop, backup, restore, and manage the services

# Exit on error
set -e

# ─────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────
# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Backup directory
BACKUP_DIR="./backups"

# Services configuration
SERVICES=("moodle" "opensis" "rosario")

# Docker compose file
DOCKER_COMPOSE_FILE="docker-compose.yaml"
ENV_FILE=".env"

# Log file
LOG_FILE="service-manager.log"

# ─────────────────────────────────────────────────────────────────
# Logging Functions
# ─────────────────────────────────────────────────────────────────

# Function to log messages to console and log file
log() {
  local level=$1
  local message=$2
  local color=$NC
  local prefix=""

  case $level in
    "INFO")
      color=$GREEN
      prefix="[INFO]"
      ;;
    "WARN")
      color=$YELLOW
      prefix="[WARN]"
      ;;
    "ERROR")
      color=$RED
      prefix="[ERROR]"
      ;;
    "DEBUG")
      color=$GRAY
      prefix="[DEBUG]"
      ;;
  esac

  # Get current timestamp
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  # Log to console with color
  echo -e "${color}${prefix} ${message}${NC}"

  # Log to file without color codes
  echo -e "${timestamp} ${prefix} ${message}" >> $LOG_FILE
}

# Function to display section header
display_header() {
  local title=$1
  local width=60

  echo -e "\n${BLUE}┌$(printf '%0.s─' $(seq 1 $((width-2))))┐${NC}"
  echo -e "${BLUE}│ ${YELLOW}${BOLD}$title${NC}${BLUE}$(printf '%*s' $((width-3-${#title})) "")│${NC}"
  echo -e "${BLUE}└$(printf '%0.s─' $(seq 1 $((width-2))))┘${NC}"
}

# Function to display progress
show_progress() {
  local step=$1
  local total=$2
  local message=$3

  local percentage=$((step*100/total))
  local progress=$((percentage/2))

  echo -ne "${CYAN}[${step}/${total}] ${message} ["
  for ((i=0; i<50; i++)); do
    if [ $i -lt $progress ]; then
      echo -ne "="
    elif [ $i -eq $progress ]; then
      echo -ne ">"
    else
      echo -ne " "
    fi
  done
  echo -ne "] ${percentage}%\r${NC}"

  if [ $step -eq $total ]; then
    echo -e "${CYAN}[${step}/${total}] ${message} [$(printf '=%.0s' $(seq 1 50))] 100%${NC}"
  fi
}

# Function to display command result
show_result() {
  local success=$1
  local message=$2

  if [ $success -eq 0 ]; then
    log "INFO" "✓ ${message}"
  else
    log "ERROR" "✗ ${message}"
  fi
}

# ─────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────

# Function to check if docker is running
check_docker() {
  if ! docker info > /dev/null 2>&1; then
    log "ERROR" "Docker is not running. Please start Docker and try again."
    exit 1
  fi
}

# Function to check if docker-compose file exists
check_docker_compose() {
  if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    log "ERROR" "Docker compose file not found: $DOCKER_COMPOSE_FILE"
    exit 1
  fi
}

# Function to check if .env file exists
check_env_file() {
  if [ ! -f "$ENV_FILE" ]; then
    if [ -f ".env.example" ]; then
      log "WARN" "Environment file not found. Creating from example..."
      cp .env.example .env
      log "INFO" "Created .env file from .env.example. Please review and update as needed."
    else
      log "ERROR" "Environment file not found: $ENV_FILE"
      exit 1
    fi
  fi
}

# Function to run docker-compose command
run_docker_compose() {
  local command=$1
  shift

  check_docker
  check_docker_compose
  check_env_file

  docker compose -f $DOCKER_COMPOSE_FILE --env-file $ENV_FILE $command "$@"
  return $?
}

# Function to ensure backup directory exists
ensure_backup_dir() {
  if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    log "INFO" "Created backup directory: $BACKUP_DIR"
  fi
}

# Function to format time duration
format_duration() {
  local seconds=$1
  local minutes=$((seconds / 60))
  local remaining_seconds=$((seconds % 60))

  if [ $minutes -gt 0 ]; then
    echo "${minutes}m ${remaining_seconds}s"
  else
    echo "${seconds}s"
  fi
}

# ─────────────────────────────────────────────────────────────────
# Core Functions
# ─────────────────────────────────────────────────────────────────

# Function to display usage information
show_usage() {
  display_header "Service Manager Help"

  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  ${BOLD}start${NC}       - Start all services"
  echo "  ${BOLD}stop${NC}        - Stop all services"
  echo "  ${BOLD}restart${NC}     - Restart all services"
  echo "  ${BOLD}status${NC}      - Check status of services"
  echo "  ${BOLD}logs${NC}        - View logs from services"
  echo "  ${BOLD}reset${NC}       - Reset the environment (WARNING: Deletes all data)"
  echo "  ${BOLD}backup${NC}      - Backup all services or a specific service"
  echo "  ${BOLD}restore${NC}     - Restore all services or a specific service from backup"
  echo "  ${BOLD}help${NC}        - Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 start                - Start all services"
  echo "  $0 logs moodle          - View logs for the Moodle service"
  echo "  $0 backup               - Backup all services"
  echo "  $0 backup moodle        - Backup only Moodle service"
  echo "  $0 restore moodle       - Restore Moodle service from backup"
}

# Function to initialize acme.json for Traefik
init_acme() {
  log "INFO" "Checking Traefik configuration..."

  # Create traefik directory if it doesn't exist
  if [ ! -d "traefik" ]; then
    log "INFO" "Creating traefik directory..."
    mkdir -p traefik
  fi

  # Create or check acme.json with proper permissions
  if [ ! -f "traefik/acme.json" ]; then
    log "INFO" "Initializing acme.json file..."
    touch traefik/acme.json
    chmod 600 traefik/acme.json
    log "INFO" "acme.json file initialized with proper permissions (600)"
  else
    # Ensure proper permissions if file exists
    current_perms=$(stat -c "%a" traefik/acme.json)
    if [ "$current_perms" != "600" ]; then
      log "WARN" "Incorrect permissions on acme.json: $current_perms"
      log "INFO" "Setting proper permissions on existing acme.json file..."
      chmod 600 traefik/acme.json
      log "INFO" "acme.json file permissions updated to 600"
    else
      log "DEBUG" "acme.json permissions are correct (600)"
    fi
  fi
}

# Function to check if openSIS-Classic exists, clone if not
check_opensis() {
  log "INFO" "Checking openSIS-Classic repository..."

  if [ ! -d "openSIS-Classic" ]; then
    log "INFO" "openSIS-Classic not found. Cloning repository..."
    git clone https://github.com/OS4ED/openSIS-Classic.git
    log "INFO" "openSIS-Classic repository cloned successfully!"
  else
    log "DEBUG" "openSIS-Classic repository already exists."
  fi
}

# Function to start all services
start_services() {
  display_header "Starting Services"
  local start_time=$(date +%s)

  # Initialize acme.json for Traefik
  init_acme

  # Check and clone openSIS if needed
  check_opensis

  log "INFO" "Starting all services..."

  # Start services
  if run_docker_compose up -d; then
    log "INFO" "Services started successfully!"

    # Source the .env file to get the domain variables
    if [ -f ".env" ]; then
      source .env

      log "INFO" "Services are available at:"
      echo -e "  - openSIS: ${YELLOW}https://${OPENSIS_DOMAIN}${NC}"
      echo -e "  - Moodle: ${YELLOW}https://${MOODLE_DOMAIN}${NC}"
      echo -e "  - RosarioSIS: ${YELLOW}https://${ROSARIO_DOMAIN}${NC}"
    fi
  else
    log "ERROR" "Failed to start services. Check the logs for details."
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log "INFO" "Operation completed in $(format_duration $duration)"
}

# Function to stop all services
stop_services() {
  display_header "Stopping Services"
  local start_time=$(date +%s)

  log "INFO" "Stopping all services..."

  if run_docker_compose down; then
    log "INFO" "Services stopped successfully!"
  else
    log "ERROR" "Failed to stop services. Check the logs for details."
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log "INFO" "Operation completed in $(format_duration $duration)"
}

# Function to restart all services
restart_services() {
  display_header "Restarting Services"
  local start_time=$(date +%s)

  log "INFO" "Restarting all services..."

  if run_docker_compose restart; then
    log "INFO" "Services restarted successfully!"
  else
    log "ERROR" "Failed to restart services. Check the logs for details."
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log "INFO" "Operation completed in $(format_duration $duration)"
}

# Function to check status of services
check_status() {
  display_header "Service Status"

  log "INFO" "Checking status of services..."
  run_docker_compose ps
}

# Function to view logs
view_logs() {
  local service=$1

  if [ -z "$service" ]; then
    display_header "Viewing Logs (All Services)"
    log "INFO" "Viewing logs for all services..."
    run_docker_compose logs --tail=100 -f
  else
    display_header "Viewing Logs ($service)"
    log "INFO" "Viewing logs for $service..."
    run_docker_compose logs --tail=100 -f "$service"
  fi
}

# Function to reset the environment
reset_services() {
  display_header "Reset Environment"

  log "WARN" "This will delete all data and reset the environment!"
  echo -e "${RED}WARNING: All data will be permanently deleted!${NC}"
  read -p "Are you sure you want to continue? (y/n): " confirm

  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    local start_time=$(date +%s)

    log "INFO" "Stopping services..."
    run_docker_compose down

    log "INFO" "Removing volumes..."
    docker volume rm moodle-db-data moodle-data opensis-db-data opensis-data rosario-db-data rosario-data

    log "INFO" "Environment has been reset!"
    log "INFO" "You can start a fresh environment with: $0 start"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log "INFO" "Operation completed in $(format_duration $duration)"
  else
    log "INFO" "Reset cancelled."
  fi
}

# ─────────────────────────────────────────────────────────────────
# Backup Functions
# ─────────────────────────────────────────────────────────────────

# Function to backup a specific service
backup_service() {
  local service=$1
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  local app_backup_file="${BACKUP_DIR}/${service}_backup_${timestamp}.tar.gz"
  local db_backup_file="${BACKUP_DIR}/${service}_db_backup_${timestamp}.tar.gz"
  local start_time=$(date +%s)

  display_header "Backing Up $service"

  # Validate service name
  if [[ ! " ${SERVICES[@]} " =~ " ${service} " ]]; then
    log "ERROR" "Unknown service: $service"
    log "INFO" "Available services: ${SERVICES[*]}"
    return 1
  fi

  log "INFO" "Starting backup of $service..."

  # Check if service containers are running
  if ! docker ps --format '{{.Names}}' | grep -q "$service"; then
    log "WARN" "Service $service is not running. Starting it temporarily for backup..."
    run_docker_compose up -d $service $service-db
    sleep 10
  fi

  # Backup application data
  log "INFO" "Backing up $service application data..."
  show_progress 1 3 "Backing up application data"

  case $service in
    moodle)
      docker run --rm --volumes-from moodle -v $(pwd)/${BACKUP_DIR}:/backup \
        alpine tar czf /backup/$(basename $app_backup_file) /bitnami/moodle
      ;;
    opensis)
      docker run --rm --volumes-from opensis -v $(pwd)/${BACKUP_DIR}:/backup \
        alpine tar czf /backup/$(basename $app_backup_file) /var/www/html
      ;;
    rosario)
      docker run --rm --volumes-from rosario -v $(pwd)/${BACKUP_DIR}:/backup \
        alpine tar czf /backup/$(basename $app_backup_file) /var/www/html
      ;;
  esac

  # Backup database data
  log "INFO" "Backing up $service database data..."
  show_progress 2 3 "Backing up database data"

  case $service in
    moodle)
      docker run --rm --volumes-from moodle-db -v $(pwd)/${BACKUP_DIR}:/backup \
        alpine tar czf /backup/$(basename $db_backup_file) /var/lib/postgresql/data
      ;;
    opensis)
      docker run --rm --volumes-from opensis-db -v $(pwd)/${BACKUP_DIR}:/backup \
        alpine tar czf /backup/$(basename $db_backup_file) /var/lib/mysql
      ;;
    rosario)
      docker run --rm --volumes-from rosario-db -v $(pwd)/${BACKUP_DIR}:/backup \
        alpine tar czf /backup/$(basename $db_backup_file) /var/lib/postgresql/data
      ;;
  esac

  # Verify backup files
  show_progress 3 3 "Verifying backup files"
  if [ -f "$app_backup_file" ] && [ -f "$db_backup_file" ]; then
    local app_size=$(du -h "$app_backup_file" | cut -f1)
    local db_size=$(du -h "$db_backup_file" | cut -f1)

    log "INFO" "Backup of $service completed successfully!"
    log "INFO" "Application backup: $app_backup_file ($app_size)"
    log "INFO" "Database backup: $db_backup_file ($db_size)"

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log "INFO" "Backup completed in $(format_duration $duration)"
    return 0
  else
    log "ERROR" "Backup failed. One or more backup files are missing."
    return 1
  fi
}

# Function to backup all services
backup_all_services() {
  display_header "Backing Up All Services"
  local start_time=$(date +%s)
  local success=true

  log "INFO" "Starting backup of all services..."

  for service in "${SERVICES[@]}"; do
    if ! backup_service "$service"; then
      log "ERROR" "Failed to backup $service"
      success=false
    fi
  done

  if $success; then
    log "INFO" "All services backed up successfully!"
  else
    log "WARN" "Some services failed to backup. Check the logs for details."
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log "INFO" "Operation completed in $(format_duration $duration)"
}

# ─────────────────────────────────────────────────────────────────
# Restore Functions
# ─────────────────────────────────────────────────────────────────

# Function to get available backups for a service
get_available_backups() {
  local service=$1
  local app_backups=($(ls -1 ${BACKUP_DIR}/${service}_backup_*.tar.gz 2>/dev/null))
  local db_backups=($(ls -1 ${BACKUP_DIR}/${service}_db_backup_*.tar.gz 2>/dev/null))

  # Extract dates from filenames for better display
  local app_dates=()
  local db_dates=()

  for backup in "${app_backups[@]}"; do
    local date_part=$(echo "$backup" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    local formatted_date=$(date -d "${date_part:0:8} ${date_part:9:2}:${date_part:11:2}:${date_part:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$date_part")
    app_dates+=("$formatted_date")
  done

  for backup in "${db_backups[@]}"; do
    local date_part=$(echo "$backup" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
    local formatted_date=$(date -d "${date_part:0:8} ${date_part:9:2}:${date_part:11:2}:${date_part:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$date_part")
    db_dates+=("$formatted_date")
  done

  echo "${app_backups[@]}"
  echo "${db_backups[@]}"
  echo "${app_dates[@]}"
  echo "${db_dates[@]}"
}

# Function to restore a specific service with given backup files
restore_service_with_backups() {
  local service=$1
  local app_backup=$2
  local db_backup=$3
  local start_time=$(date +%s)

  display_header "Restoring $service Service"

  # Validate service name
  if [[ ! " ${SERVICES[@]} " =~ " ${service} " ]]; then
    log "ERROR" "Unknown service: $service"
    log "INFO" "Available services: ${SERVICES[*]}"
    return 1
  fi

  # Validate backup files
  if [ ! -f "$app_backup" ]; then
    log "ERROR" "Application backup file not found: $app_backup"
    return 1
  fi

  if [ ! -f "$db_backup" ]; then
    log "ERROR" "Database backup file not found: $db_backup"
    return 1
  fi

  # Start the containers first to ensure they exist
  log "INFO" "[1/5] Starting $service containers..."
  show_progress 1 5 "Starting containers"
  run_docker_compose up -d ${service}-db ${service}

  # Wait for containers to be ready
  log "INFO" "[2/5] Waiting for containers to be ready..."
  show_progress 2 5 "Waiting for containers"
  sleep 10

  log "INFO" "[3/5] Identifying Docker volumes..."
  show_progress 3 5 "Identifying volumes"
  # Get the actual volume names (they might be prefixed with project name)
  local app_volume_name=$(docker volume ls --format "{{.Name}}" | grep "${service}-data" | head -n 1)
  local db_volume_name=$(docker volume ls --format "{{.Name}}" | grep "${service}-db-data" | head -n 1)

  log "DEBUG" "Found volumes: $app_volume_name and $db_volume_name"

  # Get the volume mountpoints
  local app_volume=""
  local db_volume=""

  if [ -n "$app_volume_name" ]; then
    app_volume=$(docker volume inspect -f '{{.Mountpoint}}' "$app_volume_name")
  fi

  if [ -n "$db_volume_name" ]; then
    db_volume=$(docker volume inspect -f '{{.Mountpoint}}' "$db_volume_name")
  fi

  # Validate volumes exist
  if [ -z "$app_volume" ] || [ -z "$app_volume_name" ]; then
    log "ERROR" "${service}-data volume not found. Cannot restore application data."
    return 1
  fi

  if [ -z "$db_volume" ] || [ -z "$db_volume_name" ]; then
    log "ERROR" "${service}-db-data volume not found. Cannot restore database data."
    return 1
  fi

  # Stop containers before restoring
  log "INFO" "[4/5] Stopping containers for data restoration..."
  show_progress 4 5 "Stopping containers"
  run_docker_compose stop ${service} ${service}-db

  # Restore data
  log "INFO" "[5/5] Restoring data..."
  show_progress 5 5 "Restoring data"

  log "INFO" "Restoring ${service} application data..."
  tar -xzf ${app_backup} -C / --strip-components=1

  log "INFO" "Restoring ${service} database data..."
  tar -xzf ${db_backup} -C / --strip-components=1

  # Restart services
  log "INFO" "Restarting ${service} services..."
  run_docker_compose start ${service}-db
  sleep 5
  run_docker_compose start ${service}

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log "INFO" "Restore of $service completed in $(format_duration $duration)!"

  return 0
}

# Function to display a unified selection interface for restoration
select_backups_for_restoration() {
  local services=("${SERVICES[@]}")
  local selected_app_backups=()
  local selected_db_backups=()
  local service_has_backups=()

  display_header "Backup Restoration Selection"

  # Check which services have backups
  for service in "${services[@]}"; do
    local backups_output=($(get_available_backups "$service"))
    local app_backups=(${backups_output[0]})
    local db_backups=(${backups_output[1]})

    if [ ${#app_backups[@]} -eq 0 ] || [ ${#db_backups[@]} -eq 0 ]; then
      service_has_backups+=("false")
      log "INFO" "$service: No complete backups available"
    else
      service_has_backups+=("true")
      log "INFO" "$service: $(( ${#app_backups[@]} )) application backups, $(( ${#db_backups[@]} )) database backups available"
    fi
  done

  # If no services have backups, exit
  if [[ ! " ${service_has_backups[@]} " =~ "true" ]]; then
    log "ERROR" "No backups found for any service. Cannot proceed with restoration."
    return 1
  fi

  log "INFO" "Select which services to restore:"

  # For each service with backups, ask if user wants to restore it
  local services_to_restore=()
  for i in "${!services[@]}"; do
    local service="${services[$i]}"
    if [ "${service_has_backups[$i]}" = "true" ]; then
      read -p "Restore $service? (y/n): " restore_choice
      if [[ $restore_choice == [yY] || $restore_choice == [yY][eE][sS] ]]; then
        services_to_restore+=("$service")

        # Get backups for this service
        local backups_output=($(get_available_backups "$service"))
        local app_backups=(${backups_output[0]})
        local db_backups=(${backups_output[1]})
        local app_dates=(${backups_output[2]})
        local db_dates=(${backups_output[3]})

        display_header "Available Backups for $service"

        echo -e "${YELLOW}Application backups:${NC}"
        for j in "${!app_backups[@]}"; do
          echo "$((j+1)). ${app_dates[$j]} ($(basename ${app_backups[$j]}))"
        done

        echo -e "\n${YELLOW}Database backups:${NC}"
        for j in "${!db_backups[@]}"; do
          echo "$((j+1)). ${db_dates[$j]} ($(basename ${db_backups[$j]}))"
        done

        # Select application backup
        read -p "Select application backup number to restore: " app_choice
        while [[ -z "$app_choice" || $app_choice -lt 1 || $app_choice -gt ${#app_backups[@]} ]]; do
          log "ERROR" "Invalid selection. Please try again."
          read -p "Select application backup number to restore: " app_choice
        done

        # Select database backup
        read -p "Select database backup number to restore: " db_choice
        while [[ -z "$db_choice" || $db_choice -lt 1 || $db_choice -gt ${#db_backups[@]} ]]; do
          log "ERROR" "Invalid selection. Please try again."
          read -p "Select database backup number to restore: " db_choice
        done

        selected_app_backups+=("${app_backups[$((app_choice-1))]}")
        selected_db_backups+=("${db_backups[$((db_choice-1))]}")
      fi
    fi
  done

  # If no services were selected, exit
  if [ ${#services_to_restore[@]} -eq 0 ]; then
    log "INFO" "No services selected for restoration. Operation cancelled."
    return 0
  fi

  # Display summary of selections
  display_header "Restoration Summary"

  for i in "${!services_to_restore[@]}"; do
    local service="${services_to_restore[$i]}"
    local app_backup=$(basename "${selected_app_backups[$i]}")
    local db_backup=$(basename "${selected_db_backups[$i]}")

    log "INFO" "$service:"
    echo -e "  - Application: $app_backup"
    echo -e "  - Database: $db_backup"
  done

  # Calculate estimated time (rough estimate: 2 minutes per service)
  local total_estimated_time=$((${#services_to_restore[@]} * 120))
  local minutes=$((total_estimated_time / 60))
  local seconds=$((total_estimated_time % 60))

  log "INFO" "Estimated restoration time: $(format_duration $total_estimated_time)"
  log "WARN" "All services will be stopped during restoration!"
  read -p "Proceed with restoration? (y/n): " final_confirm

  if [[ $final_confirm == [yY] || $final_confirm == [yY][eE][sS] ]]; then
    log "INFO" "Stopping all services..."
    run_docker_compose down

    local overall_start_time=$(date +%s)

    # Restore each selected service
    for i in "${!services_to_restore[@]}"; do
      local service="${services_to_restore[$i]}"
      local app_backup="${selected_app_backups[$i]}"
      local db_backup="${selected_db_backups[$i]}"

      restore_service_with_backups "$service" "$app_backup" "$db_backup"
    done

    # Final restart of all services
    log "INFO" "Restarting all services..."
    run_docker_compose restart

    local overall_end_time=$(date +%s)
    local overall_duration=$((overall_end_time - overall_start_time))

    display_header "Restoration Complete"
    log "INFO" "All selected services have been restored successfully!"
    log "INFO" "Total restoration time: $(format_duration $overall_duration)"

    return 0
  else
    log "INFO" "Restoration cancelled."
    return 0
  fi
}

# Function to restore all services
restore_all_services() {
  select_backups_for_restoration
}

# Function to restore a specific service
restore_service() {
  local service=$1

  # Validate service name
  if [[ ! " ${SERVICES[@]} " =~ " ${service} " ]]; then
    log "ERROR" "Unknown service: $service"
    log "INFO" "Available services: ${SERVICES[*]}"
    return 1
  fi

  # Check if service has backups
  local backups_output=($(get_available_backups "$service"))
  local app_backups=(${backups_output[0]})
  local db_backups=(${backups_output[1]})

  if [ ${#app_backups[@]} -eq 0 ] || [ ${#db_backups[@]} -eq 0 ]; then
    log "ERROR" "No complete backups found for $service"
    return 1
  fi

  # Get dates for better display
  local app_dates=(${backups_output[2]})
  local db_dates=(${backups_output[3]})

  display_header "Restore $service Service"

  echo -e "${YELLOW}Available backups for $service:${NC}"

  echo -e "${YELLOW}Application backups:${NC}"
  for j in "${!app_backups[@]}"; do
    echo "$((j+1)). ${app_dates[$j]} ($(basename ${app_backups[$j]}))"
  done

  echo -e "\n${YELLOW}Database backups:${NC}"
  for j in "${!db_backups[@]}"; do
    echo "$((j+1)). ${db_dates[$j]} ($(basename ${db_backups[$j]}))"
  done

  # Select application backup
  read -p "Select application backup number to restore: " app_choice
  while [[ -z "$app_choice" || $app_choice -lt 1 || $app_choice -gt ${#app_backups[@]} ]]; do
    log "ERROR" "Invalid selection. Please try again."
    read -p "Select application backup number to restore: " app_choice
  done

  # Select database backup
  read -p "Select database backup number to restore: " db_choice
  while [[ -z "$db_choice" || $db_choice -lt 1 || $db_choice -gt ${#db_backups[@]} ]]; do
    log "ERROR" "Invalid selection. Please try again."
    read -p "Select database backup number to restore: " db_choice
  done

  local selected_app_backup="${app_backups[$((app_choice-1))]}"
  local selected_db_backup="${db_backups[$((db_choice-1))]}"

  # Display summary
  display_header "Restoration Summary"

  log "INFO" "$service:"
  echo -e "  - Application: $(basename "$selected_app_backup")"
  echo -e "  - Database: $(basename "$selected_db_backup")"

  # Calculate estimated time
  local total_estimated_time=120

  log "INFO" "Estimated restoration time: $(format_duration $total_estimated_time)"
  log "WARN" "The $service service will be stopped during restoration!"
  read -p "Proceed with restoration? (y/n): " final_confirm

  if [[ $final_confirm == [yY] || $final_confirm == [yY][eE][sS] ]]; then
    restore_service_with_backups "$service" "$selected_app_backup" "$selected_db_backup"
    return 0
  else
    log "INFO" "Restoration cancelled."
    return 0
  fi
}

# ─────────────────────────────────────────────────────────────────
# Main Script Logic
# ─────────────────────────────────────────────────────────────────

# Create log file if it doesn't exist
touch $LOG_FILE

# Log script start
log "INFO" "Service Manager script started"
log "DEBUG" "Arguments: $@"

# Process command
case "$1" in
  start)
    start_services
    ;;
  stop)
    stop_services
    ;;
  restart)
    restart_services
    ;;
  status)
    check_status
    ;;
  logs)
    view_logs "$2"
    ;;
  reset)
    reset_services
    ;;
  backup)
    ensure_backup_dir
    if [ -z "$2" ]; then
      backup_all_services
    else
      backup_service "$2"
    fi
    ;;
  restore)
    ensure_backup_dir
    if [ -z "$2" ]; then
      restore_all_services
    else
      restore_service "$2"
    fi
    ;;
  help|--help|-h)
    show_usage
    ;;
  *)
    show_usage
    exit 1
    ;;
esac

# Log script end
log "INFO" "Service Manager script completed"

exit 0
