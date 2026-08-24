# 04 — Docker Engine e Compose

## Instalação

A implantação usa o repositório oficial do Docker para Ubuntu.

```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  sudo apt-get remove -y "$pkg"
done

sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
printf '%s\n' \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
sudo apt install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

## Uso sem sudo

```bash
sudo usermod -aG docker "$USER"
```

Faça logout/login ou abra uma nova sessão antes de validar:

```bash
docker ps
```

## Configuração do daemon

O projeto limita o crescimento de logs e mantém `live-restore`:

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF

sudo systemctl enable --now docker
sudo systemctl restart docker
```

## Stack atual

O arquivo oficial é:

```text
compose/compose.yaml
```

A stack `homelab` contém:

- `portainer`;
- `adguardhome`;
- `uptime-kuma`;
- `homelab-web`;
- `diun`.

O Unbound não roda em Docker; ele é um serviço nativo do Ubuntu.

## Comandos operacionais

```bash
cd ~/homelab-infrastructure-server

docker compose --env-file compose/.env -f compose/compose.yaml ps
docker compose --env-file compose/.env -f compose/compose.yaml logs -f
docker compose --env-file compose/.env -f compose/compose.yaml pull
docker compose --env-file compose/.env -f compose/compose.yaml up -d
```

Para atualizar um único serviço:

```bash
docker compose --env-file compose/.env -f compose/compose.yaml pull SERVICO
docker compose --env-file compose/.env -f compose/compose.yaml up -d SERVICO
```

## Persistência

Volumes nomeados atuais:

```text
homelab_portainer_data
homelab_adguard_work
homelab_adguard_conf
homelab_uptime_kuma_data
homelab_diun_data
```

Esses volumes são tratados pela política de backup Restic quando existem.

O `homelab-web` é stateless: os arquivos do portal ficam no diretório `web/` do próprio repositório e são montados somente leitura no Nginx.

## Segurança

- `no-new-privileges:true` é usado nos containers da stack;
- interfaces web são vinculadas a `192.168.100.2`, não a todas as interfaces;
- AdGuard Home usa `network_mode: host` por causa de DNS/DHCP;
- Portainer e Diun precisam acessar o Docker socket;
- nenhuma porta Docker é encaminhada no modem.

## Docker e UFW

Portas publicadas pelo Docker podem ser processadas antes das regras UFW comuns. Por isso o projeto combina:

- binding explícito no IP da LAN;
- UFW no host;
- regras específicas da rede Docker para checks do Uptime Kuma;
- ausência de port forwarding externo.

Consulte `docs/11-UFW.md`.

## Validação

```bash
docker version
docker compose version
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker system df
systemctl is-enabled docker
systemctl is-active docker
```

Estado atual:

- [x] Docker ativo no boot;
- [x] Compose plugin instalado;
- [x] usuário administrativo executa Docker sem sudo;
- [x] rotação de logs configurada;
- [x] stack `homelab` operacional.
