const express = require('express')
const path = require('path')
const Minio = require('minio')
const multer = require('multer')
const fs = require('fs')
const { promisify } = require('util')
const client = require('prom-client')
const os = require('os')

const readFile = promisify(fs.readFile)
const unlink = promisify(fs.unlink)

// Backup system state
let backupStorage = new Map() // Stores backup snapshots: filename -> {content, metadata}
let backupJobs = new Map() // Active backup jobs tracking
let systemLoad = { cpu: 0, memory: 0, disk: 0 }

// Prometheus metrics setup
const register = new client.Registry()

// === BACKUP OPERATION METRICS ===
const backupDurationHistogram = new client.Histogram({
  name: 'backup_duration_seconds',
  help: 'Duration of backup operations in seconds',
  buckets: [0.5, 1, 2, 5, 10, 30, 60, 300, 600],
  labelNames: ['backup_type', 'source'],
  registers: [register]
})

const backupOperationsCounter = new client.Counter({
  name: 'backup_operations_total',
  help: 'Total number of backup operations',
  labelNames: ['status', 'backup_type', 'source'], // success, failure, full/incremental, source_system
  registers: [register]
})

const backupSuccessRateGauge = new client.Gauge({
  name: 'backup_success_rate_percent',
  help: 'Backup success rate over last 24 hours as percentage',
  labelNames: ['backup_type'],
  registers: [register]
})

const backupDataThroughputGauge = new client.Gauge({
  name: 'backup_data_throughput_mbps',
  help: 'Backup data throughput in MB/s',
  labelNames: ['backup_type'],
  registers: [register]
})

// === STORAGE AND CAPACITY METRICS ===
const backupStorageUtilizationGauge = new client.Gauge({
  name: 'backup_storage_utilization_percent',
  help: 'Backup storage utilization percentage',
  labelNames: ['storage_type'],
  registers: [register]
})

const backupRetentionComplianceGauge = new client.Gauge({
  name: 'backup_retention_compliance_percent',
  help: 'Percentage of backups compliant with retention policy',
  registers: [register]
})

const filesBackedUpGauge = new client.Gauge({
  name: 'files_backed_up_total',
  help: 'Total number of files currently in backup storage',
  labelNames: ['retention_period'],
  registers: [register]
})

const backupStorageSizeGauge = new client.Gauge({
  name: 'backup_storage_size_bytes',
  help: 'Total size of backup storage in bytes',
  labelNames: ['storage_tier'],
  registers: [register]
})

// === SYSTEM PERFORMANCE DURING BACKUPS ===
const backupSystemCpuGauge = new client.Gauge({
  name: 'backup_system_cpu_usage_percent',
  help: 'CPU usage percentage during backup operations',
  registers: [register]
})

const backupSystemMemoryGauge = new client.Gauge({
  name: 'backup_system_memory_usage_percent',
  help: 'Memory usage percentage during backup operations',
  registers: [register]
})

const backupSystemDiskIOGauge = new client.Gauge({
  name: 'backup_system_disk_io_percent',
  help: 'Disk I/O utilization percentage during backup operations',
  registers: [register]
})

// === RECOVERY AND RELIABILITY METRICS ===
const restoreOperationsCounter = new client.Counter({
  name: 'restore_operations_total',
  help: 'Total number of restore operations',
  labelNames: ['status', 'restore_type'], // success/failure, full/partial
  registers: [register]
})

const restoreDurationHistogram = new client.Histogram({
  name: 'restore_duration_seconds',
  help: 'Duration of restore operations in seconds',
  buckets: [1, 5, 10, 30, 60, 300, 600, 1800],
  labelNames: ['restore_type'],
  registers: [register]
})

const backupVerificationCounter = new client.Counter({
  name: 'backup_verification_total',
  help: 'Total number of backup verifications',
  labelNames: ['status'], // success, failure, corrupted
  registers: [register]
})

const rtoMetricsGauge = new client.Gauge({
  name: 'backup_rto_seconds',
  help: 'Recovery Time Objective in seconds',
  labelNames: ['service_tier'],
  registers: [register]
})

