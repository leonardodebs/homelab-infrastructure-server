# 08 — Migração do DHCP para o AdGuard Home

Esta é a etapa mais sensível do projeto. Execute somente depois de validar DNS, Unbound e IP estático.

## Pré-requisitos

- Wyse em `192.168.100.2`;
- gateway em `192.168.100.1`;
- AdGuard respondendo na porta 53;
- Unbound respondendo em `127.0.0.1:5335`;
- acesso ao painel do modem;
- um notebook preparado com IP manual de emergência.

## Configuração de emergência

Antes da mudança, anote esta configuração manual para o notebook:

```text
IP:      192.168.100.20
Máscara: 255.255.255.0
Gateway: 192.168.100.1
DNS:     192.168.100.2
```

Ela permitirá acessar modem e servidor se o DHCP falhar.

## Configurar DHCP no AdGuard

No painel, abra **Settings > DHCP settings**.

Parâmetros sugeridos:

```text
Interface: interface Ethernet do Wyse
Gateway: 192.168.100.1
Subnet mask: 255.255.255.0
Range start: 192.168.100.50
Range end: 192.168.100.200
Lease duration: 86400 segundos
DNS: 192.168.100.2
Domain name: home.arpa
```

Antes de ativar, configure reservas para os dispositivos importantes.

Exemplo:

| Dispositivo | IP reservado |
|---|---|
| Notebook pessoal | `192.168.100.21` |
| Notebook trabalho | `192.168.100.22` |
| Smart TV 1 | `192.168.100.31` |
| Smart TV 2 | `192.168.100.32` |

Não inclua o IP do servidor no pool DHCP.

## Janela de mudança

1. Salve a configuração DHCP no AdGuard, mas deixe o serviço desativado.
2. Avise os usuários de que a rede pode ficar indisponível por alguns minutos.
3. Abra o painel do modem em `192.168.100.1`.
4. Desative o DHCP do modem.
5. Salve a alteração.
6. Ative imediatamente o DHCP no AdGuard Home.
7. Reinicie a conexão de um único cliente para teste.

## Renovar lease no Windows

```powershell
ipconfig /release
ipconfig /renew
ipconfig /all
```

Valide:

```text
DHCP Server: 192.168.100.2
Default Gateway: 192.168.100.1
DNS Servers: 192.168.100.2
```

## Renovar no Linux

```bash
sudo dhclient -r
sudo dhclient
ip address
ip route
resolvectl status
```

## Testes

```powershell
ping 192.168.100.1
ping 192.168.100.2
nslookup ubuntu.com
```

No AdGuard, confira se o cliente aparece com seu IP e se as consultas são registradas.

## Rollback

Se os clientes não receberem IP:

1. Configure o notebook com o IP manual de emergência.
2. Acesse `192.168.100.1`.
3. Reative o DHCP do modem.
4. Desative o DHCP do AdGuard.
5. Investigue logs e configuração.

Logs úteis:

```bash
docker logs --tail 200 adguardhome
sudo ss -lunp | grep -E ':67 |:68 '
ip -br address
```

## Cuidados

- nunca mantenha dois servidores DHCP ativos na mesma LAN;
- não use o Wi-Fi do Wyse como interface DHCP principal;
- mantenha o Wyse ligado 24x7;
- após falta de energia, valide se Docker e AdGuard iniciaram;
- evite reiniciar o servidor durante horários críticos.

## Checklist final

- [ ] DHCP do modem desativado;
- [ ] DHCP do AdGuard ativo;
- [ ] clientes recebem IP do pool correto;
- [ ] gateway correto;
- [ ] DNS aponta somente para o Wyse;
- [ ] Internet funciona;
- [ ] bloqueio aparece no Query Log;
- [ ] reservas DHCP aplicadas.
