# Quick Start Guide

## 1. Start Everything
Open PowerShell and run:
```powershell
cd docker/app
docker compose down
docker compose up -d
```

## 2. Set Up MinIO
```powershell
# Configure MinIO and create bucket
docker exec app-storage-1 mc alias set myminio http://localhost:9000 minio minio123
docker exec app-storage-1 mc mb myminio/testbucket

# Upload a test file
echo "Test file content" | docker exec -i app-storage-1 mc pipe myminio/testbucket/test.txt
```

## 3. Run Bacula Backup
```powershell
# Run backup job
docker exec app-bacula-server-1 sh -c 'echo "run job=MinIOBackup yes" | bconsole'
```

## 4. Browser Access

### MinIO Console
1. Open http://localhost:9001
2. Login with:
   - Username: minio
   - Password: minio123

### Baculum (Bacula Web UI)
1. Open http://localhost:9095
2. Login with:
   - Username: admin
   - Password: difficult

### Web Application
1. Open http://localhost:3000
2. Upload files using the web interface

## 5. Test Complete Flow
```powershell
# Run automated test
./tests/minio_backup_test.ps1
```

## Troubleshooting
If something's not working:
```powershell
# Restart everything
docker compose down
docker compose up -d

# Check service status
docker compose ps

# View logs
docker compose logs bacula-server
docker compose logs storage
docker compose logs web
```