const rpoMetricsGauge = new client.Gauge({
  name: 'backup_rpo_seconds',
  help: 'Recovery Point Objective in seconds',
  labelNames: ['service_tier'],
  registers: [register]
})

// === BACKUP SCHEDULE AND COMPLIANCE ===
const scheduledBackupsGauge = new client.Gauge({
  name: 'scheduled_backups_pending',
  help: 'Number of scheduled backups pending execution',
  labelNames: ['priority'],
  registers: [register]
})

const missedBackupsCounter = new client.Counter({
  name: 'missed_backups_total',
  help: 'Total number of missed backup windows',
  labelNames: ['reason'], // system_busy, storage_full, network_error
  registers: [register]
})

const backupWindowUtilizationGauge = new client.Gauge({
  name: 'backup_window_utilization_percent',
  help: 'Backup window time utilization percentage',
  registers: [register]
})

// === ERRORS AND ALERTS ===
const backupErrorsCounter = new client.Counter({
  name: 'backup_errors_total',
  help: 'Total number of backup errors',
  labelNames: ['error_type'], // network, storage, permission, corruption
  registers: [register]
})

const backupAlertsGauge = new client.Gauge({
  name: 'backup_active_alerts',
  help: 'Number of active backup-related alerts',
  labelNames: ['severity'], // critical, warning, info
  registers: [register]
})

const minioFilesGauge = new client.Gauge({
  name: 'minio_files_total',
  help: 'Total number of files in MinIO storage',
  registers: [register]
})

const minioStorageSizeGauge = new client.Gauge({
  name: 'minio_storage_size_bytes',
  help: 'Total size of MinIO storage in bytes',
  registers: [register]
})

// === ADDITIONAL BACKUP SIMULATION METRICS ===
const backupSuccessCounter = new client.Counter({
  name: 'backup_jobs_total',
  help: 'Total number of backup jobs executed',
  labelNames: ['result'], // success, failure
  registers: [register]
})

const restoreSuccessCounter = new client.Counter({
  name: 'restore_jobs_total',
  help: 'Total number of restore jobs executed',
  labelNames: ['result'], // success, failure
  registers: [register]
})

const backupQueueSizeGauge = new client.Gauge({
  name: 'backup_queue_size',
  help: 'Number of backup jobs in queue',
  registers: [register]
})

const networkBandwidthGauge = new client.Gauge({
  name: 'backup_network_bandwidth_mbps',
  help: 'Network bandwidth used during backup operations',
  registers: [register]
})

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.01, 0.1, 0.5, 1, 2, 5],
  registers: [register]
})

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
})

// Add default metrics (CPU, memory, etc.)
register.setDefaultLabels({
  app: 'backup-demo-system'
})
client.collectDefaultMetrics({ register })

// === BACKUP SIMULATION FUNCTIONS ===
function simulateBackupLoad() {
  // Simulate varying system load during backup operations
  const baseLoad = 20 + Math.random() * 30  // 20-50% base load
  const burstLoad = Math.random() > 0.8 ? Math.random() * 40 : 0  // Occasional bursts
  
  systemLoad.cpu = Math.min(95, baseLoad + burstLoad)
  systemLoad.memory = 30 + Math.random() * 40  // 30-70% memory usage
  systemLoad.disk = 40 + Math.random() * 50    // 40-90% disk I/O
  
  // Update system performance metrics
  backupSystemCpuGauge.set(systemLoad.cpu)
  backupSystemMemoryGauge.set(systemLoad.memory)
  backupSystemDiskIOGauge.set(systemLoad.disk)
  
  // Simulate network bandwidth (5-50 Mbps)
  const networkBandwidth = 5 + Math.random() * 45
  networkBandwidthGauge.set(networkBandwidth)
}

