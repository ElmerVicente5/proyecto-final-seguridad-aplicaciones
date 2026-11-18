#!/usr/bin/env bash
# Ejecuta el plan de caja negra de OWASP ZAP contra la tienda en localhost y guarda los reportes.
# Uso: ./scripts/escanear-zap.sh   (requiere ZAP y Java instalados en Windows)
set -euo pipefail
cd "$(dirname "$0")/.."

ZAP_DIR=${ZAP_DIR:-"/c/Program Files/ZAP/Zed Attack Proxy"}
ZAP_JAR=$(ls "$ZAP_DIR"/zap-*.jar | head -1)
ZAP_REPORTES="$(cygpath -m "$PWD/reportes/fase3-pentest")"
FECHA=$(date +%F)
export ZAP_REPORTES FECHA
mkdir -p reportes/fase3-pentest

# Carpeta de configuración propia para no chocar con una ventana de ZAP abierta.
CONFIG_ZAP="$(cygpath -m "${TEMP:-/tmp}/zap-cli")"
PLAN="$(cygpath -m "$PWD/scripts/zap/plan-caja-negra.yaml")"

# ZAP busca sus complementos relativo a su carpeta; el puerto 8090 evita chocar con WordPress en 8080.
cd "$ZAP_DIR"
java -Xmx2g -jar "$(basename "$ZAP_JAR")" -cmd -dir "$CONFIG_ZAP" \
  -config network.localServers.mainProxy.port=8090 \
  -autorun "$PLAN"
