# 🚀 Setup Rápido - IEC 62443 Analyzer (LOCAL HTTP)

## ✅ Cambios realizados

Se ha simplificado completamente la instalación para que funcione **SIN FALLOS** en LOCAL:

1. **HTTP en lugar de HTTPS** - Puerto 8080 por defecto (sin certificados autofirmados)
2. **Scripts mejorados** - Detección automática de Go, correcciones de imports
3. **Configuración automática** - Variables de entorno generadas automáticamente
4. **Errores manejados** - El script detiene si algo falla

---

## 📦 Opción 1: Setup Completo + Arranque (Recomendado para primera vez)

```bash
# Desde la raíz del proyecto
bash setup-local.sh --port 8080
```

**¿Qué hace?**
1. Verifica e instala Go 1.22+ si es necesario
2. Crea directorios necesarios (data/, logs/)
3. Corrige imports incompatibles en el código
4. Descarga todas las dependencias Go
5. Compila el binario `analyzer`
6. Genera archivo `.env.local` con configuración
7. **Arranca el servidor directamente**

**Opción**: Cambiar puerto con `--port 9000`

---

## 🏃 Opción 2: Arranque Rápido (Después de setup)

Si ya ejecutaste `setup-local.sh`, simplemente usa:

```bash
bash run-dev.sh --port 8080
```

**Compatible después de cambios en el código** - Solo rearranque el servidor.

---

## 🔍 Verificar que funciona

Una vez el servidor esté corriendo (sin Ctrl+C):

### En otra terminal:

```bash
# Health check
curl http://localhost:8080/healthz

# Resultado esperado:
# {"status":"healthy","timestamp":"2024-04-28T..."}
```

---

## 📁 Estructura después de setup

```
backend/
├── analyzer              ← Binario compilado (ejecutable)
├── .env.local           ← Configuración local (generada)
├── data/                ← Base de datos SQLite (se crea al ejecutar)
├── logs/                ← Logs de la aplicación
├── go.mod
├── go.sum               ← Regenerado
├── cmd/
│   └── main.go          ← Modificado para HTTP
└── internal/
    ├── config/
    │   └── config.go    ← Puerto por defecto 8080 ahora
    ├── database/
    │   └── db.go        ← Import SQLite corregido
    ├── api/
    └── analyzers/
```

---

## 🔧 Archivos modificados

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `setup-local.sh` | Nuevo + simplificado | HTTP, sin TLS, más robusto |
| `run-dev.sh` | Nuevo | Arranque rápido después de setup |
| `cmd/main.go` | `ListenAndServeTLS` → `ListenAndServe` | HTTP en lugar de HTTPS |
| `internal/config/config.go` | Puerto 443 → 8080, `https` → `http` | Valores por defecto para LOCAL |

---

## 🐛 Si algo falla

### Error: "Go 1.22+ no encontrado"
```bash
# El script intenta descargar Go automáticamente
# Si aun así falla, descárgalo manualmente:
# https://go.dev/dl/ (elige linux-arm64)
```

### Error: "El binario analyzer no existe"
```bash
# Significa que fallaron pasos anteriores
# Revisa el output del setup-local.sh
# Los logs están en /tmp/go_tidy.log y /tmp/go_download.log
```

### Puerto 8080 ya está en uso
```bash
bash setup-local.sh --port 9000    # Cambiar a 9000
# o
bash run-dev.sh --port 9000
```

### La base de datos falla
```bash
# Elimina la vieja y el script la recreará
rm backend/data/iec62443.db
bash run-dev.sh
```

---

## 🎯 Próximos pasos

1. **Frontend** (opcional):
   ```bash
   cd frontend
   npm install
   npm run dev
   # Acceder a http://localhost:5173/
   ```

2. **Probar API** (example):
   ```bash
   curl http://localhost:8080/api/scan/fr1 \
     -H "Content-Type: application/json" \
     -d '{"target": "/path/to/directory"}'
   ```

---

## 📝 Notas

- ✅ Todo funciona en HTTP (sin certificados)
- ✅ Puerto configurable (default 8080)
- ✅ Database SQLite automática
- ✅ CORS habilitado para desarrollo
- ✅ Logs en `backend/logs/`

**¿Algún problema adicional?** Ejecuta el setup nuevamente - es idempotente.
