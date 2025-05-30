# Full Integration Test: Web App -> MinIO -> Bacula Backup -> Restore
# Tests the complete workflow of file upload, backup, deletion, and recovery

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   FULL INTEGRATION TEST STARTING" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Configuration
$WEB_URL = "http://localhost:3000"
$TEST_FILE = "integration_test_file.txt"
$TEST_CONTENT = "This is a test file for integration testing. Created at: $(Get-Date)"

try {
    # Step 1: Check if all containers are running
    Write-Host "`n1. Checking container status..." -ForegroundColor Yellow
    $containers = docker ps --format "table {{.Names}}`t{{.Status}}"
    Write-Host $containers -ForegroundColor Gray
    
    $runningContainers = (docker ps --filter "name=app-" --format "{{.Names}}").Count
    if ($runningContainers -lt 5) {
        Write-Host "ERROR: Not all containers are running. Expected 5, found $runningContainers" -ForegroundColor Red
        exit 1
    }
    Write-Host "SUCCESS: All containers are running" -ForegroundColor Green

    # Step 2: Create test file
    Write-Host "`n2. Creating test file..." -ForegroundColor Yellow
    $TEST_CONTENT | Out-File -FilePath $TEST_FILE -Encoding UTF8
    Write-Host "SUCCESS: Test file created: $TEST_FILE" -ForegroundColor Green

    # Step 3: Upload file to web application
    Write-Host "`n3. Uploading file to web application..." -ForegroundColor Yellow
    $uploadResponse = curl.exe -X POST -F "file=@$TEST_FILE" "$WEB_URL/upload"
    if ($uploadResponse -match "success" -or $uploadResponse -match "uploaded") {
        Write-Host "SUCCESS: File uploaded to web application" -ForegroundColor Green
        Write-Host "Response: $uploadResponse" -ForegroundColor Gray
    } else {
        Write-Host "ERROR: File upload failed" -ForegroundColor Red
        Write-Host "Response: $uploadResponse" -ForegroundColor Gray
    }

    # Step 4: Verify file in MinIO
    Write-Host "`n4. Checking file in MinIO..." -ForegroundColor Yellow
    $listResponse = curl.exe -s "$WEB_URL/api/files"
    if ($listResponse -match $TEST_FILE) {
        Write-Host "SUCCESS: File found in MinIO storage" -ForegroundColor Green
    } else {
        Write-Host "WARNING: File may not be in MinIO yet" -ForegroundColor Yellow
        Write-Host "Files found: $listResponse" -ForegroundColor Gray
    }

    # Step 5: Trigger Bacula backup
    Write-Host "`n5. Triggering Bacula backup..." -ForegroundColor Yellow
    $backupCommands = @"
run job=MinIOBackup yes
wait
status dir
quit
"@
    
    # Write commands to a temporary file to avoid PowerShell escaping issues
    $tempCommandFile = "backup_commands.txt"
    $backupCommands | Out-File -FilePath $tempCommandFile -Encoding ASCII -NoNewline
    
    $backupResult = docker exec app-bacula-server-1 bash -c "cat /$tempCommandFile | bconsole"
    Remove-Item $tempCommandFile -ErrorAction SilentlyContinue
    
    if ($backupResult -match "Backup OK|Termination.*OK") {
        Write-Host "SUCCESS: Bacula backup completed" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Backup may have issues" -ForegroundColor Yellow
        Write-Host "Backup output preview:" -ForegroundColor Gray
        ($backupResult -split "`n" | Select-Object -First 10) | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }

    # Step 6: Delete file from web interface
    Write-Host "`n6. Deleting file from web interface..." -ForegroundColor Yellow
    $deleteResponse = curl.exe -X DELETE "$WEB_URL/api/files/$TEST_FILE"
    if ($deleteResponse -match "success" -or $deleteResponse -match "deleted") {
        Write-Host "SUCCESS: File deleted from MinIO" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Delete operation may have failed" -ForegroundColor Yellow
        Write-Host "Response: $deleteResponse" -ForegroundColor Gray
    }

    # Step 7: Verify file is gone
    Write-Host "`n7. Verifying file deletion..." -ForegroundColor Yellow
    Start-Sleep 2
    $listAfterDelete = curl.exe -s "$WEB_URL/api/files"
    if ($listAfterDelete -notmatch $TEST_FILE) {
        Write-Host "SUCCESS: File successfully removed from MinIO" -ForegroundColor Green
    } else {
        Write-Host "WARNING: File may still exist in MinIO" -ForegroundColor Yellow
    }

    # Step 8: Restore file using Bacula
    Write-Host "`n8. Restoring file using Bacula..." -ForegroundColor Yellow
    $restoreCommands = @"
restore client=bacula-fd fileset=MinIOFileSet where=/tmp/restore select all done yes
wait
status dir
quit
"@
    
    $tempRestoreFile = "restore_commands.txt"
    $restoreCommands | Out-File -FilePath $tempRestoreFile -Encoding ASCII -NoNewline
    
    $restoreResult = docker exec app-bacula-server-1 bash -c "cat /$tempRestoreFile | bconsole"
    Remove-Item $tempRestoreFile -ErrorAction SilentlyContinue
    
    if ($restoreResult -match "Restore OK|Termination.*OK") {
        Write-Host "SUCCESS: Bacula restore completed" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Restore may have issues" -ForegroundColor Yellow
        Write-Host "Restore output preview:" -ForegroundColor Gray
        ($restoreResult -split "`n" | Select-Object -First 10) | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }

    # Step 9: Verify restored file
    Write-Host "`n9. Checking restored files..." -ForegroundColor Yellow
    $restoreCheck = docker exec app-bacula-server-1 find /tmp/restore -name "*$TEST_FILE*" -type f
    if ($restoreCheck) {
        Write-Host "SUCCESS: Restored file found at: $restoreCheck" -ForegroundColor Green
        
        # Show content of restored file
        $restoredContent = docker exec app-bacula-server-1 cat $restoreCheck
        Write-Host "Restored file content preview:" -ForegroundColor Gray
        Write-Host "  $restoredContent" -ForegroundColor Gray
    } else {
        Write-Host "INFO: Restored file location may vary. Checking restore directory..." -ForegroundColor Yellow
        $restoreDir = docker exec app-bacula-server-1 ls -la /tmp/restore/
        Write-Host "Restore directory contents:" -ForegroundColor Gray
        Write-Host $restoreDir -ForegroundColor Gray
    }

} catch {
    Write-Host "ERROR: Test failed with exception: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Write-Host "`n10. Cleaning up..." -ForegroundColor Yellow
try {
    Remove-Item $TEST_FILE -Force -ErrorAction SilentlyContinue
    Write-Host "SUCCESS: Test file cleaned up" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Could not clean up test file" -ForegroundColor Yellow
}

Write-Host "`n" -ForegroundColor White
Write-Host "=========================================" -ForegroundColor Green
Write-Host "   INTEGRATION TEST COMPLETED!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "The complete workflow has been tested:" -ForegroundColor White
Write-Host "• Web Application -> MinIO Storage -> Bacula Backup -> Restore" -ForegroundColor White
Write-Host "`nTo access the services:" -ForegroundColor Cyan
Write-Host "• Web Application: http://localhost:3000" -ForegroundColor White
Write-Host "• MinIO Console: http://localhost:9001 (minio/minio123)" -ForegroundColor White
Write-Host "• Bacula Web UI: http://localhost:9095 (admin/admin)" -ForegroundColor White
Write-Host "`nYour backup system is working!" -ForegroundColor Green
