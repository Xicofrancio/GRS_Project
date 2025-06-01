# 🚀 Backup Monitoring System

A professional-grade backup monitoring system with comprehensive metrics, Prometheus integration, and Grafana dashboards.

## 📁 Project Structure

```
├── docker/
│   └── app/
│       ├── public/              # Web interface files
│       ├── monitoring/          # Prometheus & Grafana configs
│       ├── docker-compose.yml   # Container orchestration
│       ├── Dockerfile          # Web app container build
│       ├── index.js            # Main application code
│       └── package.json        # Node.js dependencies
├── bacula-server/             # Backup server configuration
├── USER_GUIDE.md             # 📚 Complete documentation
└── LICENSE                   # Project license
```

## � Quick Start

1. **Clone the repository**
2. **Navigate to the app directory:**
   ```bash
   cd docker/app
   ```
3. **Start the system:**
   ```bash
   docker-compose up -d
   ```
4. **Access the interfaces:**
   - Web App: http://localhost:3000
   - Prometheus: http://localhost:9090
   - Grafana: http://localhost:3001

## � Features

- **40+ Backup-Specific Metrics**
- **Real-time Monitoring**
- **Professional Dashboards**
- **File Backup & Restore**
- **Performance Analytics**

## 📚 Documentation

See [USER_GUIDE.md](USER_GUIDE.md) for complete documentation including:
- Setup instructions
- How to perform backups
- Viewing metrics
- Troubleshooting
- System architecture

## � System Requirements

- Docker & Docker Compose
- Available ports: 3000, 3001, 5432, 9000, 9001, 9090, 9095-9103
- Modern web browser

## 🤝 Contributing

Contributions are welcome! Please read the contribution guidelines first.

## 📝 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.