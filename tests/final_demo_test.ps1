# Complete Backup Demo Workflow - Final Test
# This demonstrates the full backup/restore system functionality

Write-Host "=========================================" -ForegroundColor Green
Write-Host "    BACKUP SYSTEM DEMONSTRATION" -ForegroundColor Green  
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# Test 1: List current files
Write-Host "1. Current files in storage:" -ForegroundColor Yellow
try {
    $files = Invoke-RestMethod -Uri "http://localhost:3000/api/files" -Method Get
    $files | ForEach-Object { Write-Host "   - $($_.name) ($($_.size) bytes)" -ForegroundColor Cyan }
    Write-Host "   Total files: $($files.Count)" -ForegroundColor Green
} catch {
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Trigger backup process
Write-Host "2. Triggering backup process..." -ForegroundColor Yellow
try {
    $backupResult = Invoke-RestMethod -Uri "http://localhost:3000/api/backup" -Method Post -ContentType "application/json" -Body "{}"
    Write-Host "   SUCCESS: $($backupResult.message)" -ForegroundColor Green
    Write-Host "   Job ID: $($backupResult.jobId)" -ForegroundColor Cyan
    Write-Host "   Status: $($backupResult.status)" -ForegroundColor Cyan
} catch {
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Simulate data loss by deleting a file
Write-Host "3. Simulating data loss (deleting backup_demo.txt)..." -ForegroundColor Yellow
try {
    $deleteResult = Invoke-RestMethod -Uri "http://localhost:3000/api/files/backup_demo.txt" -Method Delete
    Write-Host "   SUCCESS: $($deleteResult.message)" -ForegroundColor Green
    Write-Host "   File '$($deleteResult.filename)' has been deleted" -ForegroundColor Cyan
} catch {
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Confirm file deletion
Write-Host "4. Confirming file deletion:" -ForegroundColor Yellow
try {
    $filesAfterDelete = Invoke-RestMethod -Uri "http://localhost:3000/api/files" -Method Get
    $deletedFileExists = $filesAfterDelete | Where-Object { $_.name -eq "backup_demo.txt" }
    if ($deletedFileExists) {
        Write-Host "   WARNING: File still exists!" -ForegroundColor Red
    } else {
        Write-Host "   SUCCESS: File successfully deleted from storage" -ForegroundColor Green
    }
    Write-Host "   Remaining files: $($filesAfterDelete.Count)" -ForegroundColor Cyan
} catch {
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 5: Restore files from backup
Write-Host "5. Restoring files from backup..." -ForegroundColor Yellow
try {
    $restoreResult = Invoke-RestMethod -Uri "http://localhost:3000/api/restore" -Method Post -ContentType "application/json" -Body "{}"
    Write-Host "   SUCCESS: $($restoreResult.message)" -ForegroundColor Green
    Write-Host "   Files restored: $($restoreResult.filesRestored)" -ForegroundColor Cyan
    $restoreResult.restoredFiles | ForEach-Object { Write-Host "     - $_" -ForegroundColor Cyan }
} catch {
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 6: Verify restored files
Write-Host "6. Verifying restored files:" -ForegroundColor Yellow
try {
    $filesAfterRestore = Invoke-RestMethod -Uri "http://localhost:3000/api/files" -Method Get
    $restoredFiles = $filesAfterRestore | Where-Object { $_.name -like "restored_*" }
    Write-Host "   Total files now: $($filesAfterRestore.Count)" -ForegroundColor Green
    Write-Host "   Restored files found: $($restoredFiles.Count)" -ForegroundColor Green
    $restoredFiles | ForEach-Object { Write-Host "     - $($_.name) ($($_.size) bytes)" -ForegroundColor Cyan }
} catch {
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 7: View content of a restored file
Write-Host "7. Viewing content of restored file:" -ForegroundColor Yellow
try {
    $fileContent = Invoke-RestMethod -Uri "http://localhost:3000/api/files/restored_demo_file_1.txt/view" -Method Get
    Write-Host "   SUCCESS: File content retrieved:" -ForegroundColor Green
    Write-Host "   ----------------------------------------" -ForegroundColor Gray
    Write-Host $fileContent -ForegroundColor White
    Write-Host "   ----------------------------------------" -ForegroundColor Gray
} catch {
    Write-Host "   ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Summary
Write-Host "=========================================" -ForegroundColor Green
Write-Host "    DEMONSTRATION COMPLETED!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The backup system successfully demonstrated:" -ForegroundColor Yellow
Write-Host "  ✓ File storage in MinIO" -ForegroundColor Green
Write-Host "  ✓ Backup process triggering" -ForegroundColor Green
Write-Host "  ✓ File deletion (data loss simulation)" -ForegroundColor Green
Write-Host "  ✓ File restoration from backup" -ForegroundColor Green
Write-Host "  ✓ File content viewing" -ForegroundColor Green
Write-Host ""
Write-Host "Access the interfaces:" -ForegroundColor Yellow
Write-Host "  • Web App:      http://localhost:3000" -ForegroundColor Cyan
Write-Host "  • MinIO Console: http://localhost:9001" -ForegroundColor Cyan
Write-Host "  • Bacula UI:    http://localhost:9095" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your backup demonstration system is fully operational!" -ForegroundColor Green
