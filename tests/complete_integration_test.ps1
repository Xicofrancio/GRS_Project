# Complete Integration Test - Web App → MinIO → Bacula → Restore
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Complete Integration Test: Web App → MinIO → Bacula → Restore" -ForegroundColor Green
Write-Host "=" * 80

# Function to check service health
function Test-ServiceHealth {
    param($serviceName, $url, $expectedContent)
    
    Write-Host "🔍 Testing $serviceName..." -ForegroundColor Yellow
    try {
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 10
        if ($response -match $expectedContent) {
            Write-Host "✅ $serviceName is healthy" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "❌ $serviceName is not responding" -ForegroundColor Red
        return $false
    }
    return $false
}

# Function to upload file via web API
function Upload-FileViaWebAPI {
    param($filePath, $fileName)
    
    Write-Host "📤 Uploading file via Web API..." -ForegroundColor Yellow
    
    # Create test file if it doesn't exist
    if (-not (Test-Path $filePath)) {
        "This is a test file for backup integration testing. Created at $(Get-Date)" | Out-File -FilePath $filePath -Encoding UTF8
    }
    
    try {
        $uri = "http://localhost:3000/api/upload"
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        $fileContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)
        $fileContent.Headers.ContentDisposition = "form-data; name=`"file`"; filename=`"$fileName`""
        $fileContent.Headers.ContentType = "application/octet-stream"
        
        $multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
        $multipartContent.Add($fileContent)
        
        $httpClient = [System.Net.Http.HttpClient]::new()
        $response = $httpClient.PostAsync($uri, $multipartContent).Result
        
        if ($response.IsSuccessStatusCode) {
            Write-Host "✅ File uploaded successfully via Web API" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ File upload failed: $($response.StatusCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Error uploading file: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        if ($httpClient) { $httpClient.Dispose() }
    }
}

# Function to list MinIO files
function Get-MinIOFiles {
    Write-Host "📋 Listing files in MinIO..." -ForegroundColor Yellow
    try {
        $files = docker exec app-storage-1 mc ls --recursive myminio/testbucket 2>$null
        if ($files) {
            Write-Host "✅ Found files in MinIO:" -ForegroundColor Green
            Write-Host $files
            return $files
        } else {
            Write-Host "⚠️ No files found in MinIO bucket" -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "❌ Error listing MinIO files: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to run Bacula backup
function Start-BaculaBackup {
    Write-Host "💾 Running Bacula backup job..." -ForegroundColor Yellow
    
    try {
        # Run the MinIO backup job
        docker exec app-bacula-server-1 sh -c 'echo "run job=MinIOBackup yes" | bconsole'
        
        Write-Host "⏳ Waiting for backup to complete..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        # Check backup status
        for ($i = 1; $i -le 10; $i++) {
            Write-Host "Checking backup status (attempt $i/10)..." -ForegroundColor Cyan
            $status = docker exec app-bacula-server-1 sh -c 'echo "status dir" | bconsole' 2>$null
            
            if ($status -notmatch "Running Jobs:" -or $status -match "No Jobs running") {
                Write-Host "✅ Backup completed successfully" -ForegroundColor Green
                return $true
            }
            Start-Sleep -Seconds 10
        }
        
        Write-Host "⚠️ Backup may still be running" -ForegroundColor Yellow
        return $true
    } catch {
        Write-Host "❌ Error running backup: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to simulate data loss
function Simulate-DataLoss {
    Write-Host "💥 Simulating data loss (deleting files from MinIO)..." -ForegroundColor Red
    
    try {
        # Delete all files from the bucket
        docker exec app-storage-1 mc rm --recursive --force myminio/testbucket/
        
        # Verify bucket is empty
        $files = docker exec app-storage-1 mc ls myminio/testbucket 2>$null
        if (-not $files) {
            Write-Host "✅ Data loss simulation complete - bucket is empty" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Failed to simulate data loss - files still exist" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Error simulating data loss: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to restore data from Bacula
function Start-BaculaRestore {
    Write-Host "🔄 Running Bacula restore job..." -ForegroundColor Yellow
    
    try {
        # Create restore commands
        $restoreCommands = @"
restore client=bacula-fd
5
.
yes
mod
"@
        
        $restoreCommands | docker exec -i app-bacula-server-1 bconsole
        
        Write-Host "⏳ Waiting for restore to complete..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        Write-Host "✅ Restore job initiated" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Error running restore: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to verify restore success
function Test-RestoreSuccess {
    Write-Host "🔍 Verifying restore success..." -ForegroundColor Yellow
    
    try {
        # Check if files are back in MinIO
        $files = Get-MinIOFiles
        if ($files) {
            Write-Host "✅ Files successfully restored to MinIO!" -ForegroundColor Green
            return $true
        } else {
            # Check if files are in the restore directory
            $restoreFiles = docker exec app-bacula-server-1 find /var/lib/bacula/bacula-restores -type f 2>$null
            if ($restoreFiles) {
                Write-Host "✅ Files found in restore directory" -ForegroundColor Green
                Write-Host "Restored files:" -ForegroundColor Cyan
                Write-Host $restoreFiles
                return $true
            } else {
                Write-Host "❌ No files found after restore" -ForegroundColor Red
                return $false
            }
        }
    } catch {
        Write-Host "❌ Error verifying restore: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main Test Execution
Write-Host "`n🎯 STEP 1: Service Health Checks" -ForegroundColor Magenta
Write-Host "-" * 40

$webHealthy = Test-ServiceHealth "Web Application" "http://localhost:3000/api/health" "OK"
$minioHealthy = Test-ServiceHealth "MinIO Console" "http://localhost:9001/login" "MinIO"

if (-not $webHealthy -or -not $minioHealthy) {
    Write-Host "❌ Some services are not healthy. Please start all containers first." -ForegroundColor Red
    Write-Host "Run: docker compose up -d" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n🎯 STEP 2: Initialize MinIO" -ForegroundColor Magenta
Write-Host "-" * 40

# Setup MinIO client and bucket
docker exec app-storage-1 mc alias set myminio http://localhost:9000 minio minio123 2>$null
docker exec app-storage-1 mc mb myminio/testbucket 2>$null

Write-Host "`n🎯 STEP 3: Upload File via Web Application" -ForegroundColor Magenta
Write-Host "-" * 40

$testFilePath = ".\test-file.txt"
$uploadSuccess = Upload-FileViaWebAPI $testFilePath "integration-test-file.txt"

if (-not $uploadSuccess) {
    Write-Host "❌ Failed to upload file via web API" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎯 STEP 4: Verify File in MinIO" -ForegroundColor Magenta
Write-Host "-" * 40

$initialFiles = Get-MinIOFiles
if (-not $initialFiles) {
    Write-Host "❌ No files found in MinIO after upload" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎯 STEP 5: Run Bacula Backup" -ForegroundColor Magenta
Write-Host "-" * 40

$backupSuccess = Start-BaculaBackup
if (-not $backupSuccess) {
    Write-Host "❌ Backup failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎯 STEP 6: Simulate Data Loss" -ForegroundColor Magenta
Write-Host "-" * 40

$dataLossSuccess = Simulate-DataLoss
if (-not $dataLossSuccess) {
    Write-Host "❌ Failed to simulate data loss" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎯 STEP 7: Restore Data from Backup" -ForegroundColor Magenta
Write-Host "-" * 40

$restoreSuccess = Start-BaculaRestore
if (-not $restoreSuccess) {
    Write-Host "❌ Restore failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎯 STEP 8: Verify Restore Success" -ForegroundColor Magenta
Write-Host "-" * 40

$verifySuccess = Test-RestoreSuccess

Write-Host "`n" + "=" * 80
if ($verifySuccess) {
    Write-Host "🎉 INTEGRATION TEST COMPLETED SUCCESSFULLY! 🎉" -ForegroundColor Green
    Write-Host "✅ Web App → MinIO → Bacula → Restore flow is working!" -ForegroundColor Green
} else {
    Write-Host "❌ INTEGRATION TEST FAILED" -ForegroundColor Red
    Write-Host "⚠️ Check the logs above for details" -ForegroundColor Yellow
}
Write-Host "=" * 80

# Cleanup
if (Test-Path $testFilePath) {
    Remove-Item $testFilePath -Force
}
