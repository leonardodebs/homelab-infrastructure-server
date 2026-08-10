# 15 — Upgrades e evolução

## Prioridade 1 — SSD de 120 GB no fim de 2026

O armazenamento atual validado na BIOS é um **SATA Flash Drive de 32 GB**. Ele será usado para colocar o HomeLab em produção agora.

O upgrade planejado para o fim de 2026 é substituir esse armazenamento por um **SSD de 120 GB**.

Benefícios:

- mais margem para atualizações do Ubuntu;
- maior folga para imagens e volumes Docker;
- maior retenção de logs sem pressionar o disco;
- possibilidade de adicionar containers leves;
- menor risco de indisponibilidade por falta de espaço.

Até a troca, mantenha o ambiente enxuto e monitore:

```bash
df -h /
docker system df
journalctl --disk-usage
```

Mantenha preferencialmente pelo menos 20% do armazenamento interno livre.

### Estratégia recomendada para a troca

A preferência é **não clonar** o disco antigo. O upgrade será usado como teste real de recuperação:

1. confirmar o último backup Restic no HD externo;
2. executar e validar um teste de restauração;
3. registrar Netplan, hostname e usuários;
4. desligar o servidor com segurança;
5. substituir o SATA Flash de 32 GB pelo SSD de 120 GB;
6. instalar Ubuntu Server 24.04 LTS limpo no SSD novo;
7. clonar este repositório GitHub;
8. reinstalar Docker, Unbound e a stack;
9. restaurar configurações e volumes necessários pelo Restic;
10. executar `scripts/healthcheck.sh` e validar DNS/DHCP antes de considerar a migração concluída.

O SATA Flash antigo deve ser preservado temporariamente sem alterações até o novo ambiente estar totalmente validado, funcionando como rollback físico adicional.

## Prioridade 2 — memória

Confirme no hardware real se o módulo pode ser substituído e qual é o limite suportado. Não compre memória apenas pela descrição do anúncio.

Com 4 GB, mantenha a stack atual enxuta. Evite:

- Kubernetes;
- Prometheus e Grafana completos;
- Nextcloud;
- bancos de dados pesados;
- Jellyfin com transcodificação;
- múltiplas VMs.

## Prioridade 3 — energia

Para manter DNS e DHCP durante quedas curtas, considere um nobreak pequeno para:

- modem/ONT;
- Dell Wyse;
- HD externo de backup quando conectado;
- eventual switch.

Teste a opção de ligar automaticamente após retorno da energia na BIOS.

## Evolução para dois nós

Quando houver um mini PC mais potente:

### Dell Wyse

- AdGuard Home;
- Unbound;
- DHCP;
- Uptime Kuma;
- serviços essenciais da rede.

### Mini PC Core i5 ou superior

- laboratórios Docker;
- k3s/Kubernetes;
- observabilidade;
- bancos de dados;
- CI/CD;
- aplicações pessoais.

Essa separação mantém os serviços essenciais independentes dos laboratórios.

## Melhorias futuras

- segundo DNS para redundância;
- segunda cópia de backup fora do HomeLab;
- Nginx Proxy Manager apenas para serviços internos;
- Tailscale para administração remota autenticada;
- UPS/NUT para desligamento seguro;
- monitoramento de temperatura e SMART;
- GitHub Actions para validar YAML e shell scripts.

## Critério para adicionar serviços

Antes de adicionar um container, verifique:

```bash
free -h
df -h /
docker stats --no-stream
docker system df
```

Preserve recursos para DNS e DHCP e evite transformar o Wyse em host de cargas pesadas.
