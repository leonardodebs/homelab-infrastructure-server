# 01 — Hardware e preparação

## Equipamento recebido

- Dell Wyse N03D / 3290;
- Intel Celeron N2807 @ 1.58 GHz;
- 4 GB DDR3;
- memória observada na BIOS: 1333 MT/s;
- SATA Flash Drive de 32 GB instalado e reconhecido;
- HDMI;
- VGA;
- Wi-Fi;
- Ethernet;
- portas USB;
- fonte de alimentação.

## BIOS observada

Na inspeção inicial do equipamento real:

- firmware: Phoenix SecureCore;
- versão da BIOS: `1.0R`;
- data da BIOS: `2017-12-22`;
- CPU reconhecida corretamente;
- 4096 MB de memória reconhecidos;
- `SATA PORT0`: `32GB SATA Flash Drive`;
- acesso ao setup da BIOS validado.

Não registre Service Tag, serial ou outros identificadores únicos em documentação pública.

## Estado recebido

O Wyse chegou inicializando com Windows 10 Pro. O Windows será removido e o disco interno de 32 GB será dedicado integralmente ao Ubuntu Server 24.04 LTS.

O SSD de 120 GB está planejado somente para o fim de 2026. Até lá, o HomeLab será implantado e operado no SATA Flash de 32 GB.

## Materiais necessários

- pendrive de 8 GB ou maior;
- cabo HDMI ou VGA compatível com o monitor;
- teclado USB;
- cabo de rede RJ45;
- notebook Windows para criar o pendrive;
- ISO do Ubuntu Server 24.04 LTS amd64;
- Rufus ou Ventoy.

## Checklist ao receber

1. Fotografar embalagem e estado do equipamento.
2. Conferir fonte, cabo e sinais de dano.
3. Ligar o Wyse antes de formatar.
4. Abrir a BIOS e anotar:
   - versão da BIOS;
   - modelo da CPU;
   - quantidade de RAM;
   - capacidade do armazenamento interno;
   - configuração de boot.
5. Confirmar que o boot USB está disponível.
6. Testar Ethernet, vídeo e portas USB.
7. Manter o Windows original somente até finalizar os testes físicos.

## Configuração de BIOS

Os nomes podem variar conforme a versão instalada.

- habilitar boot por USB;
- preferir modo UEFI quando disponível e compatível;
- deixar o armazenamento interno como primeiro disco após a instalação;
- desabilitar PXE/network boot se não for utilizado;
- configurar restauração automática após falta de energia, caso exista a opção `AC Recovery`, `After Power Loss` ou equivalente;
- manter data e hora corretas;
- não alterar configurações desconhecidas sem necessidade.

## Criação do pendrive no Rufus

1. Selecionar a ISO `ubuntu-24.04.x-live-server-amd64.iso`.
2. Usar GPT/UEFI quando suportado.
3. Iniciar a gravação.
4. Se o boot UEFI falhar, recriar usando MBR/BIOS ou UEFI-CSM conforme o suporte real da BIOS.

## Operação com SATA Flash de 32 GB

O Ubuntu Server e a stack inicial cabem no disco de 32 GB, mas o ambiente deve permanecer enxuto:

- não instalar ambiente gráfico;
- não armazenar backups no disco interno;
- limitar logs do systemd e Docker;
- evitar bancos de dados grandes e serviços pesados;
- remover imagens Docker sem uso;
- monitorar `df -h`, `docker system df` e uso do journal;
- manter preferencialmente 20% ou mais do disco livre.

O HD externo Seagate de 1 TB será o destino dos backups Restic e testes de restauração.

## Upgrade futuro

Planejado para o fim de 2026:

```text
SATA Flash 32 GB -> SSD 120 GB
```

A estratégia preferida é realizar instalação limpa do Ubuntu no SSD novo e recuperar configurações e dados a partir do GitHub e dos backups Restic. Isso transforma a troca de armazenamento em um teste real de disaster recovery.

## Validação antes da instalação

- [x] BIOS acessível;
- [x] CPU N2807 detectada;
- [x] 4 GB de RAM detectados;
- [x] SATA Flash de 32 GB detectado;
- [x] equipamento inicializando;
- [ ] boot USB validado;
- [ ] Ethernet validada no Ubuntu;
- [ ] portas USB validadas no Ubuntu;
- [ ] opção de recuperação após falta de energia revisada;
- [ ] Ubuntu Server instalado;
- [ ] equipamento validado sem superaquecimento ou reinicializações.
