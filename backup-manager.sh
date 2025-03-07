#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# Backup Manager Script
# ─────────────────────────────────────────────────────────────────
# This script manages automated backups (daily, weekly, monthly)
# and implements retention policies to delete old backups

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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Service manager script
SERVICE_MANAGER="${SCRIPT_DIR}/service-manager.sh"

# Backup directory
BACKUP_DIR="${SCRIPT_DIR}/backups"

# Backup types
BACKUP_TYPES=("daily" "weekly" "monthly")

# Retention policies (number of backups to keep)
DAILY_RETENTION=7      # Keep 7 daily backups
WEEKLY_RETENTION=4     # Keep 4 weekly backups
MONTHLY_RETENTION=12   # Keep 12 monthly backups

# Services to backup (from service-manager.sh)
SERVICES=("moodle" "opensis" "rosario")

# Log file
LOG_FILE="${SCRIPT_DIR}/backup-manager.log"

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
# Helper Functions
# ─────────────────────────────────────────────────────────────────

# Function to ensure backup directory exists
ensure_backup_dir() {
  if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    log "INFO" "Created backup directory: $BACKUP_DIR"
  fi
}

# Function to ensure backup type subdirectories exist
ensure_backup_type_dirs() {
  for type in "${BACKUP_TYPES[@]}"; do
    if [ ! -d "${BACKUP_DIR}/${type}" ]; then
      mkdir -p "${BACKUP_DIR}/${type}"
      log "INFO" "Created ${type} backup directory: ${BACKUP_DIR}/${type}"
    fi
  done
}

# Function to check if service-manager.sh exists
check_service_manager() {
  if [ ! -f "$SERVICE_MANAGER" ]; then
    log "ERROR" "Service manager script not found: $SERVICE_MANAGER"
    exit 1
  fi
}

# ─────────────────────────────────────────────────────────────────
# Backup Functions
# ─────────────────────────────────────────────────────────────────

# Function to perform a backup of a specific type (daily, weekly, monthly)
perform_backup() {
  local backup_type=$1
  local start_time=$(date +%s)

  display_header "Performing ${backup_type} Backup"
  log "INFO" "Starting ${backup_type} backup..."

  # Create backup type directory if it doesn't exist
  if [ ! -d "${BACKUP_DIR}/${backup_type}" ]; then
    mkdir -p "${BACKUP_DIR}/${backup_type}"
    log "INFO" "Created ${backup_type} backup directory: ${BACKUP_DIR}/${backup_type}"
  fi

  # Backup each service
  for service in "${SERVICES[@]}"; do
    log "INFO" "Backing up ${service} for ${backup_type} backup..."

    # Call service-manager.sh to perform the backup
    if $SERVICE_MANAGER backup "$service"; then
      # Get the latest backup files for this service
      local latest_app_backup=$(find "$BACKUP_DIR" -maxdepth 1 -name "${service}_backup_*.tar.gz" -type f -printf "%T@ %p\n" | sort -nr | head -1 | cut -d' ' -f2-)
      local latest_db_backup=$(find "$BACKUP_DIR" -maxdepth 1 -name "${service}_db_backup_*.tar.gz" -type f -printf "%T@ %p\n" | sort -nr | head -1 | cut -d' ' -f2-)

      if [ -n "$latest_app_backup" ] && [ -n "$latest_db_backup" ]; then
        # Copy the latest backups to the type-specific directory
        local timestamp=$(date +"%Y%m%d")
        local app_backup_dest="${BACKUP_DIR}/${backup_type}/${service}_${backup_type}_app_${timestamp}.tar.gz"
        local db_backup_dest="${BACKUP_DIR}/${backup_type}/${service}_${backup_type}_db_${timestamp}.tar.gz"

        cp "$latest_app_backup" "$app_backup_dest"
        cp "$latest_db_backup" "$db_backup_dest"

        log "INFO" "Copied ${service} backups to ${backup_type} directory:"
        log "INFO" "  - Application: $(basename "$app_backup_dest")"
        log "INFO" "  - Database: $(basename "$db_backup_dest")"
      else
        log "ERROR" "Failed to find latest backups for ${service}"
      fi
    else
      log "ERROR" "Failed to backup ${service}"
    fi
  done

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log "INFO" "${backup_type} backup completed in $(format_duration $duration)"
}

