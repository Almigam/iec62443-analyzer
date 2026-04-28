#!/bin/bash
# =============================================================================
# IEC 62443-3-3 Analyzer - Script rápido para arranque en DEV
# Uso: bash run-dev.sh [--port 8080]
# =============================================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

PORT=8080
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$REPO_DIR/backend"

# Parseo de argumentos
while [[ $# -gt 0 ]]; do
  case $1 in
    --port) PORT="$2"; shift 2 ;;
    --help)
      echo "Uso: bash run-dev.sh [--port 8080]"
      exit 0 ;;
    *) shift ;;
  esac
done

# Verificaciones
[[ -d "$BACKEND_DIR" ]] || error "No se encontró directorio backend"
[[ -f "$BACKEND_DIR/cmd/main.go" ]] || error "No se encontró main.go"

BINARY="$BACKEND_DIR/analyzer"
if [[ ! -x "$BINARY" ]] || [[ "$BACKEND_DIR/cmd/main.go" -nt "$BINARY" ]] || [[ "$BACKEND_DIR/internal" -nt "$BINARY" ]]; then
  info "Compilando backend..."
  cd "$BACKEND_DIR" || error "No se puede acceder al directorio backend"
  CGO_ENABLED=0 go build -o analyzer ./cmd/main.go || error "No se pudo compilar el backend"
  ok "Backend compilado: $BINARY"
fi

if [[ ! -x "$BINARY" ]]; then
  error "El binario 'analyzer' no se creó correctamente"
fi

echo -e "\n${BOLD}╔═════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   IEC 62443 Analyzer - DEV Server       ║${NC}"
echo -e "${BOLD}╚═════════════════════════════════════════╝${NC}\n"

info "Puerto: $PORT"

# Crear directorios si no existen
mkdir -p "$BACKEND_DIR/data" "$BACKEND_DIR/logs"

# Preparar .env.local
ENV_FILE="$BACKEND_DIR/.env.local"
if [[ ! -f "$ENV_FILE" ]]; then
  LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")
  cat > "$ENV_FILE" <<EOF
ENV=development
PORT=${PORT}
DB_PATH=${BACKEND_DIR}/data/iec62443.db
LOG_DIR=${BACKEND_DIR}/logs
JWT_SECRET=dev-secret-insecure
ALLOWED_ORIGINS=http://localhost,http://127.0.0.1,http://${LOCAL_IP},http://localhost:5173
EOF
  info "Creado: $ENV_FILE"
fi

# Cargar variables de entorno
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

echo ""
echo -e "${GREEN}${BOLD}✅ Iniciando servidor...${NC}\n"
echo -e "  ${BOLD}Local:${NC}   http://localhost:${PORT}/healthz"
echo -e "  ${BOLD}API:${NC}     http://localhost:${PORT}/api/*"
echo -e "  ${BOLD}DB:${NC}     ${DB_PATH}"
echo ""

cd "$BACKEND_DIR"
exec ./analyzer
