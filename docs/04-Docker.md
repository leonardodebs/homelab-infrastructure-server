# 04 — Docker Engine e Compose

## Remover pacotes conflitantes

```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  sudo apt-get remove -y "$pkg"
done
```

## Adicionar o repositório oficial

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

```bash
. /etc/os-release
printf '%s\n' \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
```

## Instalar

```bash
sudo apt update
sudo apt install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
```

## Permitir uso sem sudo

```bash
sudo usermod -aG docker "$USER"
newgrp docker
```

## Configurar logs e inicialização

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
```

```bash
sudo systemctl enable --now docker
sudo systemctl restart docker
```

## Testes

```bash
docker version
docker compose version
docker run --rm hello-world
systemctl is-enabled docker
systemctl is-active docker
```

## Comandos operacionais

```bash
docker ps
docker ps -a
docker images
docker stats
docker system df
docker compose up -d
docker compose logs -f
docker compose pull
docker compose down
```

## Observação sobre firewall

Portas publicadas por containers são tratadas pelo Docker e podem não seguir o comportamento esperado das regras UFW comuns. Por isso, este projeto:

- usa `network_mode: host` somente para o AdGuard Home;
- vincula Portainer e Uptime Kuma ao IP da LAN;
- não publica portas no modem;
- documenta regras adicionais no capítulo de UFW.

## Validação

- [ ] Docker ativo no boot;
- [ ] usuário consegue executar `docker ps` sem sudo;
- [ ] Compose plugin instalado;
- [ ] política de rotação de logs aplicada;
- [ ] `hello-world` executado com sucesso.