# ─────────────────────────────────────────────────────────────────
# Cleanup Functions
# ─────────────────────────────────────────────────────────────────

# Function to clean up old backups based on retention policy
cleanup_old_backups() {
  local backup_type=$1
  local retention=$2

  display_header "Cleaning up old ${backup_type} backups"
  log "INFO" "Cleaning up old ${backup_type} backups (keeping ${retention} most recent)..."

  for service in "${SERVICES[@]}"; do
    # Clean up old application backups
    local app_backups=($(find "${BACKUP_DIR}/${backup_type}" -name "${service}_${backup_type}_app_*.tar.gz" -type f -printf "%T@ %p\n" | sort -nr | awk '{print $2}'))

    if [ ${#app_backups[@]} -gt $retention ]; then
      log "INFO" "Found ${#app_backups[@]} ${backup_type} application backups for ${service}, keeping ${retention}"

      for ((i=retention; i<${#app_backups[@]}; i++)); do
        log "INFO" "Deleting old ${backup_type} application backup: $(basename "${app_backups[$i]}")"
        rm "${app_backups[$i]}"
      done
    else
      log "INFO" "Found ${#app_backups[@]} ${backup_type} application backups for ${service}, no cleanup needed"
    fi

    # Clean up old database backups
    local db_backups=($(find "${BACKUP_DIR}/${backup_type}" -name "${service}_${backup_type}_db_*.tar.gz" -type f -printf "%T@ %p\n" | sort -nr | awk '{print $2}'))

    if [ ${#db_backups[@]} -gt $retention ]; then
      log "INFO" "Found ${#db_backups[@]} ${backup_type} database backups for ${service}, keeping ${retention}"

      for ((i=retention; i<${#db_backups[@]}; i++)); do
        log "INFO" "Deleting old ${backup_type} database backup: $(basename "${db_backups[$i]}")"
        rm "${db_backups[$i]}"
      done
    else
      log "INFO" "Found ${#db_backups[@]} ${backup_type} database backups for ${service}, no cleanup needed"
    fi
  done

  log "INFO" "Cleanup of old ${backup_type} backups completed"
}

# Function to clean up temporary backups in the main backup directory
cleanup_temp_backups() {
  display_header "Cleaning up temporary backups"
  log "INFO" "Cleaning up temporary backups in main backup directory..."

  # Keep only the 2 most recent backups for each service in the main directory
  for service in "${SERVICES[@]}"; do
    # Clean up old application backups
    local app_backups=($(find "$BACKUP_DIR" -maxdepth 1 -name "${service}_backup_*.tar.gz" -type f -printf "%T@ %p\n" | sort -nr | awk '{print $2}'))

    if [ ${#app_backups[@]} -gt 2 ]; then
      log "INFO" "Found ${#app_backups[@]} temporary application backups for ${service}, keeping 2"

      for ((i=2; i<${#app_backups[@]}; i++)); do
        log "INFO" "Deleting old temporary application backup: $(basename "${app_backups[$i]}")"
        rm "${app_backups[$i]}"
      done
    fi

    # Clean up old database backups
    local db_backups=($(find "$BACKUP_DIR" -maxdepth 1 -name "${service}_db_backup_*.tar.gz" -type f -printf "%T@ %p\n" | sort -nr | awk '{print $2}'))

    if [ ${#db_backups[@]} -gt 2 ]; then
      log "INFO" "Found ${#db_backups[@]} temporary database backups for ${service}, keeping 2"

      for ((i=2; i<${#db_backups[@]}; i++)); do
        log "INFO" "Deleting old temporary database backup: $(basename "${db_backups[$i]}")"
        rm "${db_backups[$i]}"
      done
    fi
  done

  log "INFO" "Cleanup of temporary backups completed"
}

# ─────────────────────────────────────────────────────────────────
# Main Functions
# ─────────────────────────────────────────────────────────────────

# Function to perform daily backup
daily_backup() {
  perform_backup "daily"
  cleanup_old_backups "daily" $DAILY_RETENTION
  cleanup_temp_backups
}

# Function to perform weekly backup
weekly_backup() {
  perform_backup "weekly"
  cleanup_old_backups "weekly" $WEEKLY_RETENTION
}

# Function to perform monthly backup
monthly_backup() {
  perform_backup "monthly"
  cleanup_old_backups "monthly" $MONTHLY_RETENTION
}

# Function to install cron jobs
install_cron_jobs() {
  display_header "Installing Cron Jobs"
  log "INFO" "Installing cron jobs for automated backups..."

  # Check if crontab command is available
  if command -v crontab >/dev/null 2>&1; then
    # Create temporary file for crontab
    local temp_cron=$(mktemp)

    # Export current crontab
    crontab -l > "$temp_cron" 2>/dev/null || echo "" > "$temp_cron"

    # Check if our backup jobs are already installed
    if grep -q "backup-manager.sh" "$temp_cron"; then
      log "INFO" "Backup cron jobs are already installed"
      rm "$temp_cron"
      return 0
    fi

    # Add header comment
    echo "# Automated backup jobs for Greats Language Center" >> "$temp_cron"

    # Add daily backup job (runs at 1:00 AM every day)
    echo "0 1 * * * $SCRIPT_DIR/backup-manager.sh daily" >> "$temp_cron"

    # Add weekly backup job (runs at 2:00 AM every Sunday)
    echo "0 2 * * 0 $SCRIPT_DIR/backup-manager.sh weekly" >> "$temp_cron"

    # Add monthly backup job (runs at 3:00 AM on the 1st day of each month)
    echo "0 3 1 * * $SCRIPT_DIR/backup-manager.sh monthly" >> "$temp_cron"

    # Install new crontab
    crontab "$temp_cron"

    # Clean up
    rm "$temp_cron"

    log "INFO" "Cron jobs installed successfully:"
    log "INFO" "  - Daily backup: 1:00 AM every day"
    log "INFO" "  - Weekly backup: 2:00 AM every Sunday"
    log "INFO" "  - Monthly backup: 3:00 AM on the 1st day of each month"
  else
    log "WARN" "Crontab command not available. Cannot install cron jobs automatically."
    log "INFO" "Here are the cron entries you can add manually to your system:"
    echo ""
    echo "# Automated backup jobs for Greats Language Center"
    echo "0 1 * * * $SCRIPT_DIR/backup-manager.sh daily"
    echo "0 2 * * 0 $SCRIPT_DIR/backup-manager.sh weekly"
    echo "0 3 1 * * $SCRIPT_DIR/backup-manager.sh monthly"
    echo ""
    log "INFO" "Alternatively, you can use the 'run-scheduler' command to run a background scheduler."
  fi
}

# Function to remove cron jobs
remove_cron_jobs() {
  display_header "Removing Cron Jobs"
  log "INFO" "Removing backup cron jobs..."

  # Check if crontab command is available
  if command -v crontab >/dev/null 2>&1; then
    # Create temporary file for crontab
    local temp_cron=$(mktemp)

    # Export current crontab
    crontab -l > "$temp_cron" 2>/dev/null || echo "" > "$temp_cron"

    # Remove backup jobs
    sed -i '/backup-manager.sh/d' "$temp_cron"
    sed -i '/Automated backup jobs for Greats Language Center/d' "$temp_cron"

    # Install new crontab
    crontab "$temp_cron"

    # Clean up
    rm "$temp_cron"

    log "INFO" "Backup cron jobs removed successfully"
  else
    log "WARN" "Crontab command not available. Cannot remove cron jobs automatically."
    log "INFO" "Please remove the following entries from your crontab manually:"
    echo ""
    echo "# Automated backup jobs for Greats Language Center"
    echo "0 1 * * * $SCRIPT_DIR/backup-manager.sh daily"
    echo "0 2 * * 0 $SCRIPT_DIR/backup-manager.sh weekly"
    echo "0 3 1 * * $SCRIPT_DIR/backup-manager.sh monthly"
  fi
}

# Function to run a background scheduler
run_scheduler() {
  display_header "Running Background Scheduler"
  log "INFO" "Starting background scheduler for automated backups..."

  # Create a scheduler script
  local scheduler_script="${SCRIPT_DIR}/backup-scheduler.sh"

  cat > "$scheduler_script" << 'EOF'
#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_MANAGER="${SCRIPT_DIR}/backup-manager.sh"
LOG_FILE="${SCRIPT_DIR}/backup-scheduler.log"

# Function to log messages
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

log "Backup scheduler started"

# Initialize last run times
last_daily_run=0
last_weekly_run=0
last_monthly_run=0

# Main loop
while true; do
  current_time=$(date +%s)
  current_hour=$(date +%H)
  current_day=$(date +%u)  # 1-7, 1 is Monday
  current_date=$(date +%d) # Day of month

  # Daily backup at 1:00 AM
  if [ "$current_hour" = "01" ] && [ $((current_time - last_daily_run)) -gt 82800 ]; then # 23 hours
    log "Running daily backup"
    "$BACKUP_MANAGER" daily >> "$LOG_FILE" 2>&1
    last_daily_run=$current_time
  fi

  # Weekly backup at 2:00 AM on Sunday (day 7)
  if [ "$current_hour" = "02" ] && [ "$current_day" = "7" ] && [ $((current_time - last_weekly_run)) -gt 604800 ]; then # 7 days
    log "Running weekly backup"
    "$BACKUP_MANAGER" weekly >> "$LOG_FILE" 2>&1
    last_weekly_run=$current_time
  fi

  # Monthly backup at 3:00 AM on the 1st day of the month
  if [ "$current_hour" = "03" ] && [ "$current_date" = "01" ] && [ $((current_time - last_monthly_run)) -gt 2592000 ]; then # 30 days
    log "Running monthly backup"
    "$BACKUP_MANAGER" monthly >> "$LOG_FILE" 2>&1
    last_monthly_run=$current_time
  fi

  # Sleep for 5 minutes
  sleep 300
done
EOF

  # Make the scheduler script executable
  chmod +x "$scheduler_script"

  # Start the scheduler in the background
  nohup "$scheduler_script" > /dev/null 2>&1 &

  # Save the PID
  local scheduler_pid=$!
  echo "$scheduler_pid" > "${SCRIPT_DIR}/backup-scheduler.pid"

  log "INFO" "Background scheduler started with PID $scheduler_pid"
  log "INFO" "Scheduler will run:"
  log "INFO" "  - Daily backup: 1:00 AM every day"
  log "INFO" "  - Weekly backup: 2:00 AM every Sunday"
  log "INFO" "  - Monthly backup: 3:00 AM on the 1st day of each month"
  log "INFO" "Logs are saved to: ${SCRIPT_DIR}/backup-scheduler.log"
}

# Function to stop the background scheduler
stop_scheduler() {
  display_header "Stopping Background Scheduler"
  log "INFO" "Stopping background scheduler..."

  local pid_file="${SCRIPT_DIR}/backup-scheduler.pid"

  if [ -f "$pid_file" ]; then
    local pid=$(cat "$pid_file")

    if ps -p "$pid" > /dev/null; then
      log "INFO" "Killing scheduler process with PID $pid"
      kill "$pid"
      rm "$pid_file"
      log "INFO" "Background scheduler stopped"
    else
      log "WARN" "Scheduler process with PID $pid is not running"
      rm "$pid_file"
    fi
  else
    log "WARN" "Scheduler PID file not found. Scheduler may not be running."
  fi
}

# Function to show backup status
show_backup_status() {
  display_header "Backup Status"

  # Check if backup directories exist
  ensure_backup_dir
  ensure_backup_type_dirs

  log "INFO" "Backup configuration:"
  log "INFO" "  - Daily backups: Keep last $DAILY_RETENTION"
  log "INFO" "  - Weekly backups: Keep last $WEEKLY_RETENTION"
  log "INFO" "  - Monthly backups: Keep last $MONTHLY_RETENTION"

  echo ""
  log "INFO" "Current backup counts:"

  # Count backups for each type and service
  for type in "${BACKUP_TYPES[@]}"; do
    echo ""
    log "INFO" "${type^} backups:"

    for service in "${SERVICES[@]}"; do
      local app_count=$(find "${BACKUP_DIR}/${type}" -name "${service}_${type}_app_*.tar.gz" -type f | wc -l)
      local db_count=$(find "${BACKUP_DIR}/${type}" -name "${service}_${type}_db_*.tar.gz" -type f | wc -l)

      echo -e "  - ${CYAN}${service}${NC}: ${app_count} application backups, ${db_count} database backups"
    done
  done

  echo ""
  log "INFO" "Temporary backups in main directory:"

  for service in "${SERVICES[@]}"; do
    local app_count=$(find "$BACKUP_DIR" -maxdepth 1 -name "${service}_backup_*.tar.gz" -type f | wc -l)
    local db_count=$(find "$BACKUP_DIR" -maxdepth 1 -name "${service}_db_backup_*.tar.gz" -type f | wc -l)

    echo -e "  - ${CYAN}${service}${NC}: ${app_count} application backups, ${db_count} database backups"
  done

  # Check if cron jobs are installed
  echo ""
  if crontab -l 2>/dev/null | grep -q "backup-manager.sh"; then
    log "INFO" "Backup cron jobs are installed"
    echo -e "  - Daily backup: 1:00 AM every day"
    echo -e "  - Weekly backup: 2:00 AM every Sunday"
    echo -e "  - Monthly backup: 3:00 AM on the 1st day of each month"
  else
    log "WARN" "Backup cron jobs are NOT installed"
    echo -e "  - Run '${YELLOW}$0 install-cron${NC}' to install cron jobs"
  fi

  # Check if background scheduler is running
  local pid_file="${SCRIPT_DIR}/backup-scheduler.pid"
  if [ -f "$pid_file" ]; then
    local pid=$(cat "$pid_file")
    if ps -p "$pid" > /dev/null; then
      log "INFO" "Background scheduler is running with PID $pid"
      echo -e "  - Daily backup: 1:00 AM every day"
      echo -e "  - Weekly backup: 2:00 AM every Sunday"
      echo -e "  - Monthly backup: 3:00 AM on the 1st day of each month"
      echo -e "  - Logs: ${SCRIPT_DIR}/backup-scheduler.log"
    else
      log "WARN" "Background scheduler PID file exists but process is not running"
      echo -e "  - Run '${YELLOW}$0 run-scheduler${NC}' to start the scheduler"
    fi
  else
    log "INFO" "Background scheduler is not running"
    echo -e "  - Run '${YELLOW}$0 run-scheduler${NC}' to start the scheduler"
  fi
}

# Function to show usage information
show_usage() {
  display_header "Backup Manager Help"

  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  ${BOLD}daily${NC}          - Perform daily backup"
  echo "  ${BOLD}weekly${NC}         - Perform weekly backup"
  echo "  ${BOLD}monthly${NC}        - Perform monthly backup"
  echo "  ${BOLD}install-cron${NC}   - Install cron jobs for automated backups"
  echo "  ${BOLD}remove-cron${NC}    - Remove backup cron jobs"
  echo "  ${BOLD}run-scheduler${NC}  - Run background scheduler for automated backups"
  echo "  ${BOLD}stop-scheduler${NC} - Stop background scheduler"
  echo "  ${BOLD}status${NC}         - Show backup status"
  echo "  ${BOLD}help${NC}           - Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 daily                - Perform daily backup"
  echo "  $0 install-cron         - Install cron jobs for automated backups"
  echo "  $0 run-scheduler        - Run background scheduler for automated backups"
  echo "  $0 status               - Show backup status"
}

# ─────────────────────────────────────────────────────────────────
# Main Script Logic
# ─────────────────────────────────────────────────────────────────

# Create log file if it doesn't exist
touch $LOG_FILE

# Log script start
log "INFO" "Backup Manager script started"
log "DEBUG" "Arguments: $@"

# Check if service-manager.sh exists
check_service_manager

# Ensure backup directories exist
ensure_backup_dir
ensure_backup_type_dirs

# Process command
case "$1" in
  daily)
    daily_backup
    ;;
  weekly)
    weekly_backup
    ;;
  monthly)
    monthly_backup
    ;;
  install-cron)
    install_cron_jobs
    ;;
  remove-cron)
    remove_cron_jobs
    ;;
  run-scheduler)
    run_scheduler
    ;;
  stop-scheduler)
    stop_scheduler
    ;;
  status)
    show_backup_status
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
log "INFO" "Backup Manager script completed"

exit 0
