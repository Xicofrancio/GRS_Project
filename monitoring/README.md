```markdown
# 📊 Monitorização (Opcional)

Configura Prometheus + Grafana para vigiar:

- Métricas do Bacula Director/Storage  
- Dashboards de sucesso/falha de jobs

### Levantar

Adiciona a secção em `docker-compose.yml` e faz:

```bash
docker-compose up -d prometheus grafana
