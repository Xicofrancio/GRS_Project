# 🚀 Backup Lab Demo

- 🚢 Levantar uma aplicação Node.js + PostgreSQL + MinIO em Docker Compose  
- 📦 Provisione um bucket S3 (ou MinIO) com Terraform  
- 🤖 Instalar e configurar Bacula (Director, Storage, Client)  
- 🔄 Testar teardown e restore automático  
- 🔧 Automatizar testes com CI (Jenkins/GoCD)  
- 📊 (Opcional) Monitorizar com Prometheus & Grafana

---

## 📂 Estrutura de Pastas

/infra/ ← Terraform (bucket S3/MinIO)
/ansible/ ← Playbooks Ansible para Bacula & Vault
/docker/ ← Docker Compose + app demo full-stack
/bacula/ ← Configurações do Director, SD, FD
/tests/ ← Scripts de teardown & restore
/monitoring/ ← Prometheus & Grafana (opcional)
/ci/ ← Pipelines Jenkins/GoCD

---

## 📋 Pré-requisitos

- Docker & Docker Compose  
- Terraform v1.x  
- Ansible v2.9+  
- (Opcional) Jenkins ou GoCD  

---

## ▶️ Quickstart

1. `git clone <repo>`  
2. `cd infra && terraform init && terraform apply`  
3. `cd ../docker && docker-compose up -d --build`  
4. Configura Bacula em `/bacula` (já montado)  
5. `bash tests/teardown.sh && bash tests/restore.sh`  
6. (Opcional) Dispara o pipeline em `/ci`

---