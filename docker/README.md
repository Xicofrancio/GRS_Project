# 🐳 Docker Compose & App Demo

Absolutamente tudo para levantar o teu ambiente full-stack.

## Conteúdo

- `docker-compose.yml`  
  - `web` → Node.js + Express  
  - `db`  → PostgreSQL  
  - `storage` → MinIO  
  - `director`, `storage-daemon`, `client` → Bacula

- `app/` → código da demo
  - `index.js`  
  - `public/index.html`  
  - `package.json`  
  - `Dockerfile`

## Como levantar

```bash
cd docker
docker-compose up -d --build

Frontend em: http://localhost:3000

MinIO UI em: http://localhost:9000