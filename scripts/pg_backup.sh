#!/bin/bash
set -e

TIMESTAMP=$(date +%F_%H-%M-%S)
BACKUP_DIR=/mnt/bacula
FILENAME="$BACKUP_DIR/demo_backup_$TIMESTAMP.sql"

# Dump da base de dados via rede
pg_dump -h db -U demo -d demo > "$FILENAME"

echo "Backup feito para $FILENAME"
