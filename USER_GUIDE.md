# 🚀 Backup Monitoring System - User Guide

## 📋 **Prerequisites**
- Docker and Docker Compose installed
- Windows PowerShell or Command Prompt
- Web browser
- Ports 3000, 3001, 5432, 9000, 9001, 9090, 9095-9103 available

## 🏁 **Quick Start**

### 1. **Start the System**
```powershell
# Navigate to the project directory
cd "c:\Users\DaFrancis\Desktop\Universidade\mestrado\2semestre\Gestao De Redes\PROJECT\docker\app"

# Start all services
docker-compose up -d

# Verify all containers are running
docker-compose ps
```

### 2. **Wait for Services to Initialize**
Wait 30-60 seconds for all services to start and become healthy.

## 📁 **How to Backup Files**

### **Option A: Web Interface (Recommended)**

1. **Access the Web Application**
   - Open: http://localhost:3000
   - You'll see the backup interface with file management options

2. **Upload Files to Storage**
   - Click "Choose Files" to select files from your computer
   - Click "Upload" to add files to MinIO storage
   - Files will appear in the "Current Files in Storage" section

3. **Perform Backup**
   - Select backup type: **Full** or **Incremental**
   - Click "Start Backup"
   - View backup results including:
     - Number of files backed up
     - Total size backed up
     - Backup duration and throughput
     - Backup job ID

4. **Check Backup Status**
   - Click "Check Backup Status" to see current system state
   - View links to monitoring dashboards

### **Option B: API Endpoints**

```powershell
# Backup files (Full backup)
Invoke-RestMethod -Uri "http://localhost:3000/api/backup" -Method POST -Body '{"type": "full"}' -ContentType "application/json"

# Backup files (Incremental backup)
Invoke-RestMethod -Uri "http://localhost:3000/api/backup" -Method POST -Body '{"type": "incremental"}' -ContentType "application/json"

# Check current files
Invoke-RestMethod -Uri "http://localhost:3000/api/files" -Method GET
```

### **Option C: Direct MinIO Upload**

1. **Access MinIO Console**
   - Open: http://localhost:9001
   - Login: `minioadmin` / `minioadmin`
   - Upload files directly to the bucket

## 📊 **How to View Metrics**

### **1. Prometheus Metrics (Raw Data)**

**Access:** http://localhost:9090

**Key Backup Metrics to Query:**

```promql
# Backup success rate
backup_success_rate_percent

# Backup operations count
backup_operations_total

# Backup duration
backup_duration_seconds

# System CPU during backups
backup_system_cpu_usage_percent

# Storage utilization
backup_storage_utilization_percent

# Recovery metrics
backup_rto_seconds
backup_rpo_seconds

# Active backup queue
backup_queue_size
```

**How to Query:**
1. Click on "Graph" tab
2. Enter any metric name above in the expression box
3. Click "Execute" to see the data
4. Use "Table" tab for raw values

### **2. Grafana Dashboards (Visualization)**

**Access:** http://localhost:3001
**Login:** `admin` / `admin`

**Create Your First Dashboard:**

1. **Set up Prometheus Data Source**
   - Go to Configuration → Data Sources
   - Add Prometheus data source
   - URL: `http://prometheus:9090`
   - Save & Test

2. **Create Backup Dashboard**
   - Click "+" → Dashboard
   - Add Panel
   - Select Prometheus as data source

**Essential Panels to Create:**

```yaml
Panel 1: Backup Success Rate
Query: backup_success_rate_percent
Visualization: Stat panel
Title: "Backup Success Rate (%)"

Panel 2: Backup Operations
Query: rate(backup_operations_total[5m])
Visualization: Time series
Title: "Backup Operations per Second"

Panel 3: System CPU During Backups
Query: backup_system_cpu_usage_percent
Visualization: Time series
Title: "CPU Usage During Backups (%)"

Panel 4: Storage Utilization
Query: backup_storage_utilization_percent
Visualization: Gauge
Title: "Storage Utilization"

Panel 5: Recovery Time Objective
Query: backup_rto_seconds
Visualization: Time series
Title: "Recovery Time Objective (seconds)"
```

### **3. Raw Metrics Endpoint**

**Access:** http://localhost:3000/metrics

View all metrics in Prometheus format directly from the application.

## 🔍 **How to Restore Files**

### **Web Interface**
1. Go to http://localhost:3000
2. Select restore type: **Full** or **Partial**
3. Click "Start Restore"
4. View restore results including duration and throughput

### **API**
```powershell
# Full restore
Invoke-RestMethod -Uri "http://localhost:3000/api/restore" -Method POST -Body '{"type": "full"}' -ContentType "application/json"

# Partial restore
Invoke-RestMethod -Uri "http://localhost:3000/api/restore" -Method POST -Body '{"type": "partial"}' -ContentType "application/json"
```

## 🎯 **Key Metrics Explained**

| Metric Category | Description | Why It Matters |
|-----------------|-------------|----------------|
| **Backup Success Rate** | Percentage of successful backups | Reliability indicator |
| **Backup Duration** | Time taken for backup operations | Performance monitoring |
| **Storage Utilization** | Percentage of storage space used | Capacity planning |
| **RTO/RPO** | Recovery time/point objectives | Disaster recovery readiness |
| **System Performance** | CPU/Memory/Disk during backups | Resource impact assessment |
| **Queue Metrics** | Pending backup jobs | Operational efficiency |

## 🏗️ **System Architecture**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web App       │    │   Prometheus    │    │    Grafana      │
│   :3000         │───▶│   :9090         │───▶│    :3001        │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│   MinIO         │    │   PostgreSQL    │
│   :9000-9001    │    │   :5432         │
└─────────────────┘    └─────────────────┘
```

## 🛠️ **Troubleshooting**

### **Services Not Starting**
```powershell
# Check container status
docker-compose ps

# View logs
docker-compose logs web
docker-compose logs prometheus
docker-compose logs grafana

# Restart services
docker-compose restart
```

### **Can't Access Web Interface**
- Ensure port 3000 is not blocked
- Check if container is healthy: `docker-compose ps`
- Restart web service: `docker-compose restart web`

### **Metrics Not Showing**
- Verify Prometheus targets: http://localhost:9090/targets
- Check metrics endpoint: http://localhost:3000/metrics
- Ensure data source is configured in Grafana

### **No Data in Grafana**
- Add Prometheus data source: `http://prometheus:9090`
- Check time range (last 15 minutes)
- Verify metric names in Prometheus first

## 🔄 **Maintenance**

### **Stop System**
```powershell
docker-compose down
```

### **Update System**
```powershell
docker-compose down
docker-compose pull
docker-compose up -d
```

### **Clean Up**
```powershell
# Remove containers and volumes
docker-compose down -v

# Remove images
docker-compose down --rmi all
```

## 📈 **Demo Scenario**

1. **Upload some files** via http://localhost:3000
2. **Perform a full backup** and note the metrics
3. **Check Prometheus** for `backup_operations_total`
4. **Perform an incremental backup**
5. **Create a Grafana dashboard** to visualize trends
6. **Simulate a restore operation**
7. **Monitor the metrics** over time to see patterns

## 🎯 **Success Indicators**

You know the system is working when:
- ✅ All containers show "healthy" status
- ✅ Web interface loads at http://localhost:3000
- ✅ Backup operations return success messages
- ✅ Prometheus shows 40+ backup metrics
- ✅ Grafana can query Prometheus data
- ✅ Metrics update in real-time during operations

---

**🎉 Enjoy monitoring your backups with professional-grade metrics!**
