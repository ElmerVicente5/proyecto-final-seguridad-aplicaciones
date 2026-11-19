#!/usr/bin/env bash
# Levanta el entorno en uno de los tres estados del proyecto, para reproducir cualquier fase
# y mostrar el antes/despues. Usa los compose congelados de docs/antes-despues sin tocar el vigente.
#
# Uso: ./scripts/levantar-estado.sh <linea-base|endurecido|waf>
#   linea-base  linea base vulnerable (sin hardening, sin WAF)      -> fases 1, 2 y 3
#   endurecido  compose endurecido con Docker secrets, sin WAF      -> fase 4
#   waf         endurecido con WAF delante (estado final)           -> fase 5
#
# El plugin (vulnerable o seguro) se elige aparte con PLUGIN_VERSION en .env.
# Para las pruebas de ataque de la fase 3 usa la linea base con PLUGIN_VERSION=vulnerable.
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

if [ ! -f .env ]; then
  echo "No existe .env; copia .env.example a .env primero." >&2
  exit 1
fi

case "${1:-}" in
  linea-base) COMPOSE=docs/antes-despues/fase4_docker-compose.antes.yml;   USA_SECRETS=0 ;;
  endurecido) COMPOSE=docs/antes-despues/fase4_docker-compose.despues.yml; USA_SECRETS=1 ;;
  waf)        COMPOSE=docs/antes-despues/fase5_docker-compose.despues.yml; USA_SECRETS=1 ;;
  *)
    grep -E "^#   (linea-base|endurecido|waf)" "$0" | sed 's/^#   /  /'
    echo "Uso: $0 <linea-base|endurecido|waf>" >&2
    exit 1 ;;
esac

# Todos los comandos usan el compose del estado, con la raiz como directorio de rutas relativas.
dc() { docker compose -f "$COMPOSE" --project-directory . "$@"; }

echo "Reiniciando el entorno en el estado: $1"
# --remove-orphans elimina contenedores de otros estados (por ejemplo el WAF al pasar a linea-base).
dc down -v --remove-orphans 2>&1 | tail -1 || true

if [ "$USA_SECRETS" = "1" ]; then
  ./scripts/generar-secretos.sh
fi

echo "Instalando dependencias PHP del plugin..."
for version in vulnerable seguro; do
  dc run --rm composer install -d "$version" --no-dev --no-interaction --no-progress >/dev/null
done

echo "Levantando los contenedores..."
dc up -d --wait

echo "Instalando WordPress con WP-CLI..."
dc run --rm wpcli bash /scripts/instalar-wordpress.sh

echo
echo "Entorno levantado en el estado '$1' (plugin: $(grep '^PLUGIN_VERSION=' .env | cut -d= -f2))."
echo "Tienda en http://localhost:8080"
echo "Para comparar el antes/despues, levanta otro estado y repite las pruebas de la fase."
