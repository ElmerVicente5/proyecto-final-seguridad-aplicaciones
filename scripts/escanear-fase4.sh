#!/usr/bin/env bash
# Audita las imagenes con Trivy y el docker-compose.yml con KICS, para la fase 4 (antes/despues).
# Checkov ya no soporta docker-compose, por eso el compose se audita con KICS.
# Uso: ./scripts/escanear-fase4.sh antes    (o: despues)
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

MOMENTO="${1:-antes}"
if [ "$MOMENTO" != "antes" ] && [ "$MOMENTO" != "despues" ]; then
  echo "Uso: $0 antes|despues" >&2
  exit 1
fi

TRIVY_IMAGE=aquasec/trivy:0.76.2
KICS_IMAGE=checkmarx/kics:v2.2.1-alpine
SALIDA=reportes/fase4-iac
FECHA=$(date +%F)
mkdir -p "$SALIDA"

# Imagenes tomadas del docker-compose.
IMAGENES="mysql:8.4.13 wordpress:7.1.4-php8.3-apache wordpress:cli-2.12.0-php8.3"

for imagen in $IMAGENES; do
  nombre=$(echo "$imagen" | tr '/:.' '_')
  echo "Trivy sobre la imagen $imagen..."
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
    "$TRIVY_IMAGE" image --quiet --scanners vuln --severity HIGH,CRITICAL --no-progress \
    --format table "$imagen" > "$SALIDA/${FECHA}_trivy_${MOMENTO}_${nombre}.txt"
done

echo "KICS sobre docker-compose.yml..."
destino="$SALIDA/kics_${MOMENTO}"
mkdir -p "$destino"
docker run --rm -v "$PWD":/src "$KICS_IMAGE" scan \
  -p /src/docker-compose.yml -t DockerCompose \
  -o "/src/$destino" --report-formats json --no-progress --ci \
  > "$SALIDA/${FECHA}_kics_${MOMENTO}_docker-compose.txt" 2>&1 || true

# Resumen legible del JSON de KICS junto al reporte de texto.
python scripts/resumir_kics.py "$destino/results.json" >> "$SALIDA/${FECHA}_kics_${MOMENTO}_docker-compose.txt"

echo
echo "Reportes de $MOMENTO en $SALIDA:"
ls -1 "$SALIDA" | grep "_${MOMENTO}_"
