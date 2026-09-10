#!/usr/bin/env bash
# ============================================================================
# install-docker-homelab.sh
# Instala Docker Engine oficial no Ubuntu Server 24.04 LTS (Noble),
# valida cada etapa e prepara o host para uso no Home Lab.
#
# Uso recomendado:
#   chmod +x install-docker-homelab.sh
#   sudo ./install-docker-homelab.sh
#
# Opcional:
#   sudo ./install-docker-homelab.sh --user leonardo
# ============================================================================

set -Eeuo pipefail

LOG_FILE="/var/log/homelab-docker-install.log"
TARGET_USER=""
STAGE=0

if [[ -t 1 ]]; then
    GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    GREEN=''; YELLOW=''; RED=''; BLUE=''; BOLD=''; NC=''
fi

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[AVISO]${NC} $*"; }
fail()  { echo -e "${RED}[ERRO]${NC} $*" >&2; exit 1; }
stage() { STAGE=$((STAGE + 1)); echo; echo -e "${BOLD}========== ETAPA ${STAGE}: $* ==========${NC}"; }

on_error() {
    local exit_code=$?
    echo
    echo -e "${RED}[ERRO] Falha na etapa ${STAGE}, linha ${BASH_LINENO[0]}. Código: ${exit_code}.${NC}" >&2
    echo -e "${RED}[ERRO] Consulte o log: ${LOG_FILE}${NC}" >&2
    exit "$exit_code"
}
trap on_error ERR

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            [[ $# -ge 2 ]] || fail "Informe um usuário após --user."
            TARGET_USER="$2"
            shift 2
            ;;
        -h|--help)
            cat <<'EOF'
Uso:
  sudo ./install-docker-homelab.sh
  sudo ./install-docker-homelab.sh --user leonardo

Etapas:
  1. Valida Ubuntu 24.04, amd64, Internet e espaço.
  2. Remove pacotes Docker conflitantes, se existirem.
  3. Configura chave e repositório oficial da Docker.
  4. Valida a origem do pacote docker-ce.
  5. Instala Engine, CLI, containerd, Buildx e Compose.
  6. Habilita e valida serviços.
  7. Configura logging local com rotação.
  8. Executa hello-world.
  9. Adiciona usuário ao grupo docker.
 10. Faz auditoria final.
EOF
            exit 0
            ;;
        *) fail "Argumento desconhecido: $1" ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "Este script precisa de privilégios administrativos."
    if [[ -n "$TARGET_USER" ]]; then
        exec sudo -E bash "$0" --user "$TARGET_USER"
    else
        exec sudo -E bash "$0"
    fi
fi

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo
echo "============================================================"
echo "       INSTALAÇÃO DOCKER - HOME LAB"
echo "============================================================"
echo "Início: $(date --iso-8601=seconds)"
echo "Log:    $LOG_FILE"

stage "Validando sistema operacional e hardware"

[[ -r /etc/os-release ]] || fail "/etc/os-release não encontrado."
# shellcheck disable=SC1091
source /etc/os-release

[[ "${ID:-}" == "ubuntu" ]] || fail "Este script foi preparado para Ubuntu. Detectado: ${ID:-desconhecido}"
[[ "${VERSION_CODENAME:-}" == "noble" || "${UBUNTU_CODENAME:-}" == "noble" ]] \
    || fail "Este script foi validado para Ubuntu 24.04 Noble. Detectado: ${PRETTY_NAME:-desconhecido}"

ARCH="$(dpkg --print-architecture)"
[[ "$ARCH" == "amd64" ]] || fail "Arquitetura esperada: amd64. Detectada: $ARCH"

ok "Sistema: ${PRETTY_NAME}"
ok "Arquitetura: ${ARCH}"
info "Kernel: $(uname -r)"
info "Hostname: $(hostname)"

FREE_KB="$(df --output=avail / | tail -1 | tr -d ' ')"
FREE_GB=$((FREE_KB / 1024 / 1024))
info "Espaço livre em /: aproximadamente ${FREE_GB} GiB"
if (( FREE_GB < 5 )); then
    fail "Menos de 5 GiB livres em /. Libere espaço antes de instalar Docker."
