# Complete Setup Tutorial: Bacula, MinIO, and Web Application Integration

This tutorial provides step-by-step instructions to set up and integrate all components of our backup solution.

## Step 1: Initial Setup

1. Clone the repository and navigate to the project directory:
```bash
git clone <repository-url>
cd PROJECT
```

2. Build the Bacula server image:
```bash
cd bacula-server
./build.sh
# Select option 1 for PostgreSQL when prompted
cd ..
```

## Step 2: Configuration Files Setup

1. Configure Bacula Director (`bacula-server/conf/11/postgresql/bacula-dir.conf`):
- Set up MinIO backup job
- Configure backup schedule
- Define storage locations

2. Verify web application configuration (`docker/app/index.js`):
- MinIO client configuration
- File upload endpoints
- Error handling

3. Check Docker Compose configuration (`docker/app/docker-compose.yml`):
- Port mappings
- Volume mounts
- Environment variables

## Step 3: Start the Services

1. Launch the entire stack:
```bash
cd docker/app
docker compose up -d
```

2. Verify all services are running:
```bash
docker compose ps
```

Expected output:
```
NAME                    STATUS              PORTS
app-bacula-server-1     Up                 9101-9103/tcp, 9095-9096/tcp
app-catalog-db-1        Up                 5432/tcp
app-db-1               Up                  5432/tcp
app-storage-1          Up                  9000-9001/tcp
app-web-1              Up                  3000/tcp
```

## Step 4: Initialize MinIO

1. Set up MinIO client and create test bucket:
```powershell
# Configure MinIO client
docker exec app-storage-1 mc alias set myminio http://localhost:9000 minio minio123

# Create test bucket
docker exec app-storage-1 mc mb myminio/testbucket
```

## Step 5: Test the Integration

1. Upload a test file to MinIO:
```powershell
echo "Test file content" | docker exec -i app-storage-1 mc pipe myminio/testbucket/test.txt
```

2. Run a manual backup:
```powershell
docker exec app-bacula-server-1 sh -c 'echo "run job=MinIOBackup yes" | bconsole'
```

3. Monitor backup progress in Baculum:
- Open http://localhost:9095
- Login with admin/difficult
- Navigate to Jobs → Status

## Step 6: Verify Web Application

1. Access the web interface:
- Open http://localhost:3000
- Try uploading a file through the web interface
- Verify the file appears in MinIO console (http://localhost:9001)

2. Test backup of uploaded files:
- Run the MinIO backup job
- Verify files are included in the backup

## Step 7: Run Integration Tests

Execute the automated test suite:
```powershell
# PowerShell
./tests/minio_backup_test.ps1

# Or Bash
./tests/minio_backup_test.sh
```

## Common Operations

### Backup Operations

1. Manual backup:
```powershell
docker exec app-bacula-server-1 sh -c 'echo "run job=MinIOBackup yes" | bconsole'
```

2. Check backup status:
```powershell
docker exec app-bacula-server-1 sh -c 'echo "status dir" | bconsole'
```

### Restore Operations

1. Through Baculum Web UI:
- Navigate to http://localhost:9095
- Go to Restore → Select Job
- Choose files and restore location

2. Using bconsole:
```powershell
docker exec app-bacula-server-1 sh -c 'echo "restore" | bconsole'
```

## Monitoring and Maintenance

### Daily Checks

1. Verify services are running:
```powershell
docker compose ps
```

2. Check backup job status in Baculum

3. Monitor storage usage:
```powershell
docker exec app-storage-1 mc admin info myminio
```

### Weekly Tasks

1. Run test restore
2. Review backup logs
3. Clean up old backups if needed

## Troubleshooting Guide

### Service Issues

If services fail to start:
```powershell
# Stop all services
docker compose down

# Remove volumes if needed
docker compose down -v

# Start services again
docker compose up -d
```

### Backup Issues

1. Check Bacula Director logs:
```powershell
docker compose logs bacula-server
```

2. Verify MinIO connection:
```powershell
docker exec app-storage-1 mc ls myminio/testbucket
```

### Web Application Issues

1. Check application logs:
```powershell
docker compose logs web
```

2. Verify MinIO connectivity:
```powershell
docker exec app-web-1 curl -I http://storage:9000
```

## Best Practices

1. Regular Testing
   - Run automated tests weekly
   - Perform test restores monthly
   - Validate backup integrity

2. Security
   - Change default passwords
   - Keep configurations in version control
   - Regular security updates

3. Monitoring
   - Set up alerts for failed backups
   - Monitor storage capacity
   - Track backup completion times

## Support and Resources

- Project Documentation: See `docs/` directory
- Issue Tracking: GitHub Issues
- Community Support: Project Discord/Forums
