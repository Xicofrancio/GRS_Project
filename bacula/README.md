```markdown
# 🎛️ Configurações Bacula

Aqui estão os ficheiros de config padrão:

- `bacula-dir.conf`  → Director (jobs, pools, schedules)  
- `bacula-sd.conf`   → Storage Daemon (device S3/MinIO)  
- `bacula-fd.conf`   → File Daemon (paths a incluir)

### Dicas

1. Ajusta `Pool` e `Job` names para o teu ambiente  
2. Verifica endpoints S3/MinIO em `Device`  
3. Usa `bconsole` para testar comandos de run/restore
