const express = require('express')
const path = require('path')
const app = express()
const PORT = process.env.PORT || 3000

// Servir estáticos na pasta public
app.use(express.static(path.join(__dirname, 'public')))

// Endpoint de health-check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: Date.now() })
})

app.listen(PORT, () => {
  console.log(`Demo app a correr em http://localhost:${PORT}`)
})
