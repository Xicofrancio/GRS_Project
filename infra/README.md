# 🌐 Infraestrutura (Terraform)

Este módulo define a infraestrutura onde armazenamos os backups:

- **Provider AWS** (usado para S3)  
- **Bucket S3** com versioning e lifecycle rules  
- Variável `env` para distinguir `lab`, `dev`, `prod`

### Como usar

```bash
cd infra
terraform init
terraform plan   # revisa as mudanças
terraform apply  # cria o bucket

Never edit bucket manually only via terraform



