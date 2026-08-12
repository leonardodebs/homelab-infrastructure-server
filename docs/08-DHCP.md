# 08 — DHCP no AdGuard Home

O DHCPv4 da rede residencial foi migrado do Huawei HG8145V5-V2 para o AdGuard Home.

## Estado atual validado

```text
Servidor DHCP : 192.168.100.2
Gateway       : 192.168.100.1
Rede          : 192.168.100.0/24
Pool          : 192.168.100.50 - 192.168.100.200
Lease         : 86400 segundos
DNS           : 192.168.100.2
Domínio       : home.arpa
DHCPv6        : desativado
```

A interface usada pelo DHCP é a Ethernet principal via TP-Link UE300. O nome exato da interface deve ser obtido no servidor:

```bash
ip -o -4 addr show | awk '$4 ~ /^192\.168\.100\.2\// {print $2}'
```

Não publique MAC address ou nome de interface derivado de MAC como identificador permanente em documentação pública.

## Pré-requisitos para uma reinstalação

- servidor em `192.168.100.2`;
- gateway em `192.168.100.1`;
- AdGuard respondendo em `:53`;
- Unbound respondendo em `127.0.0.1:5335`;
- acesso administrativo ao Huawei;
- um cliente preparado para usar IP manual em caso de rollback.

## Configuração de emergência

Exemplo temporário para um notebook:

```text
IP:      192.168.100.20
Máscara: 255.255.255.0
Gateway: 192.168.100.1
DNS:     192.168.100.2
```

Use apenas durante recuperação; não deixe IPs manuais conflitarem com leases/reservas existentes.

## Configurar DHCP no AdGuard

Em **Settings > DHCP settings**:

```text
Interface: interface Ethernet principal do servidor
Gateway: 192.168.100.1
Subnet mask: 255.255.255.0
Range start: 192.168.100.50
Range end: 192.168.100.200
Lease duration: 86400
Domain name: home.arpa
```

O IP `192.168.100.2` permanece fora do pool.

Reservas DHCP são opcionais e devem ser criadas somente para dispositivos que precisem de endereço previsível.

## Migração executada

A ordem usada foi:

1. validar DNS/Unbound;
2. configurar DHCP no AdGuard;
3. desativar DHCPv4 no Huawei;
4. ativar DHCPv4 no AdGuard;
5. renovar leases de clientes;
6. conferir gateway, DHCP Server e DNS recebidos;
7. validar Internet e Query Log.

Nunca mantenha os dois servidores DHCP ativos simultaneamente na mesma LAN.

## Renovar lease no Windows

```powershell
ipconfig /release
ipconfig /renew
ipconfig /all
```

O esperado é:

```text
DHCP Server:    192.168.100.2
Default Gateway: 192.168.100.1
DNS Servers:   192.168.100.2
```

## Testes

```powershell
ping 192.168.100.1
ping 192.168.100.2
nslookup ubuntu.com
nslookup doubleclick.net
```

No AdGuard, confirme o lease/hostname do cliente e as consultas no Query Log.

## Logs úteis

```bash
docker logs --tail 200 adguardhome
sudo ss -lunp | grep -E ':(67|68)\b'
ip -br address
```

Mensagens como `no existing lease` durante renovação podem ocorrer quando um cliente solicita endereço antes de possuir lease atual. Investigue somente se o cliente não conseguir obter configuração válida.

## Rollback

Se o DHCP do AdGuard falhar:

1. use IP manual temporário em um notebook;
2. acesse `192.168.100.1`;
3. reative DHCPv4 no Huawei;
4. desative DHCP no AdGuard;
5. renove leases dos clientes;
6. investigue antes de repetir a migração.

## Cuidados operacionais

- manter o Wyse ligado 24x7;
- garantir que Docker e AdGuard iniciem após reboot;
- não habilitar DHCPv6 sem projeto específico;
- manter UFW permitindo UDP/67 somente pela interface LAN;
- não usar o Wi-Fi do Wyse como interface DHCP principal.

## Checklist atual

- [x] DHCP do Huawei desativado;
- [x] DHCPv4 do AdGuard ativo;
- [x] clientes recebem endereços do pool atual;
- [x] gateway `192.168.100.1`;
- [x] DNS entregue `192.168.100.2`;
- [x] Internet funcional;
- [x] bloqueios aparecem no Query Log;
- [x] DHCPv6 permanece desativado.
