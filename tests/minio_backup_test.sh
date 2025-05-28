#!/bin/bash

set -e

echo "🔄 Starting MinIO + Bacula backup and restore test..."

# Function to wait for files in MinIO bucket
wait_for_minio_files() {
    echo "👀 Monitoring MinIO bucket for files..."
    max_attempts=30
    attempt=0
    has_files=false

    while [ $attempt -lt $max_attempts ]; do
        if docker exec app-storage-1 mc ls myminio/testbucket 2>/dev/null; then
            has_files=true
            break
        fi
        attempt=$((attempt + 1))
        echo "Waiting for files... (attempt $attempt of $max_attempts)"
        sleep 10
    done

    if [ "$has_files" = false ]; then
        echo "No files found in MinIO bucket after timeout"
        exit 1
    fi

    echo "✅ Files detected in MinIO bucket!"
}

# Function to get MinIO file checksums
get_minio_checksums() {
    docker exec app-storage-1 sh -c 'mc ls --recursive myminio/testbucket --json' | jq -r '.[] | "\(.key):\(.etag)"'
}

# Step 1: Wait for files in MinIO bucket
wait_for_minio_files

# Step 2: Get initial file checksums
echo "📝 Recording initial file state..."
INITIAL_FILES=$(get_minio_checksums)

# Step 3: Run Bacula backup
echo "📦 Running Bacula backup job..."
docker exec app-bacula-server-1 sh -c 'echo "run job=BackupClient1 yes" | bconsole'

# Wait for backup to complete
echo "⏳ Waiting for backup to complete..."
sleep 20

# Check backup status
echo "🔍 Checking backup status..."
for i in {1..6}; do
    status=$(docker exec app-bacula-server-1 sh -c 'echo "status dir" | bconsole')
    if ! echo "$status" | grep -q "Running Jobs:"; then
        echo "✅ Backup completed"
        break
    fi
    echo "Backup still running, waiting..."
    sleep 10
done

# Show backup messages
docker exec app-bacula-server-1 sh -c 'echo "messages" | bconsole'

# Step 4: Simulate data loss
echo "🗑️ Simulating data loss..."
docker exec app-storage-1 mc rb --force myminio/testbucket
docker exec app-storage-1 mc mb myminio/testbucket

# Verify bucket is empty
if docker exec app-storage-1 mc ls myminio/testbucket 2>/dev/null | grep -q .; then
    echo "Bucket not empty after simulated data loss!"
    exit 1
fi

# Step 5: Restore from Bacula
echo "🔄 Running restore job..."
docker exec app-bacula-server-1 sh -c 'printf "restore client=bacula-fd\n5\n.\nyes\nmod\n" | bconsole'

# Wait for restore to complete
echo "⏳ Waiting for restore to complete..."
sleep 20

# Step 6: Verify restored files
echo "🔍 Verifying restored files..."
RESTORED_FILES=$(get_minio_checksums)

# Compare files
if [ "$INITIAL_FILES" = "$RESTORED_FILES" ]; then
    echo "✅ Test passed! All files were successfully backed up and restored."
    echo "📝 Original files:"
    echo "$INITIAL_FILES" | while IFS=: read -r file etag; do
        echo "  - $file (ETag: $etag)"
    done
    echo "📝 Restored files:"
    echo "$RESTORED_FILES" | while IFS=: read -r file etag; do
        echo "  - $file (ETag: $etag)"
    done
    exit 0
else
    echo "❌ Test failed! Some files were not restored correctly."
    echo "Original files:"
    echo "$INITIAL_FILES"
    echo "Restored files:"
    echo "$RESTORED_FILES"
    exit 1
fi
