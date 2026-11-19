#!/usr/bin/env bash
# Exporta los diagramas .drawio de docs/arquitectura a PNG en evidencias/capturas/fase1.
# Uso: ./scripts/exportar-diagramas.sh
set -euo pipefail
cd "$(dirname "$0")/.."
export MSYS_NO_PATHCONV=1

ORIGEN=docs/arquitectura
DESTINO=evidencias/capturas/fase1
mkdir -p "$DESTINO"

# El exportador usa drawio-desktop headless dentro del contenedor.
docker run --rm -v "$PWD/$ORIGEN":/data rlespinasse/drawio-export:v4.60.0 \
  -f png --scale 2 -o /data /data

# El exportador nombra cada PNG como <archivo>-<pagina>.png; se renombran limpio.
declare -A nombres=(
  [arquitectura-actual]=10_arquitectura-actual
  [arquitectura-redisenada]=11_arquitectura-redisenada
  [mapa-superficie-ataque]=../fase3/09_mapa-superficie-ataque
)
for base in "${!nombres[@]}"; do
  origen="$ORIGEN/${base}-${base}.png"
  [ -f "$origen" ] && mv "$origen" "$DESTINO/${nombres[$base]}.png" && echo "  ${nombres[$base]}.png"
done
echo "Diagramas exportados a $DESTINO"
