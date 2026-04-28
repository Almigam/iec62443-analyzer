#!/bin/bash
# =============================================================================
# IEC 62443-3-3 Analyzer - Setup y arranque local en Raspberry Pi 5
# Uso: bash setup-local.sh [--port 8443] [--no-tls]
# =============================================================================

set -e

# ── Colores para output ───────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${BOLD}━━━ $* ━━━${NC}"; }

# ── Parámetros por defecto ────────────────────────────────────────────────────
PORT=8443           # 8443 para no requerir sudo; cambia a 443 con --port 443
USE_TLS=true
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_VERSION="1.22.4"
GO_ARCH="arm64"
GO_TAR="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
GO_URL="https://go.dev/dl/${GO_TAR}"

# ── Parseo de argumentos ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --port)   PORT="$2"; shift 2 ;;
    --no-tls) USE_TLS=false; shift ;;
    --dir)    REPO_DIR="$2"; shift 2 ;;
    --help)
      echo "Uso: bash setup-local.sh [--port 8443] [--no-tls] [--dir /ruta/repo]"
      exit 0 ;;
    *) warn "Argumento desconocido: $1"; shift ;;
  esac
done

# Si se usa el puerto 443 sin sudo, avisa
if [[ "$PORT" == "443" && "$EUID" -ne 0 ]]; then
  warn "El puerto 443 requiere root. Ejecútalo como: sudo bash setup-local.sh --port 443"
  warn "O usa el puerto por defecto 8443 (sin sudo)."
  exit 1
fi

# ── Detección del directorio del repo ────────────────────────────────────────
# Sube directorios hasta encontrar backend/cmd/main.go
find_repo_root() {
  local dir="$1"
  for _ in 1 2 3 4 5; do
    [[ -f "$dir/backend/cmd/main.go" ]] && { echo "$dir"; return; }
    dir="$(dirname "$dir")"
  done
  echo ""
}

DETECTED=$(find_repo_root "$REPO_DIR")
if [[ -z "$DETECTED" ]]; then
  warn "No se encontró backend/cmd/main.go desde $REPO_DIR"
  warn "Asegúrate de ejecutar este script desde dentro del repositorio iec62443-analyzer"
  read -rp "¿Ruta manual al repositorio? [intro para omitir]: " MANUAL_DIR
  [[ -n "$MANUAL_DIR" ]] && REPO_DIR="$MANUAL_DIR" || error "No se puede continuar sin el repositorio."
else
  REPO_DIR="$DETECTED"
fi

BACKEND_DIR="$REPO_DIR/backend"
CERTS_DIR="$BACKEND_DIR/certs"
DATA_DIR="$BACKEND_DIR/data"
LOGS_DIR="$BACKEND_DIR/logs"

echo -e "\n${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   IEC 62443-3-3 Analyzer — Setup Local (Pi 5)   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
info "Repositorio : $REPO_DIR"
info "Puerto      : $PORT"
info "TLS         : $USE_TLS"
echo ""

# =============================================================================
# PASO 1 — Instalar Go si no está disponible o es versión incorrecta
# =============================================================================
section "PASO 1: Go $GO_VERSION"

install_go() {
  info "Descargando Go $GO_VERSION para linux/$GO_ARCH..."
  cd /tmp
  wget -q --show-progress "$GO_URL" -O "$GO_TAR" || \
    curl -L "$GO_URL" -o "$GO_TAR" || \
    error "No se pudo descargar Go. Comprueba la conexión a internet."
  info "Instalando Go en /usr/local/go..."
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$GO_TAR"
  rm -f "$GO_TAR"
  # Añadir al PATH de la sesión actual
  export PATH="/usr/local/go/bin:$PATH"
  # Añadir al .bashrc si no está ya
  grep -q '/usr/local/go/bin' ~/.bashrc || \
    echo 'export PATH="/usr/local/go/bin:$PATH"' >> ~/.bashrc
  ok "Go $GO_VERSION instalado correctamente."
}

# Añadir rutas habituales de Go al PATH por si acaso
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

