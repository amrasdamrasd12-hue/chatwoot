#!/bin/bash

# Configuration
BACKUP_DIR="/home/chatwoot/cw-backups"
DB_NAME="chatwoot_production"
DB_USER="chatwoot"
DB_PASSWORD="Fxgg8tRsPJChhLx"
KEEP_DAYS=7

# Change to backup directory to prevent permission warnings
cd "${BACKUP_DIR}" || exit 1

# Create backup filename with timestamp
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
TEMP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz.tmp"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "Starting database backup for ${DB_NAME} at $(date)..."

# Run pg_dump and compress to temp file first
PGPASSWORD="${DB_PASSWORD}" pg_dump -h localhost -U ${DB_USER} ${DB_NAME} | gzip > "${TEMP_FILE}"

if [ $? -eq 0 ]; then
  mv "${TEMP_FILE}" "${BACKUP_FILE}"
  echo "Backup successfully created: ${BACKUP_FILE}"
else
  rm -f "${TEMP_FILE}"
  echo "Error: Backup failed!" >&2
  exit 1
fi

# Clean up backups older than KEEP_DAYS
echo "Cleaning up backups older than ${KEEP_DAYS} days..."
find "${BACKUP_DIR}" -name "${DB_NAME}_*.sql.gz" -mtime +${KEEP_DAYS} -delete

echo "Backup process finished at $(date)."
