#!/usr/bin/env bash
# Audita las imagenes con Trivy y el docker-compose con KICS, para la fase 4 (antes/despues).
# Checkov ya no soporta docker-compose, por eso el compose se audita con KICS.
# El antes/despues escanea los compose congelados de docs/antes-despues, para que sea reproducible.
# Uso: ./scripts/escanear-fase4.sh antes    (o: despues)
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

MOMENTO="${1:-antes}"
case "$MOMENTO" in
  antes)   COMPOSE=docs/antes-despues/fase4_docker-compose.antes.yml ;;
  despues) COMPOSE=docs/antes-despues/fase4_docker-compose.despues.yml ;;
  *) echo "Uso: $0 antes|despues" >&2; exit 1 ;;
esac

TRIVY_IMAGE=aquasec/trivy:0.76.2
KICS_IMAGE=checkmarx/kics:v2.2.1-alpine
SALIDA=reportes/fase4-iac
HTML="$SALIDA/html"
FECHA=$(date +%F)
mkdir -p "$SALIDA" "$HTML"

IMAGENES="mysql:8.4.13 wordpress:7.1.4-php8.3-apache wordpress:cli-2.12.0-php8.3"

for imagen in $IMAGENES; do
  nombre=$(echo "$imagen" | tr '/:.' '_')
  echo "Trivy sobre la imagen $imagen..."
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
    "$TRIVY_IMAGE" image --quiet --scanners vuln --severity HIGH,CRITICAL --no-progress \
    --format table "$imagen" > "$SALIDA/${FECHA}_trivy_${MOMENTO}_${nombre}.txt"
  # Reporte HTML para presentar como evidencia.
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
    "$TRIVY_IMAGE" image --quiet --scanners vuln --severity HIGH,CRITICAL --no-progress \
    --format template --template "@/contrib/html.tpl" -o "/root/.cache/t.html" "$imagen"
  docker run --rm -v trivy-cache:/root/.cache --entrypoint cat "$TRIVY_IMAGE" "/root/.cache/t.html" \
    > "$HTML/${FECHA}_trivy_${nombre}.html"
done

echo "KICS sobre $COMPOSE..."
destino="$SALIDA/kics_${MOMENTO}"
mkdir -p "$destino"
docker run --rm -v "$PWD":/src "$KICS_IMAGE" scan \
  -p "/src/$COMPOSE" -t DockerCompose \
  -o "/src/$destino" --report-formats json --no-progress --ci \
  > "$SALIDA/${FECHA}_kics_${MOMENTO}_docker-compose.txt" 2>&1 || true
# Reporte HTML de KICS.
docker run --rm -v "$PWD":/src -v "$PWD/$HTML":/out "$KICS_IMAGE" scan \
  -p "/src/$COMPOSE" -t DockerCompose \
  -o /out --output-name "${FECHA}_kics_${MOMENTO}" --report-formats html --no-progress --ci >/dev/null 2>&1 || true

python scripts/resumir_kics.py "$destino/results.json" >> "$SALIDA/${FECHA}_kics_${MOMENTO}_docker-compose.txt"

echo
echo "Reportes de $MOMENTO en $SALIDA (HTML en $HTML):"
ls -1 "$SALIDA" | grep "_${MOMENTO}_"