function updateBackupMetrics() {
  // Simulate backup success rates (85-98% success rate)
  const successRate = 85 + Math.random() * 13
  backupSuccessRateGauge.labels('full').set(successRate)
  backupSuccessRateGauge.labels('incremental').set(Math.min(99, successRate + 5))
  
  // Simulate storage utilization (60-85% for primary, 40-70% for archive)
  backupStorageUtilizationGauge.labels('primary').set(60 + Math.random() * 25)
  backupStorageUtilizationGauge.labels('archive').set(40 + Math.random() * 30)
  
  // Simulate retention compliance (90-100%)
  backupRetentionComplianceGauge.set(90 + Math.random() * 10)
  
  // Simulate scheduled backups pending (0-5 jobs)
  scheduledBackupsGauge.labels('high').set(Math.floor(Math.random() * 3))
  scheduledBackupsGauge.labels('normal').set(Math.floor(Math.random() * 4))
  scheduledBackupsGauge.labels('low').set(Math.floor(Math.random() * 2))
  
  // Simulate backup window utilization (70-95%)
  backupWindowUtilizationGauge.set(70 + Math.random() * 25)
  
  // Simulate RTO/RPO metrics (in seconds)
  rtoMetricsGauge.labels('critical').set(300 + Math.random() * 300)  // 5-10 minutes
  rtoMetricsGauge.labels('standard').set(1800 + Math.random() * 1800) // 30-60 minutes
  rpoMetricsGauge.labels('critical').set(60 + Math.random() * 240)    // 1-5 minutes
  rpoMetricsGauge.labels('standard').set(900 + Math.random() * 2700)  // 15-60 minutes
  
  // Simulate active alerts (0-3 alerts of different severities)
  backupAlertsGauge.labels('critical').set(Math.random() > 0.9 ? 1 : 0)
  backupAlertsGauge.labels('warning').set(Math.floor(Math.random() * 3))
  backupAlertsGauge.labels('info').set(Math.floor(Math.random() * 2))
  
  // Simulate backup queue size (0-8 jobs)
  backupQueueSizeGauge.set(Math.floor(Math.random() * 9))
}

function simulateBackupOperation(backupType = 'full', sourceSystem = 'web-app') {
  const startTime = Date.now()
  
  // Simulate backup operation metrics
  const duration = backupType === 'full' ? 
    30 + Math.random() * 120 :  // Full: 30-150 seconds
    5 + Math.random() * 25      // Incremental: 5-30 seconds
  
  // Simulate data throughput (10-100 MB/s)
  const throughput = 10 + Math.random() * 90
  backupDataThroughputGauge.labels(backupType).set(throughput)
  
  return {
    duration,
    throughput,
    startTime,
    backupType,
    sourceSystem
  }
}

function recordBackupCompletion(operationData, success = true) {
  const { duration, backupType, sourceSystem } = operationData
  
  // Record operation metrics
  backupOperationsCounter.labels(
    success ? 'success' : 'failure',
    backupType,
    sourceSystem
  ).inc()
  
  // Record duration
  backupDurationHistogram.labels(backupType, sourceSystem).observe(duration / 1000)
  
  // Occasionally record errors and verifications
  if (Math.random() > 0.95) {  // 5% chance of error
    const errorTypes = ['network', 'storage', 'permission', 'corruption']
    const errorType = errorTypes[Math.floor(Math.random() * errorTypes.length)]
    backupErrorsCounter.labels(errorType).inc()
  }
  
  if (Math.random() > 0.7) {  // 30% chance of verification
    const verificationStatus = Math.random() > 0.95 ? 'corrupted' : 'success'
    backupVerificationCounter.labels(verificationStatus).inc()
  }
  
  // Occasionally record missed backups
  if (Math.random() > 0.98) {  // 2% chance
    const reasons = ['system_busy', 'storage_full', 'network_error']
    const reason = reasons[Math.floor(Math.random() * reasons.length)]
    missedBackupsCounter.labels(reason).inc()
  }
}

// Start background metric simulation
setInterval(() => {
  simulateBackupLoad()
  updateBackupMetrics()
}, 10000)  // Update every 10 seconds

