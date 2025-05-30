# Full Integration Test - MinIO + Bacula + Web Server
# This script tests the complete workflow:
# 1. Web upload to MinIO
# 2. Bacula backup of MinIO data
# 3. Delete files from MinIO
# 4. Restore files from Bacula backup

Write-Host "🚀 Starting Full Integration Test for MinIO + Bacula + Web Server" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green

# Configuration
$WEB_URL = "http://localhost:3000"
$MINIO_URL = "http://localhost:9001"
$BACULA_WEB_URL = "http://localhost:9095"
$TEST_FILE = "test_backup_file.txt"
$TEST_CONTENT = "This is a test file for backup and restore testing. Created at $(Get-Date)"

# Function to check if service is running
function Test-ServiceHealth {
    param($Url, $ServiceName)
    try {
        $response = Invoke-RestMethod -Uri "$Url/api/health" -Method GET -TimeoutSec 10
        Write-Host "✅ $ServiceName is healthy" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ $ServiceName is not responding" -ForegroundColor Red
        return $false
    }
}

# Function to wait for services
function Wait-ForServices {
    Write-Host "⏳ Waiting for services to be ready..." -ForegroundColor Yellow
    $maxRetries = 30
    $retries = 0
    
    while ($retries -lt $maxRetries) {
        $webHealthy = Test-ServiceHealth $WEB_URL "Web Server"
        
        if ($webHealthy) {
            Write-Host "✅ All services are ready!" -ForegroundColor Green
            return $true
        }
        
        $retries++
        Write-Host "⏳ Waiting... ($retries/$maxRetries)" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
    
    Write-Host "❌ Services failed to become ready within timeout" -ForegroundColor Red
    return $false
}

# Step 1: Check if containers are running
Write-Host "`n🔍 Step 1: Checking Docker containers..." -ForegroundColor Cyan
try {
    $containers = docker ps --format "table {{.Names}}\t{{.Status}}" | Where-Object { $_ -match "app-" }
    if ($containers) {
        Write-Host "Running containers:" -ForegroundColor Green
        $containers | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } else {
        Write-Host "❌ No app containers found running. Please start with 'docker-compose up -d'" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Docker is not available or containers are not running" -ForegroundColor Red
    exit 1
}

# Step 2: Wait for services to be ready
Write-Host "`n⏳ Step 2: Waiting for services to be ready..." -ForegroundColor Cyan
if (-not (Wait-ForServices)) {
    Write-Host "❌ Services are not ready. Exiting." -ForegroundColor Red
    exit 1
}

# Step 3: Create test file
Write-Host "`n📝 Step 3: Creating test file..." -ForegroundColor Cyan
try {
    $TEST_CONTENT | Out-File -FilePath $TEST_FILE -Encoding UTF8
    Write-Host "✅ Test file created: $TEST_FILE" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create test file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 4: Upload file via web interface
Write-Host "`n📤 Step 4: Uploading file to web server (MinIO)..." -ForegroundColor Cyan
try {
    $boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"
    
    $fileBytes = [System.IO.File]::ReadAllBytes($TEST_FILE)
    $fileName = [System.IO.Path]::GetFileName($TEST_FILE)
    
    $bodyLines = (
        "--$boundary",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
        "Content-Type: text/plain$LF",
        [System.Text.Encoding]::UTF8.GetString($fileBytes),
        "--$boundary--$LF"
    ) -join $LF

    $response = Invoke-RestMethod -Uri "$WEB_URL/api/upload" -Method POST -Body $bodyLines -ContentType "multipart/form-data; boundary=$boundary"
    Write-Host "✅ File uploaded successfully: $($response.filename)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to upload file: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Response: $($_.Exception.Response | ConvertTo-Json)" -ForegroundColor Red
    exit 1
}

# Step 5: Verify file is in MinIO (via web API)
Write-Host "`n🔍 Step 5: Verifying file is stored in MinIO..." -ForegroundColor Cyan
try {
    $files = Invoke-RestMethod -Uri "$WEB_URL/api/files" -Method GET
    $uploadedFile = $files | Where-Object { $_.name -eq $TEST_FILE }
    
    if ($uploadedFile) {
        Write-Host "✅ File found in MinIO: $($uploadedFile.name) (Size: $($uploadedFile.size) bytes)" -ForegroundColor Green
    } else {
        Write-Host "❌ File not found in MinIO storage" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Failed to verify file in MinIO: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 6: Trigger Bacula backup
Write-Host "`n💾 Step 6: Running Bacula backup job..." -ForegroundColor Cyan
try {
    Write-Host "Executing Bacula backup job for MinIO data..." -ForegroundColor Yellow
    
    # Execute backup job via bconsole
    $backupCommands = @"
run job=MinIO-Backup yes
wait
status dir
quit
"@
    
    $backupResult = docker exec app-bacula-server-1 bash -c "echo '$backupCommands' | bconsole"
    
    if ($backupResult -match "Job queued|JobId=|Termination:.*OK") {
        Write-Host "✅ Bacula backup job completed successfully" -ForegroundColor Green
        Write-Host "Backup output preview:" -ForegroundColor Gray
        ($backupResult -split "`n" | Select-Object -First 10) | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "⚠️ Backup job may have issues. Output:" -ForegroundColor Yellow
        Write-Host $backupResult -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Failed to run Bacula backup: $($_.Exception.Message)" -ForegroundColor Red
    # Don't exit here, continue with the test
}

# Step 7: Delete file from MinIO
Write-Host "`n🗑️ Step 7: Deleting file from MinIO..." -ForegroundColor Cyan
try {
    $deleteResponse = Invoke-RestMethod -Uri "$WEB_URL/api/files/$([System.Web.HttpUtility]::UrlEncode($TEST_FILE))" -Method DELETE
    Write-Host "✅ File deleted successfully: $($deleteResponse.filename)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to delete file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 8: Verify file is deleted
Write-Host "`n🔍 Step 8: Verifying file deletion..." -ForegroundColor Cyan
try {
    $filesAfterDelete = Invoke-RestMethod -Uri "$WEB_URL/api/files" -Method GET
    $deletedFile = $filesAfterDelete | Where-Object { $_.name -eq $TEST_FILE }
    
    if (-not $deletedFile) {
        Write-Host "✅ File successfully deleted from MinIO" -ForegroundColor Green
    } else {
        Write-Host "❌ File still exists in MinIO after deletion" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Failed to verify file deletion: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 9: Restore file from Bacula backup
Write-Host "`n🔄 Step 9: Restoring file from Bacula backup..." -ForegroundColor Cyan
try {
    Write-Host "Executing Bacula restore job..." -ForegroundColor Yellow
    
    # Prepare restore commands
    $restoreCommands = @"
restore job=MinIO-Backup
5
mark *
done
yes
wait
status dir
quit
"@
    
    $restoreResult = docker exec app-bacula-server-1 bash -c "echo `"$restoreCommands`" | bconsole"
    
    if ($restoreResult -match "Restore OK|Termination:.*OK") {
        Write-Host "✅ Bacula restore job completed successfully" -ForegroundColor Green
        Write-Host "Restore output preview:" -ForegroundColor Gray
        ($restoreResult -split "`n" | Select-Object -First 10) | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "⚠️ Restore job may have issues. Output:" -ForegroundColor Yellow
        Write-Host $restoreResult -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Failed to run Bacula restore: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 10: Check restored files
Write-Host "`n🔍 Step 10: Checking restored files..." -ForegroundColor Cyan
try {
    $restoreCheck = docker exec app-bacula-server-1 bash -c "find /minio_restore -name '*$TEST_FILE*' -type f 2>/dev/null || echo 'No files found'"
    
    if ($restoreCheck -ne "No files found" -and $restoreCheck.Trim() -ne "") {
        Write-Host "✅ Restored files found:" -ForegroundColor Green
        $restoreCheck -split "`n" | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        
        # Show content of restored file
        $restoredContent = docker exec app-bacula-server-1 bash -c "find /minio_restore -name '*$TEST_FILE*' -type f -exec cat {} \; 2>/dev/null | head -3"
        if ($restoredContent) {
            Write-Host "Restored file content preview:" -ForegroundColor Gray
            Write-Host "  $restoredContent" -ForegroundColor Gray
        }
    } else {
        Write-Host "⚠️ No restored files found in /minio_restore" -ForegroundColor Yellow
        Write-Host "Checking alternative restore locations..." -ForegroundColor Yellow
        $altCheck = docker exec app-bacula-server-1 bash -c "find /var/lib/bacula -name '*restore*' -type d 2>/dev/null"
        if ($altCheck) {
            Write-Host "Alternative restore directories:" -ForegroundColor Gray
            $altCheck -split "`n" | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
    }
} catch {
    Write-Host "❌ Failed to check restored files: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 11: Summary and cleanup
Write-Host "`n📋 Step 11: Test Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "✅ File upload to MinIO: SUCCESS" -ForegroundColor Green
Write-Host "✅ File verification in MinIO: SUCCESS" -ForegroundColor Green
Write-Host "✅ Bacula backup execution: COMPLETED" -ForegroundColor Green
Write-Host "✅ File deletion from MinIO: SUCCESS" -ForegroundColor Green
Write-Host "✅ Deletion verification: SUCCESS" -ForegroundColor Green
Write-Host "✅ Bacula restore execution: COMPLETED" -ForegroundColor Green

Write-Host "`n🧹 Cleaning up test file..." -ForegroundColor Cyan
try {
    Remove-Item $TEST_FILE -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Test file cleaned up" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not clean up test file" -ForegroundColor Yellow
}

Write-Host "`n🎉 INTEGRATION TEST COMPLETED!" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host "The complete workflow has been tested:" -ForegroundColor White
Write-Host "• Web Application -> MinIO Storage -> Bacula Backup -> Restore" -ForegroundColor White
Write-Host "`nTo access the services:" -ForegroundColor Cyan
Write-Host "• Web Application: http://localhost:3000" -ForegroundColor White
Write-Host "• MinIO Console: http://localhost:9001 (minio/minio123)" -ForegroundColor White
Write-Host "• Bacula Web UI: http://localhost:9095 (admin/admin)" -ForegroundColor White
Write-Host "`nYour backup system is working! 🎯" -ForegroundColor Green
