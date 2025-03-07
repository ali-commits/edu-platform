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
