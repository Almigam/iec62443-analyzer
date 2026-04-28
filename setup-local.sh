#!/bin/bash
# =============================================================================
# IEC 62443-3-3 Analyzer - Setup y arranque local (HTTP)
# Uso: bash setup-local.sh [--port 8080]
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
PORT=8080
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GO_VERSION="1.22"
GO_ARCH="arm64"

# ── Parseo de argumentos ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --port)   PORT="$2"; shift 2 ;;
    --dir)    REPO_DIR="$2"; shift 2 ;;
    --help)
      echo "Uso: bash setup-local.sh [--port 8080] [--dir /ruta/repo]"
      exit 0 ;;
    *) warn "Argumento desconocido: $1"; shift ;;
  esac
done

# ── Detección del directorio del repo ────────────────────────────────────────
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
  error "No se encontró backend/cmd/main.go desde $REPO_DIR"
else
  REPO_DIR="$DETECTED"
fi

BACKEND_DIR="$REPO_DIR/backend"
DATA_DIR="$BACKEND_DIR/data"
LOGS_DIR="$BACKEND_DIR/logs"

echo -e "\n${BOLD}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   IEC 62443-3-3 Analyzer — Setup Local HTTP   ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════╝${NC}"
info "Repositorio : $REPO_DIR"
info "Puerto      : $PORT (HTTP)"
echo ""

# =============================================================================
# PASO 1 — Verificar/Instalar Go
# =============================================================================
section "PASO 1: Go $GO_VERSION+"

# Añadir rutas habituales de Go al PATH
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"

if command -v go &>/dev/null; then
  CURRENT=$(go version | awk '{print $3}' | sed 's/go//')
  ok "$CURRENT"
else
  warn "Go 1.22+ no encontrado o versión insuficiente"
  
  # Intentar descargar e instalar Go
  info "Descargando Go..."
  cd /tmp
  GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
  
  if wget -q --show-progress "$GO_URL" -O go.tar.gz 2>/dev/null || \
     curl -L "$GO_URL" -o go.tar.gz 2>/dev/null; then
    info "Extrayendo Go..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go.tar.gz
    rm -f go.tar.gz
    export PATH="/usr/local/go/bin:$PATH"
    grep -q '/usr/local/go/bin' ~/.bashrc || \
      echo 'export PATH="/usr/local/go/bin:$PATH"' >> ~/.bashrc
    ok "$(go version)"
  else
    error "No se pudo descargar Go. Descárgalo manualmente desde https://go.dev/dl/"
  fi
fi


# =============================================================================
# PASO 2 — Crear directorios
# =============================================================================
section "PASO 2: Directorios"

mkdir -p "$DATA_DIR" "$LOGS_DIR"
chmod 750 "$DATA_DIR" "$LOGS_DIR"
ok "Directorios listos: data/ logs/"



# =============================================================================
# PASO 3 — Correcciones de código fuente
# =============================================================================
section "PASO 3: Correcciones necesarias"

# Verificar y corregir db.go si es necesario
DB_GO="$BACKEND_DIR/internal/database/db.go"
if [[ -f "$DB_GO" ]]; then
  if grep -q '"gorm.io/driver/sqlite"' "$DB_GO"; then
    info "Corrigiendo import de SQLite en db.go..."
    sed -i 's|"gorm.io/driver/sqlite"|"github.com/glebarez/sqlite"|g' "$DB_GO"
    ok "✓ Import SQLite corregido"
  fi
fi

# Verificar main.go
MAIN_GO="$BACKEND_DIR/cmd/main.go"
if [[ -f "$MAIN_GO" ]]; then
  if grep -q 'import.*"os"' "$MAIN_GO" && ! grep -q '\bos\.' "$MAIN_GO"; then
    info "Eliminando import 'os' no usado en main.go..."
    sed -i '/"os"/d' "$MAIN_GO"
    ok "✓ Import 'os' eliminado"
  fi
fi

