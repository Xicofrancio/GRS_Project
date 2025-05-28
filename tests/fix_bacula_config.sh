#!/bin/bash

# Create the configuration file
cat > /etc/bacula/bacula-dir.d/minio-job.conf << 'EOL'
FileSet {
  Name = "MinIOSet"
  Include {
    Options {
      Signature = MD5
      Compression = GZIP
    }
    File = /data
  }
}

Job {
  Name = "MinIOBackup"
  Type = Backup
  Level = Full
  Client = bacula-fd
  FileSet = "MinIOSet"
  Storage = File1
  Pool = File
  Messages = Standard
}
EOL

# Restart Bacula Director to load the new configuration
/etc/init.d/bacula-director restart

# Wait for the service to restart
sleep 5

# Test the configuration
echo "status dir" | bconsole
