# 10 — Migração do Beszel para Grafana

## Estado atual

O Beszel Hub e o Beszel Agent foram aposentados em 24/08/2026 depois da
validação do dashboard `Dell Overview` no Grafana do Lenovo. O monitoramento do
Dell agora usa:

- Node Exporter em `192.168.100.2:9100`;
- cAdvisor em `192.168.100.2:8081`;
- Prometheus e Grafana em `192.168.100.3`;
- alertas enviados por e-mail pelo Alertmanager.

As portas dos exporters aceitam somente a origem `192.168.100.3`. A antiga
porta `8090/tcp` foi removida do Compose e do UFW.

## Backup de retirada

Antes da remoção dos containers e volumes, os dados foram arquivados em:

```text
/home/leonardo/backups/beszel-retirement/20260824-145811
```

O diretório contém os arquivos `homelab_beszel_data.tar.gz`,
`homelab_beszel_agent_data.tar.gz` e `SHA256SUMS`.

## Restauração excepcional

Use somente se for necessário recuperar o histórico antigo. Crie volumes
temporários, valide os checksums e restaure os arquivos sem reabrir a porta
`8090/tcp` até que a necessidade seja confirmada.

```bash
cd /home/leonardo/backups/beszel-retirement/20260824-145811
sha256sum -c SHA256SUMS
```

O Compose atual não contém mais os serviços nem os volumes do Beszel. Uma
reativação exige reintroduzir explicitamente a configuração e revisar o UFW.