# Verificar fr3_si.go si existe
FR3_GO="$BACKEND_DIR/internal/analyzers/fr3_si.go"
if [[ -f "$FR3_GO" ]] && grep -q '"io/ioutil"' "$FR3_GO"; then
  info "Migrando io/ioutil a os en fr3_si.go..."
  sed -i 's|"io/ioutil"|"|g' "$FR3_GO"
  sed -i 's|ioutil\.ReadFile|os.ReadFile|g' "$FR3_GO"
  if ! grep -q '"os"' "$FR3_GO"; then
    sed -i '/^import (/a \\t"os"' "$FR3_GO"
  fi
  ok "✓ fr3_si.go migrado"
fi

ok "Correcciones completadas"

# =============================================================================
# PASO 4 — Descargar dependencias Go
# =============================================================================
section "PASO 4: Dependencias Go"

cd "$BACKEND_DIR" || error "No se encontró backend"

# Limpiar go.sum para regenerarlo
if [[ -f "go.sum" ]]; then
  info "Limpiando go.sum..."
  rm -f go.sum
fi

# Descargar módulos
info "Ejecutando go mod tidy..."
if GONOSUMDB="*" go mod tidy 2>&1 > /tmp/go_tidy.log; then
  ok "✓ go mod tidy"
else
  warn "go mod tidy generó advertencias (podrían ser normales)"
fi

info "Descargando dependencias..."
if GONOSUMDB="*" go mod download 2>&1 > /tmp/go_download.log; then
  ok "✓ Dependencias descargadas"
else
  error "Error descargando dependencias. Ver /tmp/go_download.log"
fi

# =============================================================================
# PASO 5 — Compilar binario
# =============================================================================
section "PASO 5: Compilación"

cd "$BACKEND_DIR" || error "No se encontró backend"

info "Compilando analyzer (HTTP, sin TLS)..."
if CGO_ENABLED=0 go build -o analyzer ./cmd/main.go 2>&1; then
  ok "✓ Binario compilado: ./analyzer"
else
  error "Error en la compilación. Revisa los errores arriba."
fi

# Verificar que el binario existe y es ejecutable
if [[ -x "analyzer" ]]; then
  ok "✓ Binario listo para ejecutar"
else
  error "El binario no se creó correctamente"
fi


# =============================================================================
# PASO 6 — Configuración del entorno
# =============================================================================
section "PASO 6: Configuración"

ENV_FILE="$BACKEND_DIR/.env.local"
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")

cat > "$ENV_FILE" <<EOF
# IEC 62443-3-3 Analyzer - Configuración Local
ENV=development
PORT=${PORT}
DB_PATH=${DATA_DIR}/iec62443.db
LOG_DIR=${LOGS_DIR}
JWT_SECRET=dev-secret-$(openssl rand -hex 16 2>/dev/null || echo "localdev")
ALLOWED_ORIGINS=http://localhost,http://localhost:5173,http://127.0.0.1,http://${LOCAL_IP}
EOF

ok "Configuración: $ENV_FILE"

# =============================================================================
# PASO 7 — Arrancar servidor
# =============================================================================
section "PASO 7: Arranque"

# Cargar variables de entorno
set -a
source "$ENV_FILE"
set +a

echo ""
echo -e "${GREEN}${BOLD}✅ Setup completado. Iniciando servidor...${NC}"
echo ""
echo -e "  ${BOLD}URL local:${NC}    http://localhost:${PORT}/healthz"
if [[ "$LOCAL_IP" != "127.0.0.1" ]]; then
  echo -e "  ${BOLD}URL en red:${NC}   http://${LOCAL_IP}:${PORT}/healthz"
fi
echo -e "  ${BOLD}API:${NC}          http://localhost:${PORT}/api/*"
echo ""
echo -e "  ${YELLOW}Pulsa Ctrl+C para detener el servidor.${NC}"
echo ""

cd "$BACKEND_DIR" || error "No se encontró backend"
exec ./analyzer