// Simulate random backup operations
setInterval(() => {
  if (Math.random() > 0.7) {  // 30% chance every 15 seconds
    const backupType = Math.random() > 0.3 ? 'incremental' : 'full'
    const sources = ['web-app', 'database', 'file-server', 'email-server']
    const source = sources[Math.floor(Math.random() * sources.length)]
    
    const operation = simulateBackupOperation(backupType, source)
    
    // Complete operation after simulated duration
    setTimeout(() => {
      const success = Math.random() > 0.05  // 95% success rate
      recordBackupCompletion(operation, success)
    }, Math.random() * 2000)  // Complete within 2 seconds for demo
  }
}, 15000)  // Check every 15 seconds

// Simulate restore operations occasionally
setInterval(() => {
  if (Math.random() > 0.95) {  // 5% chance every 30 seconds
    const restoreType = Math.random() > 0.5 ? 'full' : 'partial'
    const success = Math.random() > 0.1  // 90% success rate
    
    restoreOperationsCounter.labels(
      success ? 'success' : 'failure',
      restoreType
    ).inc()
    
    // Record restore duration (typically longer than backup)
    const duration = restoreType === 'full' ? 
      60 + Math.random() * 300 :  // Full restore: 1-6 minutes
      10 + Math.random() * 50     // Partial restore: 10-60 seconds
    
    restoreDurationHistogram.labels(restoreType).observe(duration)
  }
}, 30000)  // Check every 30 seconds

// Helper function to update storage metrics
async function updateStorageMetrics() {
  try {
    // Update backup storage metrics
    let totalBackupSize = 0
    for (const [filename, backupData] of backupStorage.entries()) {
      totalBackupSize += backupData.metadata.size
    }
    filesBackedUpGauge.set(backupStorage.size)
    backupStorageSizeGauge.set(totalBackupSize)

    // Update MinIO metrics
    const bucketName = 'testbucket'
    const objectStream = minioClient.listObjects(bucketName, '', true)
    let minioFileCount = 0
    let minioTotalSize = 0
    
    for await (const obj of objectStream) {
      minioFileCount++
      minioTotalSize += obj.size
    }
    
    minioFilesGauge.set(minioFileCount)
    minioStorageSizeGauge.set(minioTotalSize)
  } catch (error) {
    console.error('Error updating storage metrics:', error.message)
  }
}

// Middleware to track HTTP requests
function metricsMiddleware(req, res, next) {
  const start = Date.now()
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000
    const route = req.route ? req.route.path : req.path
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode.toString())
      .observe(duration)
    
    httpRequestTotal
      .labels(req.method, route, res.statusCode.toString())
      .inc()
  })
  
  next()
}

const upload = multer({ 
  dest: 'uploads/',
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB limit
  }
})

const app = express()
const PORT = process.env.PORT || 3000

// Configure MinIO client
const minioClient = new Minio.Client({
  endPoint: 'storage',  // Using docker service name
  port: 9000,          // MinIO API port
  useSSL: false,
  accessKey: 'minio',  // Match with docker-compose env vars
  secretKey: 'minio123'
})

// Initialize bucket on startup
async function initializeBucket() {
  const bucketName = 'testbucket'
  try {
    const exists = await minioClient.bucketExists(bucketName)
    if (!exists) {
      await minioClient.makeBucket(bucketName)
      console.log('Bucket created successfully')
    }
  } catch (error) {
    console.error('Error initializing bucket:', error)
  }
}

initializeBucket()

// Apply metrics middleware to all routes
app.use(metricsMiddleware)

// Serve static files from public directory
app.use(express.static(path.join(__dirname, 'public')))

// Prometheus metrics endpoint
app.get('/metrics', async (req, res) => {
  try {
    // Update storage metrics before serving metrics
    await updateStorageMetrics()
    
    res.set('Content-Type', register.contentType)
    res.end(await register.metrics())
  } catch (error) {
    console.error('Error generating metrics:', error)
    res.status(500).end('Error generating metrics')
  }
})

// Health-check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: Date.now() })
})

