# MinIO + Bacula Backup Test Script
$ErrorActionPreference = "Stop"

Write-Host "Starting MinIO + Bacula backup and restore test..."

function Wait-ForMinIOFile {
    Write-Host "Monitoring MinIO bucket for files..."
    $maxAttempts = 30
    $attempt = 0
    $hasFiles = $false

    while ($attempt -lt $maxAttempts) {
        $files = docker exec app-storage-1 mc ls myminio/testbucket 2>&1
        if ($LASTEXITCODE -eq 0 -and $files) {
            $hasFiles = $true
            break
        }
        $attempt++
        Write-Host "Waiting for files... (attempt $attempt of $maxAttempts)"
        Start-Sleep -Seconds 10
    }

    if (-not $hasFiles) {
        Write-Error "No files found in MinIO bucket after timeout"
        exit 1
    }

    Write-Host "Files detected in MinIO bucket!"
}

function Get-MinIOFileChecksums {
    $output = docker exec app-storage-1 sh -c "mc ls --recursive myminio/testbucket --json" | ConvertFrom-Json
    return $output | ForEach-Object { 
        @{
            name = $_.key
            etag = $_.etag
        }
    }
}

# Step 1: Wait for files in MinIO bucket
Wait-ForMinIOFile

# Step 2: Get initial file checksums
Write-Host "Recording initial file state..."
$initialFiles = Get-MinIOFileChecksums

# Step 3: Run Bacula backup
Write-Host "Running Bacula backup job..."
docker exec app-bacula-server-1 sh -c "echo \"run job=BackupClient1 yes\" | bconsole"

# Wait for backup to complete
Write-Host "Waiting for backup to complete..."
Start-Sleep -Seconds 20

# Check backup status
Write-Host "Checking backup status..."
for ($i = 1; $i -le 6; $i++) {
    $status = docker exec app-bacula-server-1 sh -c "echo \"status dir\" | bconsole"
    if ($status -notmatch "Running Jobs:") {
        Write-Host "Backup completed"
        break
    }
    Write-Host "Backup still running, waiting..."
    Start-Sleep -Seconds 10
}

# Show backup messages
docker exec app-bacula-server-1 sh -c "echo \"messages\" | bconsole"

# Step 4: Simulate data loss
Write-Host "Simulating data loss..."
docker exec app-storage-1 mc rb --force myminio/testbucket
docker exec app-storage-1 mc mb myminio/testbucket

# Verify bucket is empty
$files = docker exec app-storage-1 mc ls myminio/testbucket
if ($files) {
    Write-Error "Bucket not empty after simulated data loss!"
    exit 1
}

# Step 5: Restore from Bacula
Write-Host "Running restore job..."
docker cp restore_commands.sh app-bacula-server-1:/tmp/restore_commands.sh
docker exec app-bacula-server-1 sh /tmp/restore_commands.sh

# Wait for restore to complete
Write-Host "Waiting for restore to complete..."
Start-Sleep -Seconds 20

# Step 6: Verify restored files
Write-Host "Verifying restored files..."
$restoredFiles = Get-MinIOFileChecksums

# Compare files
$success = $true
foreach ($initial in $initialFiles) {
    $restored = $restoredFiles | Where-Object { $_.name -eq $initial.name }
    if (-not $restored -or $restored.etag -ne $initial.etag) {
        Write-Host "File mismatch: $($initial.name)"
        $success = $false
    }
}

if ($success) {
    Write-Host "Test passed! All files were successfully backed up and restored."
    Write-Host "Original files:"
    $initialFiles | ForEach-Object { 
        Write-Host "  - $($_.name) (ETag: $($_.etag))"
    }
    Write-Host "Restored files:"
    $restoredFiles | ForEach-Object { 
        Write-Host "  - $($_.name) (ETag: $($_.etag))"
    }
    exit 0
} else {
    Write-Host "Test failed! Files do not match."
    exit 1
}