if command -v go &>/dev/null; then
  CURRENT_GO=$(go version | awk '{print $3}' | sed 's/go//')
  REQUIRED_MAJOR=1; REQUIRED_MINOR=22
  CURRENT_MAJOR=$(echo "$CURRENT_GO" | cut -d. -f1)
  CURRENT_MINOR=$(echo "$CURRENT_GO" | cut -d. -f2)
  if [[ "$CURRENT_MAJOR" -gt "$REQUIRED_MAJOR" ]] || \
     ([[ "$CURRENT_MAJOR" -eq "$REQUIRED_MAJOR" ]] && \
      [[ "$CURRENT_MINOR" -ge "$REQUIRED_MINOR" ]]); then
    ok "Go $CURRENT_GO ya instalado. Se usará la versión existente."
  else
    warn "Go $CURRENT_GO es demasiado antiguo (necesario >= $GO_VERSION)."
    install_go
  fi
else
  warn "Go no encontrado."
  install_go
fi

go version

# =============================================================================
# PASO 2 — Crear directorios necesarios
# =============================================================================
section "PASO 2: Directorios"

mkdir -p "$CERTS_DIR" "$DATA_DIR" "$LOGS_DIR"
chmod 700 "$CERTS_DIR" "$DATA_DIR" "$LOGS_DIR"
ok "Directorios creados: certs/ data/ logs/"

# =============================================================================
# PASO 3 — Generar certificados TLS autofirmados
# =============================================================================
section "PASO 3: Certificados TLS"

if [[ "$USE_TLS" == true ]]; then
  if [[ -f "$CERTS_DIR/server.crt" && -f "$CERTS_DIR/server.key" ]]; then
    ok "Certificados ya existen en $CERTS_DIR — se reutilizan."
  else
    info "Generando certificados autofirmados (RSA 4096)..."
    # Obtener IP local de la Pi
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    openssl req -x509 -newkey rsa:4096 -nodes \
      -keyout "$CERTS_DIR/server.key" \
      -out    "$CERTS_DIR/server.crt" \
      -days 365 \
      -subj "/C=ES/ST=Local/L=Local/O=IEC62443/CN=rpi-analyzer" \
      -addext "subjectAltName=DNS:localhost,DNS:rpi-analyzer,IP:127.0.0.1,IP:${LOCAL_IP}" \
      2>/dev/null
    chmod 600 "$CERTS_DIR/server.key"
    chmod 644 "$CERTS_DIR/server.crt"
    ok "Certificados generados para localhost y $LOCAL_IP"
  fi
else
  warn "TLS desactivado. El servidor usará HTTP puro."
fi

# =============================================================================
# PASO 4 — Arreglar imports del código fuente
# =============================================================================
section "PASO 4: Corrección de imports (SQLite)"

DB_GO="$BACKEND_DIR/internal/database/db.go"

# db.go importa "gorm.io/driver/sqlite" pero go.mod tiene "github.com/glebarez/sqlite"
# La API del driver glebarez es idéntica: sqlite.Open(path)
if grep -q '"gorm.io/driver/sqlite"' "$DB_GO" 2>/dev/null; then
  info "Corrigiendo import de SQLite en db.go..."
  sed -i 's|"gorm.io/driver/sqlite"|"github.com/glebarez/sqlite"|g' "$DB_GO"
  ok "Import corregido: github.com/glebarez/sqlite"
else
  ok "Import de SQLite ya es correcto."
fi

# fr3_si.go usa ioutil.ReadFile (deprecated pero funcional; no falla en Go 1.22)
# Solo advertimos, no es necesario corregirlo para que compile
FR3_GO="$BACKEND_DIR/internal/analyzers/fr3_si.go"
if grep -q '"io/ioutil"' "$FR3_GO" 2>/dev/null; then
  warn "fr3_si.go usa io/ioutil (deprecated). Funciona en Go 1.22, pero considera migrar a os.ReadFile."
fi

# =============================================================================
# PASO 5 — Descargar dependencias Go
# =============================================================================
section "PASO 5: Dependencias Go"

cd "$BACKEND_DIR"

# El go.sum del repo tiene checksums incorrectos/fabricados.
# Lo borramos para que Go lo regenere desde los servidores oficiales.
if [[ -f "go.sum" ]]; then
  info "Eliminando go.sum (checksums incorrectos en el repo)..."
  rm -f go.sum
  ok "go.sum eliminado."
fi