// File upload endpoint
app.post('/api/upload', upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file provided' })
  }

  try {
    const file = req.file
    const bucketName = 'testbucket'
    const fileData = await readFile(file.path)
    
    // Upload to MinIO
    await minioClient.putObject(
      bucketName,
      file.originalname,
      fileData,
      file.size,
      file.mimetype
    )

    // Clean up temporary file
    await unlink(file.path)

    res.json({ 
      message: 'File uploaded successfully',
      filename: file.originalname,
      size: file.size,
      type: file.mimetype
    })
  } catch (err) {
    console.error('Upload error:', err)
    // Clean up temporary file on error
    if (req.file) {
      await unlink(req.file.path).catch(console.error)
    }
    res.status(500).json({ error: 'Upload failed: ' + err.message })
  }
})

// List files endpoint
app.get('/api/files', async (req, res) => {
  try {
    const bucketName = 'testbucket'
    const stream = minioClient.listObjects(bucketName, '', true)
    const files = []
    
    await new Promise((resolve, reject) => {
      stream.on('data', (obj) => {
        files.push({
          name: obj.name,
          size: obj.size,
          lastModified: obj.lastModified
        })
      })
      stream.on('end', resolve)
      stream.on('error', reject)
    })
    
    res.json(files)
  } catch (error) {
    console.error('Error listing files:', error)
    res.status(500).json({ error: 'Failed to list files: ' + error.message })
  }
})

// Delete file endpoint
app.delete('/api/files/:filename', async (req, res) => {
  try {
    const bucketName = 'testbucket'
    const filename = decodeURIComponent(req.params.filename)
    
    await minioClient.removeObject(bucketName, filename)
    
    res.json({ 
      message: 'File deleted successfully',
      filename: filename
    })
  } catch (error) {
    console.error('Error deleting file:', error)
    res.status(500).json({ error: 'Failed to delete file: ' + error.message })
  }
})

// Backup endpoint - triggers Bacula backup
app.post('/api/backup', async (req, res) => {
  const backupType = req.body?.type || 'full'
  const sourceSystem = 'web-app'
  
  // Start backup operation simulation
  const operation = simulateBackupOperation(backupType, sourceSystem)
  const backupTimer = backupDurationHistogram.labels(backupType, sourceSystem).startTimer()
  
  try {
    console.log(`Triggering ${backupType} backup...`)
    
    // Simulate system load during backup
    simulateBackupLoad()
    
    // For demonstration, we'll actually back up the current files in MinIO
    const bucketName = 'testbucket'
    const currentFiles = []
    const objectStream = minioClient.listObjects(bucketName, '', true)
    
    // Get list of all current files
    for await (const obj of objectStream) {
      currentFiles.push({
        name: obj.name,
        size: obj.size,
        lastModified: obj.lastModified
      })
    }
    
    // "Back up" each file by storing its content and metadata
    const backedUpFiles = []
    let totalBackupSize = 0
    
    for (const fileInfo of currentFiles) {
      try {
        // Get the file content from MinIO
        const fileStream = await minioClient.getObject(bucketName, fileInfo.name)
        const chunks = []
        
        for await (const chunk of fileStream) {
          chunks.push(chunk)
        }
        
        const fileContent = Buffer.concat(chunks)
        totalBackupSize += fileContent.length
        
        // Store in backup storage with enhanced metadata
        backupStorage.set(fileInfo.name, {
          content: fileContent,
          metadata: {
            originalName: fileInfo.name,
            size: fileInfo.size,
            lastModified: fileInfo.lastModified,
            backupTimestamp: new Date().toISOString(),
            backupType: backupType,
            sourceSystem: sourceSystem,
            contentType: 'application/octet-stream',
            checksum: Buffer.from(fileContent).toString('base64').slice(0, 20) // Simple checksum simulation
          }
        })
        
        backedUpFiles.push(fileInfo.name)
        console.log(`Backed up file: ${fileInfo.name}`)
        
      } catch (err) {
        console.log(`Failed to backup file ${fileInfo.name}:`, err.message)
        // Record error
        backupErrorsCounter.labels('storage').inc()
      }
    }
    
    // Complete backup operation
    const actualDuration = (Date.now() - operation.startTime) / 1000
    operation.duration = actualDuration
    
    // Record successful backup
    recordBackupCompletion(operation, true)
    backupSuccessCounter.labels('success').inc()
    backupTimer()
    
    // Update file metrics
    filesBackedUpGauge.labels('30days').set(backupStorage.size)
    backupStorageSizeGauge.labels('primary').set(totalBackupSize)
    
    // Update storage metrics
    await updateStorageMetrics()
    
    res.json({
      message: `${backupType} backup completed successfully`,
      jobId: Math.floor(Math.random() * 10000),
      backupType: backupType,
      sourceSystem: sourceSystem,
      filesBackedUp: backedUpFiles.length,
      totalSizeBackedUp: totalBackupSize,
      duration: actualDuration.toFixed(2) + ' seconds',
      throughput: (totalBackupSize / (1024 * 1024) / actualDuration).toFixed(2) + ' MB/s',
      backupFiles: backedUpFiles,
      status: `${backedUpFiles.length} files backed up from MinIO storage`,
      timestamp: new Date().toISOString(),
      note: `Files are now stored in backup storage and can be restored if deleted from MinIO.`
    })
    
  } catch (error) {
    console.error('Backup error:', error)
    
    // Record failed backup
    recordBackupCompletion(operation, false)
    backupSuccessCounter.labels('failure').inc()
    backupErrorsCounter.labels('system').inc()
    backupTimer()
    
    res.status(500).json({ 
      error: 'Backup failed: ' + error.message,
      jobId: Math.floor(Math.random() * 10000),
      backupType: backupType,
      duration: ((Date.now() - operation.startTime) / 1000).toFixed(2) + ' seconds'
    })
  }
})

