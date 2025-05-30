# Simple Integration Test using curl
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Simple Integration Test" -ForegroundColor Green

# Step 1: Restart all services to ensure clean state
Write-Host "🔄 Restarting all services..." -ForegroundColor Yellow
Set-Location "..\docker\app"
docker compose down
Start-Sleep -Seconds 5
docker compose up -d
Start-Sleep -Seconds 30  # Wait for services to be ready
Set-Location "..\..\tests"

# Step 2: Initialize MinIO
Write-Host "🔧 Setting up MinIO..." -ForegroundColor Yellow
docker exec app-storage-1 mc alias set myminio http://localhost:9000 minio minio123
docker exec app-storage-1 mc mb myminio/testbucket --ignore-existing

# Step 3: Create and upload test file using curl
Write-Host "📤 Creating and uploading test file..." -ForegroundColor Yellow
$testContent = "Integration test file created at $(Get-Date)"
$testContent | Out-File -FilePath "test-upload.txt" -Encoding UTF8

# Upload using curl
curl -X POST -F "file=@test-upload.txt" http://localhost:3000/api/upload

# Step 4: Verify file in MinIO
Write-Host "📋 Checking files in MinIO..." -ForegroundColor Yellow
$files = docker exec app-storage-1 mc ls myminio/testbucket
Write-Host "Files in MinIO:"
Write-Host $files

# Step 5: Run Bacula backup
Write-Host "💾 Running Bacula backup..." -ForegroundColor Yellow
docker exec app-bacula-server-1 sh -c 'echo "run job=MinIOBackup yes" | bconsole'

# Wait for backup
Write-Host "⏳ Waiting for backup to complete..."
Start-Sleep -Seconds 30

# Step 6: Simulate data loss
Write-Host "💥 Simulating data loss..." -ForegroundColor Red
docker exec app-storage-1 mc rm --recursive --force myminio/testbucket/

# Verify bucket is empty
$emptyCheck = docker exec app-storage-1 mc ls myminio/testbucket
if (-not $emptyCheck) {
    Write-Host "✅ Bucket is now empty" -ForegroundColor Green
}

# Step 7: Restore from backup
Write-Host "🔄 Restoring from backup..." -ForegroundColor Yellow
@"
restore client=bacula-fd
5
.
yes
mod
"@ | docker exec -i app-bacula-server-1 bconsole

# Wait for restore
Start-Sleep -Seconds 20

# Step 8: Check restore results
Write-Host "🔍 Checking restore results..." -ForegroundColor Yellow
$restoreFiles = docker exec app-bacula-server-1 find /var/lib/bacula/bacula-restores -type f 2>$null
if ($restoreFiles) {
    Write-Host "✅ Files found in restore directory:" -ForegroundColor Green
    Write-Host $restoreFiles
} else {
    Write-Host "❌ No files found in restore directory" -ForegroundColor Red
}

# Cleanup
Remove-Item "test-upload.txt" -Force -ErrorAction SilentlyContinue

Write-Host "🏁 Test completed!" -ForegroundColor Green
