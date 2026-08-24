# 16 — Upgrades e evolução

## Prioridade 1 — SSD de 120 GB no fim de 2026

O armazenamento de produção atual é um **SATA Flash Drive de 32 GB**. A stack funciona nesse espaço, mas deve permanecer enxuta.

O upgrade planejado é substituir o armazenamento interno por um **SSD de 120 GB**.

Benefícios:

- mais margem para atualizações do Ubuntu;
- maior folga para imagens e volumes Docker;
- mais tolerância a crescimento de logs;
- possibilidade de adicionar containers leves sem pressionar o sistema;
- menor risco de indisponibilidade por falta de espaço.

Até a troca:

```bash
df -h /
docker system df
journalctl --disk-usage
```

Mantenha preferencialmente pelo menos 20% livre.

## Estratégia de migração

A preferência é **não clonar** o disco antigo. A troca deve funcionar como teste real de disaster recovery:

1. confirmar snapshot Restic recente em `/srv/backup`;
2. executar `restic check`;
3. executar e validar restore test;
4. registrar hostname, rede e estado da stack;
5. desligar com segurança;
6. substituir o SATA Flash pelo SSD;
7. instalar Ubuntu Server LTS limpo;
8. configurar hostname `homelab` e IP `192.168.100.2`;
9. clonar este repositório;
10. reinstalar Docker e Unbound;
11. recriar a stack Compose;
12. restaurar configurações/volumes necessários pelo Restic;
13. validar DNS, DHCP, UFW, observabilidade e backup.

O SATA Flash antigo deve ser preservado temporariamente como rollback físico.

## Mídia de backup

A mídia operacional atual é um **pendrive USB de 128 GB**, validado com F3 e montado em `/srv/backup`.

Um HD externo de maior capacidade pode ser usado futuramente como:

- segunda cópia local;
- substituição do pendrive;
- mídia offline rotacionada.

A capacidade atual do Restic é pequena em relação ao espaço disponível, então não existe necessidade imediata de migrar o backup.

## Prioridade 2 — memória

Antes de comprar RAM, valide fisicamente:

- tipo do módulo;
- limite suportado pela placa;
- compatibilidade real do equipamento.

Com 4 GB, evite no Wyse:

- Kubernetes/k3s de laboratório permanente;
- Prometheus + Grafana completos;
- Nextcloud;
- bancos pesados;
- Jellyfin com transcodificação;
- múltiplas VMs.

## Prioridade 3 — energia

Para preservar DNS/DHCP durante quedas curtas, um nobreak pode proteger:

- modem/ONT;
- Dell Wyse;
- mídia de backup quando conectada;
- eventual switch.

Também vale revisar na BIOS a opção de retorno automático após falta de energia, se disponível e confiável.

## Evolução para dois nós

Quando houver hardware mais potente:

### Dell Wyse — infraestrutura essencial

- AdGuard Home;
- Unbound;
- DHCP;
- Uptime Kuma;
- Node Exporter e cAdvisor;
- Portainer;
- Diun;
- portal interno;
- backup/rotinas de recuperação.

### Segundo mini PC — laboratório

- k3s/Kubernetes;
- observabilidade mais pesada;
- bancos de dados;
- CI/CD;
- aplicações pessoais;
- workloads experimentais.

Essa separação mantém DNS/DHCP independentes dos laboratórios.

## Melhorias futuras opcionais

- segundo DNS para redundância;
- segunda cópia criptografada fora do HomeLab;
- reverse proxy interno para URLs amigáveis;
- DNS rewrites em `home.arpa`;
- Tailscale somente se houver necessidade real de administração remota;
- UPS/NUT;
- GitHub Actions para validar YAML e shell scripts.

Esses itens não são necessários para considerar o HomeLab atual operacional.

## Critério para adicionar serviços

Antes de instalar qualquer novo container:

```bash
free -h
df -h /
docker stats --no-stream
docker system df
```

Pergunte:

1. esse serviço resolve uma necessidade concreta?
2. duplica algo que já existe?
3. aumenta o risco para DNS/DHCP?
4. cabe confortavelmente em 4 GB de RAM e 32 GB de armazenamento?
5. está incluído na estratégia de backup e monitoramento?

Preserve recursos para os serviços essenciais.
