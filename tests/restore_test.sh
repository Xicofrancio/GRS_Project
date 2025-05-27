#!/bin/bash

set -e

echo "Starting Bacula backup and restore test..."

# Create test data directory and files
echo "Creating test data..."
docker exec app-bacula-server-1 sh -c 'mkdir -p /data && echo "test file 1" > /data/file1.txt && echo "test file 2" > /data/file2.txt'

# Step 1: Execute backup
echo "Running backup job..."
docker exec app-bacula-server-1 sh -c 'echo "run job=BackupClient1 yes" | bconsole'

# Wait for backup to complete and verify backup files
echo "Waiting for backup to complete..."
sleep 20  # Give more time for the backup to complete

# Check backup status and wait for completion
echo "Checking backup status..."
for i in {1..6}; do
    status=$(docker exec app-bacula-server-1 sh -c 'echo "status dir" | bconsole')
    if ! echo "$status" | grep -q "Running Jobs:"; then
        echo "Backup completed"
        break
    fi
    echo "Backup still running, waiting..."
    sleep 10
done

# Show final messages
docker exec app-bacula-server-1 sh -c 'echo "messages" | bconsole'

# Verify backup directory exists
echo "Verifying backup directory..."
docker exec app-bacula-server-1 ls -l /mnt/bacula/ || {
    echo "Backup directory not accessible!"
    exit 1
}

# Calculate checksums of original data
echo "Calculating original data checksums..."
ORIGINAL_CHECKSUM=$(docker exec app-bacula-server-1 find /data -type f -exec md5sum {} \; | sort)

# Step 2: Simulate data loss
echo "Simulating data loss..."
docker exec app-bacula-server-1 sh -c 'find /data -mindepth 1 -not -name "." -not -name ".." -delete'

# Verify data is gone
if [ "$(docker exec app-bacula-server-1 sh -c 'ls -A /data/')" ]; then
    echo "Data directory not empty after deletion!"
    docker exec app-bacula-server-1 sh -c 'ls -la /data/'
    exit 1
fi

# Step 3: Execute restore
echo "Running restore job..."
docker exec app-bacula-server-1 sh -c 'printf "restore client=bacula-fd\n5\n.\nyes\nmod\n" | bconsole'

# Step 4: Validate restored data
echo "Calculating restored data checksums..."
RESTORED_CHECKSUM=$(docker exec app-bacula-server-1 find /data -type f -exec md5sum {} \; | sort)

# Compare checksums
if [ "$ORIGINAL_CHECKSUM" = "$RESTORED_CHECKSUM" ]; then
    echo "✅ Test passed! Backup and restore completed successfully."
    exit 0
else
    echo "❌ Test failed! Restored data does not match original data."
    echo "Original checksums:"
    echo "$ORIGINAL_CHECKSUM"
    echo "Restored checksums:"
    echo "$RESTORED_CHECKSUM"
    exit 1
fi
