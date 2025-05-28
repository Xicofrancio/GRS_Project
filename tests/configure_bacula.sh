#!/bin/bash
echo "Adding MinIO FileSet configuration..."
bconsole << EOF
reload
configure add fileset name="MinIOSet" includefile=/data options=verify=s ignorecase=yes
configure add job name="MinIOBackup" fileset=MinIOSet pool=File client=bacula-fd messages=Standard storage=File1
yes
reload
EOF
