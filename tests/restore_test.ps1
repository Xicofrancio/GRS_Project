# Bacula backup and restore test script for PowerShell
$ErrorActionPreference = "Stop"

Write-Host "Starting Bacula backup and restore test..."

# Create test data directory and files
Write-Host "Creating test data..."
docker exec app-bacula-server-1 sh -c 'mkdir -p /data && echo "test file 1" > /data/file1.txt && echo "test file 2" > /data/file2.txt'

# Step 1: Execute backup
Write-Host "Running backup job..."
docker exec app-bacula-server-1 sh -c 'echo "run job=BackupClient1 yes" | bconsole'

# Wait for backup to complete and verify backup files
Write-Host "Waiting for backup to complete..."
Start-Sleep -Seconds 20  # Give more time for the backup to complete

# Check backup status and wait for completion
Write-Host "Checking backup status..."
for ($i = 1; $i -le 6; $i++) {
    $status = docker exec app-bacula-server-1 sh -c 'echo "status dir" | bconsole'
    if ($status -notmatch "Running Jobs:") {
        Write-Host "Backup completed"
        break
    }
    Write-Host "Backup still running, waiting..."
    Start-Sleep -Seconds 10
}

# Show final messages
docker exec app-bacula-server-1 sh -c 'echo "messages" | bconsole'

# Verify backup directory exists
Write-Host "Verifying backup directory..."
$backupCheck = docker exec app-bacula-server-1 sh -c 'ls -l /mnt/bacula/'
if (-not $backupCheck) {
    Write-Error "Backup directory not accessible!"
    exit 1
}

# Calculate checksums of original data
Write-Host "Calculating original data checksums..."
$originalChecksum = docker exec app-bacula-server-1 sh -c 'find /data -type f -exec md5sum {} \; | sort'

# Step 2: Simulate data loss
Write-Host "Simulating data loss..."
docker exec app-bacula-server-1 sh -c 'find /data -mindepth 1 -not -name "." -not -name ".." -delete'

# Verify data is gone
$remainingFiles = docker exec app-bacula-server-1 sh -c 'ls -A /data/'
if ($remainingFiles) {
    Write-Error "Data directory not empty after deletion!"
    docker exec app-bacula-server-1 sh -c 'ls -la /data/'
    exit 1
}

# Step 3: Execute restore
Write-Host "Running restore job..."
docker exec app-bacula-server-1 sh -c 'printf "restore client=bacula-fd\n5\n.\nyes\nmod\n" | bconsole'

# Step 4: Validate restored data
Write-Host "Calculating restored data checksums..."
$restoredChecksum = docker exec app-bacula-server-1 sh -c 'find /data -type f -exec md5sum {} \; | sort'

# Compare checksums
if ($originalChecksum -eq $restoredChecksum) {
    Write-Host "✅ Test passed! Backup and restore completed successfully."
    exit 0
} else {
    Write-Host "❌ Test failed! Restored data does not match original data."
    Write-Host "Original checksums:"
    Write-Host $originalChecksum
    Write-Host "Restored checksums:"
    Write-Host $restoredChecksum
    exit 1
}