elif (( FREE_GB < 10 )); then
    warn "Há menos de 10 GiB livres. Docker funcionará, mas monitore o armazenamento."
else
    ok "Espaço em disco suficiente."
fi

MEM_MB="$(awk '/MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)"
info "RAM detectada: aproximadamente ${MEM_MB} MiB"

stage "Identificando usuário administrador do Docker"

if [[ -z "$TARGET_USER" ]]; then
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        TARGET_USER="$SUDO_USER"
    else
        TARGET_USER="$(logname 2>/dev/null || true)"
    fi
fi

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]] || ! id "$TARGET_USER" >/dev/null 2>&1; then
    CANDIDATE="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}')"
    [[ -n "$CANDIDATE" ]] && TARGET_USER="$CANDIDATE"
fi

if [[ -n "$TARGET_USER" && "$TARGET_USER" != "root" ]] && id "$TARGET_USER" >/dev/null 2>&1; then
    ok "Usuário Docker: $TARGET_USER"
else
    TARGET_USER=""
    warn "Nenhum usuário comum identificado. A etapa do grupo docker será ignorada."
fi

stage "Validando conectividade com download.docker.com"

if ! command -v curl >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
fi

curl -fsSL --connect-timeout 10 --max-time 30 \
    https://download.docker.com/linux/ubuntu/gpg -o /dev/null \
    || fail "Não foi possível acessar download.docker.com. Verifique DNS/Internet/horário."
ok "Repositório oficial Docker acessível."

stage "Removendo pacotes conflitantes, se existirem"

CONFLICTS=(docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc)
INSTALLED_CONFLICTS=()
for pkg in "${CONFLICTS[@]}"; do
    if dpkg-query -W -f='${db:Status-Abbrev}' "$pkg" 2>/dev/null | grep -q '^ii'; then
        INSTALLED_CONFLICTS+=("$pkg")
    fi
done

