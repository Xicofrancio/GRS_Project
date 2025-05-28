$backupScript = "run job=MinIOBackup yes"
docker cp .\run_backup.txt app-bacula-server-1:/tmp/run_backup.txt
docker exec app-bacula-server-1 /usr/sbin/bconsole -c "/etc/bacula/bconsole.conf" -u root -n -d 200