// Restore endpoint - restores files from backup storage
app.post('/api/restore', async (req, res) => {
  const restoreType = req.body?.type || 'full'
  const restoreTimer = restoreDurationHistogram.labels(restoreType).startTimer()
  const startTime = Date.now()
  
  try {
    console.log(`Starting ${restoreType} file restore from backup storage...`)
    
    const bucketName = 'testbucket'
    
    // Get current files to see what's missing
    const currentFiles = []
    const objectStream = minioClient.listObjects(bucketName, '', true)
    
    for await (const obj of objectStream) {
      currentFiles.push(obj.name)
    }
    
    console.log(`Current files in MinIO: ${currentFiles.length}`)
    console.log(`Files available in backup: ${backupStorage.size}`)
    
    const restoredFiles = []
    const failedRestores = []
    let totalRestoredSize = 0
    
    // Restore files from backup storage that are not currently in MinIO
    for (const [filename, backupData] of backupStorage.entries()) {
      try {
        if (!currentFiles.includes(filename)) {
          // Restore the file to MinIO
          await minioClient.putObject(
            bucketName, 
            filename, 
            backupData.content,
            backupData.metadata.size,
            {
              'Content-Type': backupData.metadata.contentType || 'application/octet-stream'
            }
          )
          
          totalRestoredSize += backupData.metadata.size
          
          restoredFiles.push({
            name: filename,
            size: backupData.metadata.size,
            backupType: backupData.metadata.backupType || 'unknown',
            originalBackupTime: backupData.metadata.backupTimestamp,
            restoredAt: new Date().toISOString(),
            checksum: backupData.metadata.checksum
          })
          
          console.log(`Restored file: ${filename}`)
        } else {
          console.log(`File ${filename} already exists, skipping restore`)
        }
      } catch (err) {
        console.log(`Failed to restore file ${filename}:`, err.message)
        failedRestores.push({
          filename: filename,
          error: err.message
        })
        backupErrorsCounter.labels('storage').inc()
      }
    }
    
    // If no files were available to restore, create some demo files to show the concept
    if (backupStorage.size === 0) {
      console.log('No backup files found, creating demo restored files...')
      const demoContent = `DEMO RESTORED FILE - ${restoreType} restore at ${new Date().toISOString()}\n\nThis demonstrates that the restore functionality is working.\nRestore Type: ${restoreType}\nIn a real backup scenario, your original files would be restored here.\n\nThis file contains simulated data showing successful ${restoreType} restore operation.`
      
      const demoFiles = [`demo_${restoreType}_restored_file.txt`]
      for (const filename of demoFiles) {
        if (!currentFiles.includes(filename)) {
          await minioClient.putObject(bucketName, filename, demoContent)
          totalRestoredSize += demoContent.length
          restoredFiles.push({
            name: filename,
            size: demoContent.length,
            restoredAt: new Date().toISOString(),
            type: 'demo',
            restoreType: restoreType
          })
        }
      }
    }
    
    // Calculate restore metrics
    const duration = (Date.now() - startTime) / 1000
    const throughput = totalRestoredSize > 0 ? (totalRestoredSize / (1024 * 1024) / duration).toFixed(2) : '0'
    
    // Record restore metrics
    if (restoredFiles.length > 0) {
      restoreSuccessCounter.labels('success').inc()
      restoreOperationsCounter.labels('success', restoreType).inc()
    }
    if (failedRestores.length > 0) {
      restoreSuccessCounter.labels('failure').inc()
      restoreOperationsCounter.labels('failure', restoreType).inc(failedRestores.length)
    }
    
    restoreTimer()
    
    // Update storage metrics
    await updateStorageMetrics()
    
    res.json({
      message: `${restoreType} restore completed`,
      restoreType: restoreType,
      filesRestored: restoredFiles.length,
      totalSizeRestored: totalRestoredSize,
      duration: duration.toFixed(2) + ' seconds',
      throughput: throughput + ' MB/s',
      restoredFiles: restoredFiles,
      failedRestores: failedRestores,
      availableBackups: backupStorage.size,
      currentFilesInStorage: currentFiles.length,
      timestamp: new Date().toISOString(),
      note: restoredFiles.length > 0 ? 
        `${restoredFiles.length} files have been successfully restored from backup storage using ${restoreType} restore.` : 
        'No files needed to be restored (all backup files already exist in storage).'
    })
    
  } catch (error) {
    console.error('Restore error:', error)
    
    // Record failed restore
    restoreSuccessCounter.labels('failure').inc()
    restoreOperationsCounter.labels('failure', restoreType).inc()
    restoreTimer()
    
    res.status(500).json({ 
      error: `${restoreType} restore failed: ` + error.message,
      restoreType: restoreType,
      duration: ((Date.now() - startTime) / 1000).toFixed(2) + ' seconds'
    })
  }
})