if (( ${#INSTALLED_CONFLICTS[@]} > 0 )); then
    info "Removendo: ${INSTALLED_CONFLICTS[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get remove -y "${INSTALLED_CONFLICTS[@]}"
    ok "Pacotes conflitantes removidos."
else
    ok "Nenhum pacote conflitante instalado."
fi

stage "Instalando pré-requisitos"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl python3
ok "Pré-requisitos instalados (ca-certificates, curl e python3)."

stage "Configurando chave oficial da Docker"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
[[ -s /etc/apt/keyrings/docker.asc ]] || fail "A chave Docker foi criada vazia."
grep -q "BEGIN PGP PUBLIC KEY BLOCK" /etc/apt/keyrings/docker.asc \
    || fail "docker.asc não parece ser uma chave PGP ASCII válida."
ok "Chave instalada em /etc/apt/keyrings/docker.asc"

stage "Configurando repositório oficial Docker"
CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

cat /etc/apt/sources.list.d/docker.sources
apt-get update
apt-cache policy docker-ce | grep -q "download.docker.com" \
    || fail "docker-ce não está vindo de download.docker.com."
CANDIDATE="$(apt-cache policy docker-ce | awk '/Candidate:/ {print $2; exit}')"
[[ -n "$CANDIDATE" && "$CANDIDATE" != "(none)" ]] \
    || fail "Nenhuma versão candidata de docker-ce encontrada."
ok "Repositório oficial validado."
info "Versão candidata docker-ce: $CANDIDATE"

stage "Instalando Docker Engine, CLI, containerd, Buildx e Compose"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" \
        || fail "Pacote não instalado corretamente: $pkg"
done
ok "Todos os pacotes oficiais foram instalados."

stage "Habilitando e validando serviços"
systemctl enable --now containerd
systemctl enable --now docker
systemctl is-active --quiet containerd || fail "containerd não está ativo."
systemctl is-active --quiet docker || fail "Docker não está ativo."
systemctl is-enabled --quiet containerd || fail "containerd não está habilitado no boot."
systemctl is-enabled --quiet docker || fail "Docker não está habilitado no boot."
ok "containerd ativo e habilitado."
ok "docker ativo e habilitado."

stage "Configurando rotação de logs para proteger o armazenamento"
mkdir -p /etc/docker
if [[ -e /etc/docker/daemon.json ]]; then
    BACKUP="/etc/docker/daemon.json.backup.$(date +%Y%m%d-%H%M%S)"
    cp -a /etc/docker/daemon.json "$BACKUP"
    warn "/etc/docker/daemon.json já existia. Backup: $BACKUP"
    warn "Por segurança, ele NÃO será sobrescrito automaticamente."
else
    cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    python3 -m json.tool /etc/docker/daemon.json >/dev/null
    dockerd --validate --config-file=/etc/docker/daemon.json
    systemctl restart docker
    systemctl is-active --quiet docker || fail "Docker não voltou após configurar daemon.json."
    CURRENT_LOG_DRIVER="$(docker info --format '{{.LoggingDriver}}')"
    [[ "$CURRENT_LOG_DRIVER" == "local" ]] \
        || fail "Logging driver esperado: local; detectado: $CURRENT_LOG_DRIVER"
    ok "Logging local configurado: max-size=10m, max-file=3."
fi

stage "Validando versões"
docker --version
docker compose version
docker buildx version
command -v docker >/dev/null 2>&1 || fail "Comando docker não encontrado."
docker compose version >/dev/null 2>&1 || fail "Docker Compose Plugin não está funcional."
docker buildx version >/dev/null 2>&1 || fail "Docker Buildx não está funcional."
ok "Docker CLI, Compose e Buildx funcionais."

stage "Executando teste hello-world"
docker run --rm hello-world
ok "hello-world executado com sucesso."

stage "Configurando acesso Docker para usuário comum"
if [[ -n "$TARGET_USER" ]]; then
    getent group docker >/dev/null 2>&1 || groupadd docker
    if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx docker; then
        ok "$TARGET_USER já pertence ao grupo docker."
    else
        usermod -aG docker "$TARGET_USER"
        ok "$TARGET_USER adicionado ao grupo docker."
    fi
    getent group docker | grep -q "$TARGET_USER" \
        || warn "O grupo foi alterado, mas a nova sessão ainda será necessária para refletir a associação."
    warn "Feche e abra novamente a sessão SSH para usar Docker sem sudo."
else
    warn "Etapa de usuário ignorada."
fi

stage "Auditoria final"
echo
echo "--- Serviços ---"
printf "docker:     "; systemctl is-active docker
printf "containerd: "; systemctl is-active containerd

echo
echo "--- Inicialização automática ---"
printf "docker:     "; systemctl is-enabled docker
printf "containerd: "; systemctl is-enabled containerd

echo
echo "--- Versões ---"
docker --version
docker compose version
docker buildx version

echo
echo "--- Docker Info ---"
docker info --format 'Server Version: {{.ServerVersion}}'
docker info --format 'Storage Driver: {{.Driver}}'
docker info --format 'Logging Driver: {{.LoggingDriver}}'
docker info --format 'Containers: {{.Containers}}'
docker info --format 'Images: {{.Images}}'

echo
echo "--- Espaço ---"
df -h /
docker system df

echo
echo "--- Containers ---"
docker ps -a

echo
echo "============================================================"
echo -e "${GREEN}${BOLD}INSTALAÇÃO CONCLUÍDA COM SUCESSO${NC}"
echo "============================================================"
echo "Fim: $(date --iso-8601=seconds)"
echo "Log: $LOG_FILE"

if [[ -n "$TARGET_USER" ]]; then
    echo
    echo "IMPORTANTE: feche e abra novamente a sessão SSH."
    echo "Depois valide sem sudo:"
    echo "  docker ps"
    echo "  docker compose version"
    echo "  docker run --rm hello-world"
fi
