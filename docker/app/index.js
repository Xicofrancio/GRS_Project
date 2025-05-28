const express = require('express')
const path = require('path')
const Minio = require('minio')
const multer = require('multer')
const fs = require('fs')
const { promisify } = require('util')

const readFile = promisify(fs.readFile)
const unlink = promisify(fs.unlink)

// Configure multer with file size limits
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

// Serve static files from public directory
app.use(express.static(path.join(__dirname, 'public')))

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
