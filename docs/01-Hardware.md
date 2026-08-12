# 01 — Hardware e preparação

## Equipamento recebido

- Dell Wyse N03D / 3290;
- Intel Celeron N2807 @ 1.58 GHz;
- 4 GB DDR3 / 1333 MT/s;
- SATA Flash Drive interno de 32 GB;
- HDMI e VGA;
- Wi-Fi disponível, mas fora da operação principal;
- portas USB;
- fonte de alimentação.

A Ethernet onboard apresentou problema de link. A interface principal do HomeLab passou a ser um adaptador **TP-Link UE300 USB 3.0 Gigabit Ethernet**, validado em 1 Gbps/full duplex.

## BIOS observada

Na inspeção do equipamento real:

- firmware Phoenix SecureCore;
- BIOS `1.0R`;
- data `2017-12-22`;
- CPU e 4096 MB de RAM reconhecidos;
- SATA Flash de 32 GB reconhecido;
- boot USB validado.

Não registre Service Tag, serial, MAC address ou outros identificadores únicos em documentação pública.

## Estado atual

O Windows 10 Pro original foi removido e o armazenamento interno foi dedicado ao **Ubuntu Server 24.04.4 LTS**.

O HomeLab opera atualmente com:

```text
SATA Flash 32 GB -> produção
Pendrive USB 128 GB -> backup Restic
```

O pendrive de backup foi validado com F3, formatado em ext4 e montado em `/srv/backup`.

O SSD de 120 GB permanece planejado para o fim de 2026.

## Materiais usados na implantação

- pendrive de instalação do Ubuntu;
- cabo HDMI/VGA e teclado USB para instalação/recuperação local;
- adaptador TP-Link UE300 + cabo RJ45;
- notebook para criação da mídia e administração SSH;
- Ubuntu Server 24.04 LTS amd64;
- mídia USB dedicada ao backup.

## Configuração de BIOS

- boot USB habilitado;
- armazenamento interno como disco de sistema;
- UEFI utilizado conforme suporte do equipamento;
- PXE desnecessário para a operação atual;
- nenhuma alteração de firmware forçada;
- Secure Boot permanece fora da implantação atual;
- não alterar opções desconhecidas sem necessidade.

O `fwupdmgr` não ofereceu atualização de BIOS aplicável ao equipamento. Atualização de dbx/UEFI não foi forçada devido às limitações observadas de efivarfs.

## Operação com SATA Flash de 32 GB

O Ubuntu e a stack atual cabem no armazenamento, mas o ambiente deve permanecer enxuto:

- não instalar ambiente gráfico;
- não armazenar snapshots Restic no disco interno;
- limitar logs do systemd e Docker;
- evitar bancos de dados grandes e serviços pesados;
- remover imagens Docker não utilizadas de forma controlada;
- monitorar `df -h`, `docker system df` e `journalctl --disk-usage`;
- manter preferencialmente 20% ou mais de espaço livre.

## Mídia de backup atual

A implantação não depende mais do HD externo de 1 TB planejado inicialmente. A mídia operacional atual é um pendrive USB de 128 GB nominais, adequado ao volume atual de configurações e volumes persistentes.

O HD externo de maior capacidade pode ser reutilizado futuramente como segunda cópia ou substituição da mídia atual.

## Upgrade futuro

Planejado para o fim de 2026:

```text
SATA Flash 32 GB -> SSD 120 GB
```

A estratégia preferida é instalação limpa do Ubuntu no SSD e recuperação a partir do GitHub + Restic. O SATA Flash antigo deve ser preservado temporariamente como rollback físico.

## Validação concluída

- [x] BIOS acessível;
- [x] CPU N2807 detectada;
- [x] 4 GB de RAM detectados;
- [x] SATA Flash de 32 GB detectado;
- [x] boot USB validado;
- [x] Ubuntu Server instalado;
- [x] Ethernet principal validada via TP-Link UE300;
- [x] portas USB usadas com sucesso;
- [x] servidor operando sem reinicializações anormais observadas durante a implantação;
- [x] mídia USB de backup validada e montada.
