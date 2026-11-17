#!/usr/bin/env bash
# Levanta el entorno e instala WordPress, WooCommerce, usuarios y datos de ejemplo.
# Uso: ./scripts/instalar.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# Evita que Git Bash convierta /scripts/... en una ruta de Windows.
export MSYS_NO_PATHCONV=1

if [ ! -f .env ]; then
  echo "No existe .env. Copia la plantilla con: cp .env.example .env" >&2
  exit 1
fi

echo "Levantando db y wordpress..."
docker compose up -d --wait db wordpress

echo "Instalando con WP-CLI..."
docker compose run --rm wpcli bash /scripts/instalar-wordpress.sh

echo "Entorno listo en http://localhost:8080"
