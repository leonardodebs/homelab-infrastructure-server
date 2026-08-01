# 15 — Upgrades e evolução

## Prioridade 1 — SSD mSATA maior

O upgrade mais importante é substituir os 16 GB por 120 ou 240 GB.

Benefícios:

- mais margem para atualizações;
- maior retenção de logs;
- backups temporários locais;
- possibilidade de novos containers;
- menor risco de indisponibilidade por disco cheio.

Antes da troca:

1. execute `scripts/backup.sh`;
2. copie o backup para o notebook;
3. exporte as configurações do AdGuard e Portainer;
4. anote Netplan, hostname e usuários;
5. instale Ubuntu limpo no novo SSD;
6. reinstale Docker e Unbound;
7. restaure os volumes.

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
- backup automático para NAS ou notebook;
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

Mantenha no mínimo 20% do SSD livre e preserve recursos para DNS e DHCP.
