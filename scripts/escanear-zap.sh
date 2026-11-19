#!/usr/bin/env bash
# Ejecuta el plan de caja negra de OWASP ZAP (en Docker) contra la tienda y guarda los reportes.
# Uso: ./scripts/escanear-zap.sh
# El objetivo por defecto es la tienda publicada en el anfitrion (host.docker.internal:8080).
# Para reproducir el escaneo de la fase 3 hay que tener levantada la linea base vulnerable.
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

ZAP_IMAGE=${ZAP_IMAGE:-zaproxy/zap-stable:2.17.0}
ZAP_TARGET=${ZAP_TARGET:-http://host.docker.internal:8080}
SALIDA=reportes/fase3-pentest
mkdir -p "$SALIDA"
FECHA=$(date +%F)

# ZAP corre dentro del contenedor; /zap/wrk es su directorio de trabajo montado.
docker run --rm \
  --add-host host.docker.internal:host-gateway \
  -v "$PWD/scripts/zap":/zap/wrk/plan:ro \
  -v "$PWD/$SALIDA":/zap/wrk/out \
  -e ZAP_TARGET="$ZAP_TARGET" \
  -e ZAP_REPORTES=/zap/wrk/out \
  -e FECHA="$FECHA" \
  "$ZAP_IMAGE" zap.sh -cmd -autorun /zap/wrk/plan/plan-caja-negra.yaml

echo "Reportes de ZAP en $SALIDA"
