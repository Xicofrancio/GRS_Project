# Bacula Backup & Restore Demo

This guide explains how to demonstrate the Bacula backup and restore process for your project using Docker and PowerShell.

---

## 1. Start All Containers

```
powershell
docker compose -f .\docker\app\docker-compose.yml up -d
```

---

## 2. Check That All Containers Are Running

```
powershell
docker compose -f .\docker\app\docker-compose.yml ps
```

---

## 3. (Optional) Check Bacula Director Status

```
powershell
docker exec app-bacula-server-1 sh -c 'echo "status dir" | bconsole'
```

---

## 4. Run the Automated Backup & Restore Test

This script will:
- Create test data
- Run a backup
- Simulate data loss
- Restore the data
- Validate the restore

```
powershell
docker exec app-bacula-server-1 bconsole
.\tests\restore_test.ps1
```

If you want to run the bash version inside WSL or Git Bash, use:
```
bash ./tests/restore_test.sh
```

---

## 5. (Optional) Manually Demonstrate Data Loss and Recovery

### a. Create Test Data

```
powershell
docker exec app-bacula-server-1 sh -c 'mkdir -p /data && echo "file1" > /data/file1.txt && echo "file2" > /data/file2.txt'
```

### b. Run a Backup Job

```
powershell
docker exec app-bacula-server-1 sh -c 'echo "run job=BackupClient1 yes" | bconsole'
```

### c. Check Backup Files

```
powershell
docker exec app-bacula-server-1 ls -l /mnt/bacula/
```

### d. Simulate Data Loss

```
powershell
docker exec app-bacula-server-1 rm -rf /data/*
```

### e. Restore Data

```
powershell
docker exec app-bacula-server-1 sh -c 'printf "restore client=bacula-fd\n5\n.\nyes\nmod\n" | bconsole'
```

### f. Verify Data is Restored

```
powershell
docker exec app-bacula-server-1 ls -l /data/
```

---

## 6. Show the Baculum Web UI (Optional)

Open your browser and go to:  
http://localhost:9095  
Login:  
- User: `admin`
- Password: `difficult`

---

## What to Show Your Professor

- The containers running (`docker compose ... ps`)
- The test script output showing "✅ Test passed! Backup and restore completed successfully."
- (Optional) Manually delete files and restore them, showing before/after with `ls -l /data/`
- (Optional) The Baculum web interface

---

**Good luck with your demo!**
