# Bacula Backup & Restore Project – Presentation Guide

## 1. Project Overview

This project demonstrates a full-stack environment with automated backup and restore using Bacula, running in Docker containers. It simulates real-world data protection: if data is lost, you can restore it reliably.

**Key Technologies:**
- **Bacula**: Enterprise-grade backup and restore system
- **Docker Compose**: Orchestrates multiple containers (web app, databases, storage, Bacula server)
- **Node.js/Express**: Simple web app for demo purposes (not connected with bacula still)
- **PowerShell & Bash scripts**: Automate backup/restore tests

---

## 2. Architecture & Components

- **Web App (`web`)**: Node.js/Express, serves a demo page
- **Database (`db`)**: PostgreSQL for the app
- **Object Storage (`storage`)**: MinIO, S3-compatible
- **Bacula Server (`bacula-server`)**: Handles backup/restore, with Baculum web UI
- **Catalog DB (`catalog-db`)**: Dedicated PostgreSQL for Bacula’s catalog
- **Persistent Volumes**: Ensure data and backups survive container restarts

All Bacula config files are mounted into the container for transparency and persistence.

---

## 3. How Backup & Restore Works

- **Backup**: Bacula copies files from `/data` inside the container to `/mnt/bacula` (persistent storage)
- **Restore**: If files in `/data` are lost/deleted, Bacula can restore them from the backup
- **Automation**: Scripts (`restore_test.ps1` for PowerShell, `restore_test.sh` for Bash) automate the process: create test data, back it up, delete it, restore it, and verify integrity

---

## 4. Demo Walkthrough

### A. Show containers running
```powershell
docker compose -f .\docker\app\docker-compose.yml ps
```
Point out the `bacula-server`, `web`, `db`, etc.

### B. Run the automated test
```powershell
.\tests\restore_test.ps1
```
- This script will:
  1. Create test files in `/data`
  2. Run a Bacula backup job
  3. Simulate data loss (delete files)
  4. Run a Bacula restore job
  5. Compare checksums to verify the restore

### C. Show the output
Highlight the line:
```
✅ Test passed! Backup and restore completed successfully.
```

### D. (Optional) Show Baculum Web UI
Open [http://localhost:9095](http://localhost:9095)
Login: `admin` / `difficult`
Show the dashboard or job history.

---

## 5. What to Emphasize to Your Professor

- **Reliability**: Data is safe even if containers are stopped/restarted
- **Automation**: The test script proves backup/restore works end-to-end
- **Transparency**: All configs and volumes are visible and persistent
- **Realism**: Simulates real-world backup/restore scenarios

---

## 6. Q&A Preparation

Be ready to explain:
- How Bacula interacts with the containers and volumes
- How you’d add more data sources or scale up
- How to recover from a real disaster (e.g., accidental deletion)

---

## 7. Demo Checklist

- All containers are running and healthy
- Run the test script and show the success message
- (Optional) Manually delete and restore files to show flexibility
- (Optional) Show the Baculum web interface

---

**Summary:**
Your project is a robust, automated backup and restore solution using Bacula and Docker. The demo proves that data can be lost and fully recovered, with all steps automated and verifiable.