// File view endpoint
app.get('/api/files/:filename/view', async (req, res) => {
  try {
    const filename = decodeURIComponent(req.params.filename)
    console.log(`Viewing file: ${filename}`)
    
    const stream = await minioClient.getObject('testbucket', filename)
    
    // Set appropriate content type
    const ext = filename.split('.').pop().toLowerCase()
    const contentTypes = {
      'txt': 'text/plain',
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'json': 'application/json',
      'html': 'text/html',
      'css': 'text/css',
      'js': 'text/javascript'
    }
    
    const contentType = contentTypes[ext] || 'application/octet-stream'
    res.setHeader('Content-Type', contentType)
    res.setHeader('Content-Disposition', `inline; filename="${filename}"`)
    
    stream.pipe(res)
  } catch (error) {
    console.error('Error viewing file:', error)
    res.status(500).json({ error: 'Failed to view file: ' + error.message })
  }
})

// Debug endpoint to check backup storage contents
app.get('/api/backup/status', (req, res) => {
  const backupInfo = []
  for (const [filename, backupData] of backupStorage.entries()) {
    backupInfo.push({
      filename: filename,
      size: backupData.metadata.size,
      backupTimestamp: backupData.metadata.backupTimestamp,
      originalLastModified: backupData.metadata.lastModified
    })
  }
  
  res.json({
    totalBackups: backupStorage.size,
    backupFiles: backupInfo,
    timestamp: new Date().toISOString()
  })
})

// Error handling middleware
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large. Maximum size is 10MB.' })
    }
    return res.status(400).json({ error: 'File upload error: ' + err.message })
  }
  next(err)
})

app.listen(PORT, () => {
  console.log(`Demo app running at http://localhost:${PORT}`)
})
