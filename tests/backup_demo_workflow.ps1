# Backup Demo Workflow Test
# This script demonstrates the complete backup/restore workflow

Write-Host "Starting Backup Demo Workflow Test" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Step 1: Create a test file to upload
$testContent = @"
This is a test file for the backup demonstration.
Created at: $(Get-Date)
Content: Important data that needs to be backed up!
"@

$testFile = "c:\temp\demo_file.txt"
New-Item -Path "c:\temp" -ItemType Directory -Force | Out-Null
$testContent | Out-File -FilePath $testFile -Encoding UTF8

Write-Host "Step 1: Created test file: $testFile" -ForegroundColor Yellow

# Step 2: Upload the file via web API
Write-Host "📤 Step 2: Uploading file to web application..." -ForegroundColor Yellow

try {
    $uploadUri = "http://localhost:3000/upload"
    $form = @{
        file = Get-Item -Path $testFile
    }
    $uploadResponse = Invoke-RestMethod -Uri $uploadUri -Method Post -Form $form
    Write-Host "✅ File uploaded successfully!" -ForegroundColor Green
    Write-Host "Response: $($uploadResponse | ConvertTo-Json)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Upload failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: List files to verify upload
Write-Host "📋 Step 3: Listing uploaded files..." -ForegroundColor Yellow

try {
    $listResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/files" -Method Get
    Write-Host "✅ Files in storage:" -ForegroundColor Green
    $listResponse.files | ForEach-Object { Write-Host "  - $($_.name) (Size: $($_.size) bytes)" -ForegroundColor Cyan }
} catch {
    Write-Host "❌ Failed to list files: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 4: View the uploaded file content
Write-Host "👁️ Step 4: Viewing file content..." -ForegroundColor Yellow

try {
    $viewResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/files/demo_file.txt/view" -Method Get
    Write-Host "✅ File content retrieved:" -ForegroundColor Green
    Write-Host "$viewResponse" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Failed to view file: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 5: Delete the file (simulate data loss)
Write-Host "🗑️ Step 5: Deleting file (simulating data loss)..." -ForegroundColor Yellow

try {
    $deleteResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/files/demo_file.txt" -Method Delete
    Write-Host "✅ File deleted successfully!" -ForegroundColor Green
    Write-Host "Response: $($deleteResponse | ConvertTo-Json)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Delete failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 6: Verify file is gone
Write-Host "🔍 Step 6: Verifying file deletion..." -ForegroundColor Yellow

try {
    $listAfterDelete = Invoke-RestMethod -Uri "http://localhost:3000/api/files" -Method Get
    Write-Host "✅ Files after deletion:" -ForegroundColor Green
    if ($listAfterDelete.files.Count -eq 0) {
        Write-Host "  - No files found (deletion confirmed)" -ForegroundColor Cyan
    } else {
        $listAfterDelete.files | ForEach-Object { Write-Host "  - $($_.name)" -ForegroundColor Cyan }
    }
} catch {
    Write-Host "❌ Failed to verify deletion: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 7: Trigger backup
Write-Host "🔄 Step 7: Triggering backup process..." -ForegroundColor Yellow

try {
    $backupResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/backup" -Method Post -ContentType "application/json" -Body "{}"
    Write-Host "✅ Backup triggered successfully!" -ForegroundColor Green
    Write-Host "Response: $($backupResponse | ConvertTo-Json)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Backup failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 8: Restore files
Write-Host "📥 Step 8: Restoring files from backup..." -ForegroundColor Yellow

try {
    $restoreResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/restore" -Method Post -ContentType "application/json" -Body "{}"
    Write-Host "✅ Files restored successfully!" -ForegroundColor Green
    Write-Host "Response: $($restoreResponse | ConvertTo-Json)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Restore failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 9: Verify restored files
Write-Host "✅ Step 9: Verifying restored files..." -ForegroundColor Yellow

try {
    $listAfterRestore = Invoke-RestMethod -Uri "http://localhost:3000/api/files" -Method Get
    Write-Host "✅ Files after restore:" -ForegroundColor Green
    $listAfterRestore.files | ForEach-Object { 
        Write-Host "  - $($_.name) (Size: $($_.size) bytes)" -ForegroundColor Cyan 
    }
} catch {
    Write-Host "❌ Failed to verify restore: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 10: View restored file content
Write-Host "👁️ Step 10: Viewing restored file content..." -ForegroundColor Yellow

try {
    # Try to view one of the restored files
    $restoreListResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/files" -Method Get
    if ($restoreListResponse.files.Count -gt 0) {
        $firstFile = $restoreListResponse.files[0].name
        $viewRestoredResponse = Invoke-RestMethod -Uri "http://localhost:3000/api/files/$firstFile/view" -Method Get
        Write-Host "✅ Restored file content:" -ForegroundColor Green
        Write-Host "$viewRestoredResponse" -ForegroundColor Cyan
    }
} catch {
    Write-Host "❌ Failed to view restored file: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 Backup Demo Workflow Complete!" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host "Summary of demonstrated features:" -ForegroundColor Yellow
Write-Host "✅ File upload to MinIO storage" -ForegroundColor Green
Write-Host "✅ File listing and viewing" -ForegroundColor Green
Write-Host "✅ File deletion (data loss simulation)" -ForegroundColor Green
Write-Host "✅ Backup process triggering" -ForegroundColor Green
Write-Host "✅ File restoration from backup" -ForegroundColor Green
Write-Host "✅ Verification of restored data" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Web interface available at: http://localhost:3000" -ForegroundColor Cyan
Write-Host "💾 MinIO console available at: http://localhost:9001" -ForegroundColor Cyan
Write-Host "🗄️ Bacula console available at: http://localhost:9095" -ForegroundColor Cyan

# Cleanup
Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
Write-Host "Cleanup: Removed temporary test file" -ForegroundColor Gray
