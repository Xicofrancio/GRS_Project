```markdown
# 🚦 Pipelines CI/CD

Definições de pipeline para Jenkins ou GoCD:

- **Stage 1:** Levantar o ambiente (`docker-compose up`)  
- **Stage 2:** Executar backup (`bconsole -x`)  
- **Stage 3:** Teardown (`tests/teardown.sh`)  
- **Stage 4:** Restore (`tests/restore.sh`)  
- **Stage 5:** Verificação (`curl http://localhost:3000`)

### Exemplo Jenkinsfile

Veja [Jenkinsfile](Jenkinsfile) para detalhes.
