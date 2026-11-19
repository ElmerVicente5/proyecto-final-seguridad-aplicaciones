#!/usr/bin/env bash
# Escanea con Nmap (en Docker) los puertos publicados en el anfitrion y la red interna de Docker.
# Uso: ./scripts/escanear-nmap.sh
# Reproduce el escaneo de la fase 3; para ver MySQL expuesto hay que tener levantada la linea base.
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

NMAP_IMAGE=${NMAP_IMAGE:-instrumentisto/nmap:7.98-r2}
RED=${RED:-umg-wp-ecommerce_default}
SALIDA=reportes/fase3-pentest
mkdir -p "$SALIDA"
FECHA=$(date +%F)

echo "Nmap sobre los puertos publicados en el anfitrion..."
{
  echo '$ nmap -sV -p 8080,3306 --reason host.docker.internal'
  docker run --rm --add-host host.docker.internal:host-gateway "$NMAP_IMAGE" \
    -sV -p 8080,3306 --reason host.docker.internal 2>&1 | grep -vE "^Starting Nmap|Service detection"
} > "$SALIDA/${FECHA}_nmap_host-puertos-publicados.txt"

echo "Nmap sobre la red interna de Docker..."
{
  echo "\$ nmap -sV -sC --open -p 80,3306,443 (contenedores de la red $RED)"
  docker run --rm --network "$RED" "$NMAP_IMAGE" \
    -sV -sC --open -p 80,3306,443 172.19.0.0/29 2>&1 | grep -vE "^Starting Nmap|Service detection|^\s*$"
} > "$SALIDA/${FECHA}_nmap_red-interna-docker.txt"

echo "Reportes de Nmap en $SALIDA"
