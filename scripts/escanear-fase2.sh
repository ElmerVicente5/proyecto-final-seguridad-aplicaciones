#!/usr/bin/env bash
# Ejecuta en local el mismo SAST (Semgrep) y SCA (Trivy) del pipeline y guarda los reportes.
# Uso: ./scripts/escanear-fase2.sh
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

SEMGREP_IMAGE=semgrep/semgrep:1.186.0
TRIVY_IMAGE=aquasec/trivy:0.76.2
SALIDA=reportes/fase2-sast-sca
FECHA=$(date +%F)
mkdir -p "$SALIDA"

for version in vulnerable seguro; do
  echo "Semgrep sobre la versión $version..."
  docker run --rm -e HOME=/tmp -v "$PWD:/src" -w /src "$SEMGREP_IMAGE" semgrep scan \
    --metrics=off --quiet \
    --config .semgrep/wordpress.yml \
    --config p/php --config p/owasp-top-ten --config p/secrets \
    --exclude vendor \
    --json-output="$SALIDA/${FECHA}_semgrep_${version}.json" \
    --text-output="$SALIDA/${FECHA}_semgrep_${version}.txt" \
    "plugin-consulta-pedidos/$version" >/dev/null || true

  echo "Trivy sobre las dependencias de la versión $version..."
  for formato in json table; do
    extension=$([ "$formato" = table ] && echo txt || echo json)
    docker run --rm -v "$PWD:/src" -v trivy-cache:/cache "$TRIVY_IMAGE" --cache-dir /cache \
      fs --quiet --scanners vuln --format "$formato" \
      --output "/src/$SALIDA/${FECHA}_trivy_${version}.${extension}" \
      "/src/plugin-consulta-pedidos/$version"
  done
done

echo "Reportes guardados en $SALIDA:"
ls -1 "$SALIDA" | grep "^$FECHA"