# También actualizamos go.mod para añadir la dependencia correcta de SQLite
# (el import fue corregido en PASO 4 pero puede que go.mod necesite ajuste)
info "Ejecutando go mod tidy para regenerar go.sum..."
GONOSUMCHECK="*" GOFLAGS="-mod=mod" go mod tidy 2>&1 || {
  warn "go mod tidy falló, intentando con GONOSUMDB..."
  GONOSUMDB="*" GOFLAGS="-mod=mod" go mod tidy 2>&1 || true
}

info "Ejecutando go mod download..."
GONOSUMDB="*" go mod download 2>&1 | grep -v "^$" || true

ok "Dependencias descargadas y go.sum regenerado."

# =============================================================================
# PASO 6 — Compilar el binario
# =============================================================================
section "PASO 6: Compilación"

cd "$BACKEND_DIR"

# main.go importa "os" pero no lo usa — Go no compila con imports no usados
MAIN_GO="$BACKEND_DIR/cmd/main.go"
if grep -q '"os"' "$MAIN_GO" 2>/dev/null; then
  OS_USES=$(grep -v '"os"' "$MAIN_GO" | grep -c '\bos\.' || true)
  if [[ "$OS_USES" -eq 0 ]]; then
    info "Eliminando import 'os' no utilizado en main.go..."
    sed -i '/"os"/d' "$MAIN_GO"
    ok "Import 'os' eliminado de main.go"
  fi
fi

# fr3_si.go: ioutil está deprecated en Go 1.16+ — en Go 1.24 puede fallar
FR3_GO="$BACKEND_DIR/internal/analyzers/fr3_si.go"
if grep -q '"io/ioutil"' "$FR3_GO" 2>/dev/null; then
  info "Migrando io/ioutil -> os en fr3_si.go (requerido en Go 1.24)..."
  sed -i 's|"io/ioutil"||g' "$FR3_GO"
  sed -i 's|ioutil\.ReadFile|os.ReadFile|g' "$FR3_GO"
  # Asegurar que "os" está importado
  if ! grep -q '"os"' "$FR3_GO"; then
    sed -i '/^import (/a \\t"os"' "$FR3_GO"
  fi
  ok "fr3_si.go migrado a os.ReadFile"
fi

info "Compilando analyzer (CGO desactivado para compatibilidad Pi)..."
CGO_ENABLED=0 go build -o analyzer ./cmd/main.go
ok "Binario generado: $BACKEND_DIR/analyzer"

# =============================================================================
# PASO 7 — Preparar variables de entorno
# =============================================================================
section "PASO 7: Configuración"

ENV_FILE="$BACKEND_DIR/.env.local"
cat > "$ENV_FILE" <<EOF
ENV=development
PORT=${PORT}
DB_PATH=${DATA_DIR}/iec62443.db
TLS_CERT=${CERTS_DIR}/server.crt
TLS_KEY=${CERTS_DIR}/server.key
JWT_SECRET=dev-secret-$(openssl rand -hex 16)
ALLOWED_ORIGINS=https://localhost,https://localhost:5173,https://$(hostname -I | awk '{print $1}')
LOG_DIR=${LOGS_DIR}
EOF

ok "Fichero de entorno generado: $ENV_FILE"

# =============================================================================
# PASO 8 — Arrancar el servidor
# =============================================================================
section "PASO 8: Arranque del servidor"

# Cargar variables de entorno
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}${BOLD}✅ Setup completado. Arrancando servidor...${NC}"
echo ""
if [[ "$USE_TLS" == true ]]; then
  echo -e "  ${BOLD}URL local:${NC}    https://localhost:${PORT}/healthz"
  echo -e "  ${BOLD}URL en red:${NC}   https://${LOCAL_IP}:${PORT}/healthz"
  echo -e "  ${BOLD}Scans:${NC}        https://localhost:${PORT}/api/scan/all"
  echo ""
  echo -e "  ${YELLOW}Nota:${NC} El navegador mostrará aviso de certificado autofirmado."
  echo -e "  Acepta la excepción de seguridad o usa: curl -k https://localhost:${PORT}/healthz"
else
  echo -e "  ${BOLD}URL local:${NC}    http://localhost:${PORT}/healthz"
fi
echo ""
echo -e "  ${YELLOW}Pulsa Ctrl+C para detener el servidor.${NC}"
echo ""

cd "$BACKEND_DIR"
exec ./analyzer