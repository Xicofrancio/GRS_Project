#!/bin/bash
set -e

# Caminho para backups montado pelo volume do Bacula
BACKUP_DIR=/backups

# Esperar pelo Postgres
until pg_isready -h localhost -U "$POSTGRES_USER" >/dev/null 2>&1; do
  echo "Esperando o PostgreSQL iniciar..."
  sleep 2
done

# Verificar se a base de dados está vazia
TABLE_COUNT=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" | xargs)

if [ "$TABLE_COUNT" -eq "0" ]; then
  echo "Base de dados vazia. Restaurando backup..."
  LATEST_BACKUP=$(ls -t $BACKUP_DIR/demo_backup_*.sql 2>/dev/null | head -n 1)
  if [ -f "$LATEST_BACKUP" ]; then
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$LATEST_BACKUP"
    echo "Backup restaurado com sucesso a partir de $LATEST_BACKUP."
  else
    echo "Nenhum ficheiro de backup encontrado em $BACKUP_DIR."
  fi
else
  echo "Base de dados já contém dados. Ignorando restauração."
fi
