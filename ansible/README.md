# 🤖 Deploy e Configuração (Ansible)

Playbooks para instalar e configurar:

- **Bacula File Daemon** (cliente)  
- **Vault Agent** para injeção de segredos  
- Templates de configuração em `/ansible/roles`

### Inventário

Cria `hosts.yml` com:

```yaml
all:
  hosts:
    demo-client:
      ansible_host: 127.0.0.1
      ansible_user: user
```

## Execute
cd ansible
ansible-playbook -i hosts.yml site.yml --check   # modo dry-run
ansible-playbook -i hosts.yml site.yml           # deploy real
