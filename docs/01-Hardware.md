# 01 — Hardware e preparação

## Equipamento

- Dell Wyse N03D / 3290;
- Intel Celeron N2807;
- 4 GB DDR3;
- SSD mSATA de 16 GB;
- HDMI;
- Wi-Fi;
- Ethernet;
- fonte de alimentação.

## Materiais necessários

- pendrive de 8 GB ou maior;
- cabo HDMI;
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
   - capacidade do mSATA;
   - senha fornecida pelo vendedor.
5. Confirmar que o boot USB está disponível.
6. Testar Ethernet, HDMI e portas USB.
7. Manter o Windows original somente até finalizar os testes físicos.

## Configuração de BIOS

Os nomes podem variar conforme a versão instalada.

- habilitar boot por USB;
- preferir modo UEFI quando disponível;
- deixar o SSD interno como primeiro disco após a instalação;
- desabilitar PXE/network boot se não for utilizado;
- configurar restauração automática após falta de energia, caso exista a opção `AC Recovery`;
- manter data e hora corretas;
- remover a senha da BIOS somente se souber a senha atual e considerar seguro.

## Criação do pendrive no Rufus

1. Selecionar a ISO `ubuntu-24.04.x-live-server-amd64.iso`.
2. Usar GPT/UEFI quando suportado.
3. Iniciar a gravação.
4. Se o boot UEFI falhar, recriar usando MBR/BIOS ou UEFI-CSM.

## Limitações do SSD de 16 GB

O sistema cabe no disco, mas haverá pouca margem. Por isso:

- não instalar ambiente gráfico;
- não armazenar backups no próprio SSD;
- limitar logs do systemd e Docker;
- evitar bancos de dados e serviços pesados;
- monitorar espaço livre regularmente;
- planejar mSATA de 120 ou 240 GB como upgrade.

## Validação antes da instalação

- [ ] BIOS acessível;
- [ ] senha da BIOS conhecida;
- [ ] boot USB funcional;
- [ ] SSD detectado;
- [ ] 4 GB de RAM detectados;
- [ ] Ethernet funcional;
- [ ] fonte estável;
- [ ] equipamento sem superaquecimento ou reinicializações.
