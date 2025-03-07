# Automated Backup System

This backup system provides automated daily, weekly, and monthly backups for the Greats Language Center services (Moodle, openSIS, and RosarioSIS). It also implements retention policies to automatically delete old backups.

## Features

- **Scheduled Backups**: Daily, weekly, and monthly backups
- **Retention Policies**: Automatically delete old backups based on configurable retention periods
- **Multiple Automation Options**: Use cron jobs or a background scheduler
- **Status Reporting**: View backup counts and scheduler status

## Configuration

The backup system is configured with the following retention policies:

- **Daily Backups**: Keep the last 7 daily backups
- **Weekly Backups**: Keep the last 4 weekly backups
- **Monthly Backups**: Keep the last 12 monthly backups

These settings can be adjusted by modifying the variables at the top of the `backup-manager.sh` script:

```bash
# Retention policies (number of backups to keep)
DAILY_RETENTION=7      # Keep 7 daily backups
WEEKLY_RETENTION=4     # Keep 4 weekly backups
MONTHLY_RETENTION=12   # Keep 12 monthly backups
```

## Usage

The backup system is controlled by the `backup-manager.sh` script, which provides the following commands:

### Manual Backup Commands

- `./backup-manager.sh daily` - Perform a daily backup
- `./backup-manager.sh weekly` - Perform a weekly backup
- `./backup-manager.sh monthly` - Perform a monthly backup

### Automation Commands

- `./backup-manager.sh install-cron` - Install cron jobs for automated backups
- `./backup-manager.sh remove-cron` - Remove backup cron jobs
- `./backup-manager.sh run-scheduler` - Run background scheduler for automated backups
- `./backup-manager.sh stop-scheduler` - Stop background scheduler

### Other Commands

- `./backup-manager.sh status` - Show backup status
- `./backup-manager.sh help` - Show help message

## Backup Schedule

When using cron jobs or the background scheduler, backups are performed at the following times:

- **Daily Backup**: 1:00 AM every day
- **Weekly Backup**: 2:00 AM every Sunday
- **Monthly Backup**: 3:00 AM on the 1st day of each month

## Backup Storage

Backups are stored in the following directory structure:

```
backups/
  ├── daily/
  │   ├── moodle_daily_app_YYYYMMDD.tar.gz
  │   ├── moodle_daily_db_YYYYMMDD.tar.gz
  │   ├── opensis_daily_app_YYYYMMDD.tar.gz
  │   ├── opensis_daily_db_YYYYMMDD.tar.gz
  │   ├── rosario_daily_app_YYYYMMDD.tar.gz
  │   └── rosario_daily_db_YYYYMMDD.tar.gz
  ├── weekly/
  │   ├── moodle_weekly_app_YYYYMMDD.tar.gz
  │   ├── moodle_weekly_db_YYYYMMDD.tar.gz
  │   ├── opensis_weekly_app_YYYYMMDD.tar.gz
  │   ├── opensis_weekly_db_YYYYMMDD.tar.gz
  │   ├── rosario_weekly_app_YYYYMMDD.tar.gz
  │   └── rosario_weekly_db_YYYYMMDD.tar.gz
  ├── monthly/
  │   ├── moodle_monthly_app_YYYYMMDD.tar.gz
  │   ├── moodle_monthly_db_YYYYMMDD.tar.gz
  │   ├── opensis_monthly_app_YYYYMMDD.tar.gz
  │   ├── opensis_monthly_db_YYYYMMDD.tar.gz
  │   ├── rosario_monthly_app_YYYYMMDD.tar.gz
  │   └── rosario_monthly_db_YYYYMMDD.tar.gz
  ├── moodle_backup_YYYYMMDD_HHMMSS.tar.gz
  ├── moodle_db_backup_YYYYMMDD_HHMMSS.tar.gz
  ├── opensis_backup_YYYYMMDD_HHMMSS.tar.gz
  ├── opensis_db_backup_YYYYMMDD_HHMMSS.tar.gz
  ├── rosario_backup_YYYYMMDD_HHMMSS.tar.gz
  └── rosario_db_backup_YYYYMMDD_HHMMSS.tar.gz
```

The main backup directory contains temporary backups created by the `service-manager.sh` script. The backup-manager.sh script copies these backups to the appropriate type-specific directory (daily, weekly, or monthly) and then cleans up old backups based on the retention policies.

## Logs

The backup system logs its activity to the following files:

- `backup-manager.log` - Log file for the backup-manager.sh script
- `backup-scheduler.log` - Log file for the background scheduler

## Automation Options

### Cron Jobs

To use cron jobs for automated backups, run:

```bash
./backup-manager.sh install-cron
```

This will install cron jobs to run the daily, weekly, and monthly backups at the scheduled times.

### Background Scheduler

If cron is not available or you prefer to use a background process, you can run the background scheduler:

```bash
./backup-manager.sh run-scheduler
```

This will start a background process that will run the daily, weekly, and monthly backups at the scheduled times. The scheduler will continue running until you stop it with:

```bash
./backup-manager.sh stop-scheduler
```

## Integration with Service Manager

The backup system integrates with the existing `service-manager.sh` script to perform the actual backups. It calls the `service-manager.sh backup` command to create backups for each service, then copies the backups to the appropriate type-specific directory.
