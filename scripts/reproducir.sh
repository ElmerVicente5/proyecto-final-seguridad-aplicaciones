#!/usr/bin/env bash
# Punto de entrada unico para reproducir los escaneos de cada fase, todos en Docker.
# Uso: ./scripts/reproducir.sh <fase>
#   fase2   SAST (Semgrep) y SCA (Trivy) del plugin, en sus dos versiones
#   fase3   Nmap, ZAP, WPScan y Postman (caja negra y gris) contra la linea base
#   fase4   Trivy (imagenes) y KICS (compose) antes y despues del hardening
#   fase5   pruebas de bloqueo del WAF
# Requisitos: Docker y la CLI de Postman. Un .env valido para levantar el entorno.
set -euo pipefail
cd "$(dirname "$0")/.."

PM_ENV="postman/laboratorio-localhost.postman_environment.json"
clave_cliente() { grep '^CLIENTE_PASSWORD=' .env | cut -d= -f2; }

case "${1:-}" in
  fase2)
    ./scripts/escanear-fase2.sh
    ;;
  fase3)
    echo "Nota: la fase 3 se hace contra la linea base vulnerable."
    echo "Para reproducirla tal cual, levanta la linea base (plugin vulnerable, sin WAF)."
    ./scripts/escanear-nmap.sh
    ./scripts/escanear-zap.sh
    echo "WPScan (enumeracion)..."
    docker run --rm --network host wpscanteam/wpscan:v4.2.0 --url http://localhost:8080 \
      --enumerate u,cb,dbe --plugins-detection passive --no-banner --format cli-no-colour --no-update \
      | tee reportes/fase3-pentest/$(date +%F)_wpscan_enumeracion.txt
    echo "Postman (caja gris de WordPress y WooCommerce)..."
    postman collection run postman/wordpress-woocommerce-api.postman_collection.json -e "$PM_ENV"
    ;;
  fase4)
    ./scripts/escanear-fase4.sh antes
    ./scripts/escanear-fase4.sh despues
    ;;
  fase5)
    echo "Pruebas del WAF (requiere el entorno con WAF levantado: docker compose up -d)..."
    B=http://localhost:8080
    for ruta in "/" "/shop/"; do printf '  %-30s HTTP %s\n' "legitimo $ruta" "$(curl -s -o /dev/null -w '%{http_code}' $B$ruta)"; done
    printf '  %-30s HTTP %s\n' "SQLi (debe dar 403)" "$(curl -s -o /dev/null -w '%{http_code}' "$B/?id=1%27%20UNION%20SELECT%201--")"
    printf '  %-30s HTTP %s\n' "xmlrpc (debe dar 403)" "$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/xmlrpc.php)"
    echo "Postman (caja gris con WAF)..."
    postman collection run postman/wordpress-woocommerce-api.postman_collection.json -e "$PM_ENV"
    ;;
  *)
    grep -E "^#   fase" "$0" | sed 's/^#   /  /'
    echo "Uso: $0 <fase2|fase3|fase4|fase5>" >&2
    exit 1
    ;;
esac
