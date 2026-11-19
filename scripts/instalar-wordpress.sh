#!/usr/bin/env bash
# Instala WordPress y WooCommerce con WP-CLI; corre dentro del contenedor wpcli y se puede repetir.
set -euo pipefail

export WP_CLI_CACHE_DIR=/tmp/wp-cli-cache

# Las contraseñas llegan como Docker secrets (archivos); se leen aquí a variables.
leer_secreto() {
  # $1 variable destino, $2 archivo de secreto, $3 variable de entorno de respaldo
  local archivo="/run/secrets/$2"
  if [ -f "$archivo" ]; then
    eval "$1=\$(cat '$archivo')"
  else
    eval "$1=\${$3:-}"
  fi
}
leer_secreto WP_ADMIN_PASSWORD wp_admin_password WP_ADMIN_PASSWORD
leer_secreto GESTOR_PASSWORD gestor_password GESTOR_PASSWORD
leer_secreto EDITOR_PASSWORD editor_password EDITOR_PASSWORD
leer_secreto CLIENTE_PASSWORD cliente_password CLIENTE_PASSWORD
# La comprobación de BD de abajo usa esta variable; la contraseña llega por el secreto mysql_password.
leer_secreto WORDPRESS_DB_PASSWORD mysql_password WORDPRESS_DB_PASSWORD
export WORDPRESS_DB_PASSWORD

: "${WP_URL:?}" "${WP_TITULO:?}" "${WP_ADMIN_USER:?}" "${WP_ADMIN_PASSWORD:?}" "${WP_ADMIN_EMAIL:?}"
: "${WOOCOMMERCE_VERSION:?}" "${GESTOR_PASSWORD:?}" "${EDITOR_PASSWORD:?}" "${CLIENTE_PASSWORD:?}"
CREAR_DATOS_EJEMPLO="${CREAR_DATOS_EJEMPLO:-1}"

log() { printf '\n%s\n' "$*"; }

# Se prueba la BD con mysqli porque el cliente mariadb de la imagen rechaza el TLS autofirmado de MySQL 8.
bd_lista() {
  php -r '$h=explode(":",getenv("WORDPRESS_DB_HOST")); mysqli_report(MYSQLI_REPORT_OFF);
    $c=@mysqli_connect($h[0],getenv("WORDPRESS_DB_USER"),getenv("WORDPRESS_DB_PASSWORD"),getenv("WORDPRESS_DB_NAME"),(int)($h[1]??3306));
    exit($c ? 0 : 1);'
}

log "Esperando archivos de WordPress y la base de datos..."
for i in $(seq 1 60); do
  if [ -f /var/www/html/wp-config.php ] && bd_lista; then break; fi
  if [ "$i" -eq 60 ]; then echo "WordPress o la BD no respondieron en 120 s." >&2; exit 1; fi
  sleep 2
done

if wp core is-installed >/dev/null 2>&1; then
  log "WordPress ya está instalado."
else
  log "Instalando WordPress en ${WP_URL}..."
  wp core install --url="${WP_URL}" --title="${WP_TITULO}" \
    --admin_user="${WP_ADMIN_USER}" --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}" --skip-email
fi

log "Configurando idioma, zona horaria y enlaces permanentes..."
wp language core install es_ES --activate >/dev/null 2>&1 || echo "No se pudo instalar es_ES; se sigue en inglés."
wp option update timezone_string "America/Guatemala"
# La API REST de WooCommerce necesita enlaces permanentes.
wp rewrite structure '/%postname%/'
wp rewrite flush

if wp plugin is-installed woocommerce; then
  log "WooCommerce ya está instalado."
else
  log "Instalando WooCommerce ${WOOCOMMERCE_VERSION}..."
  wp plugin install woocommerce --version="${WOOCOMMERCE_VERSION}"
fi
wp plugin is-active woocommerce || wp plugin activate woocommerce

log "Configurando la tienda..."
# Son opciones no críticas, así que un fallo solo se avisa.
opcion() {
  if wp option update "$@" >/dev/null 2>&1; then echo "  $1"; else echo "  No se pudo actualizar $1"; fi
}
opcion woocommerce_default_country "GT"
opcion woocommerce_currency "GTQ"
opcion woocommerce_store_city "Guatemala"
opcion woocommerce_store_address "Zona 1"
opcion woocommerce_onboarding_profile '{"skipped":true}' --format=json
opcion woocommerce_coming_soon "no"
opcion woocommerce_task_list_hidden "yes"
opcion woocommerce_allow_tracking "no"
opcion woocommerce_cod_settings '{"enabled":"yes","title":"Pago contra entrega"}' --format=json
wp wc tool run install_pages --user="${WP_ADMIN_USER}" >/dev/null 2>&1 || true

log "Activando el plugin propio Consulta de Pedidos..."
if wp plugin is-installed consulta-pedidos; then
  wp plugin is-active consulta-pedidos || wp plugin activate consulta-pedidos
  if [ "$(wp post list --post_type=page --name=consultar-pedido --format=count)" -eq 0 ]; then
    wp post create --post_type=page --post_status=publish --post_title="Consultar pedido" \
      --post_name=consultar-pedido --post_content='[consulta_pedidos]' --porcelain >/dev/null
    echo "  Página creada: ${WP_URL}/consultar-pedido/"
  fi
else
  echo "  No se encontró el plugin; revisa PLUGIN_VERSION en .env."
fi

crear_usuario() {
  local usuario=$1 email=$2 rol=$3 clave=$4 nombre=$5 apellido=$6
  if wp user get "$usuario" --field=ID >/dev/null 2>&1; then
    echo "  $usuario ya existe ($rol)"
  else
    wp user create "$usuario" "$email" --role="$rol" --user_pass="$clave" \
      --first_name="$nombre" --last_name="$apellido" --porcelain >/dev/null
    echo "  $usuario creado ($rol)"
  fi
}

log "Creando usuarios de prueba..."
crear_usuario gestor   gestor@tienda-umg.test   shop_manager "${GESTOR_PASSWORD}"  "Gabriela" "Gestora"
crear_usuario editor   editor@tienda-umg.test   editor       "${EDITOR_PASSWORD}"  "Eduardo"  "Editor"
crear_usuario cliente1 cliente1@tienda-umg.test customer     "${CLIENTE_PASSWORD}" "Carla"    "Cliente"
crear_usuario cliente2 cliente2@tienda-umg.test customer     "${CLIENTE_PASSWORD}" "Carlos"   "Comprador"

crear_producto() {
  wp wc product create --user="${WP_ADMIN_USER}" --porcelain --type=simple --status=publish \
    --name="$1" --regular_price="$2" --sku="$3" --manage_stock=true --stock_quantity="$4"
}

crear_pedido() {
  local usuario=$1 estado=$2 lineas=$3 nombre=$4 apellido=$5 cid email
  cid=$(wp user get "$usuario" --field=ID)
  email=$(wp user get "$usuario" --field=user_email)
  # No hay SMTP en el laboratorio, así que se ocultan solo los avisos de sendmail.
  wp wc shop_order create --user="${WP_ADMIN_USER}" --porcelain \
    --customer_id="$cid" --status="$estado" \
    --payment_method=cod --payment_method_title="Pago contra entrega" \
    --billing="{\"first_name\":\"$nombre\",\"last_name\":\"$apellido\",\"email\":\"$email\",\"phone\":\"5555-0000\",\"address_1\":\"Calle Falsa 123\",\"city\":\"Guatemala\",\"country\":\"GT\"}" \
    --line_items="$lineas" 2>/tmp/pedido.err || { cat /tmp/pedido.err >&2; return 1; }
  grep -v '^sendmail:' /tmp/pedido.err >&2 || true
}

if [ "${CREAR_DATOS_EJEMPLO}" = "1" ]; then
  num_productos=$(wp post list --post_type=product --post_status=any --format=count)
  if [ "$num_productos" -gt 0 ]; then
    log "Ya hay ${num_productos} productos; no se crean datos de ejemplo."
  else
    log "Creando productos de ejemplo..."
    p1=$(crear_producto "Camiseta UMG"          "95.00"  "UMG-CAM-01" 50)
    p2=$(crear_producto "Taza Seguridad"        "45.00"  "UMG-TAZ-01" 100)
    p3=$(crear_producto "Sudadero Ciberdefensa" "250.00" "UMG-SUD-01" 20)
    p4=$(crear_producto "Libro OWASP Top 10"    "180.00" "UMG-LIB-01" 15)
    echo "  Productos: $p1 $p2 $p3 $p4"

    # Pedidos de dos clientes distintos para las pruebas de BOLA/IDOR.
    log "Creando pedidos de ejemplo..."
    o1=$(crear_pedido cliente1 processing "[{\"product_id\":$p1,\"quantity\":2},{\"product_id\":$p2,\"quantity\":1}]" "Carla" "Cliente")
    o2=$(crear_pedido cliente2 completed  "[{\"product_id\":$p3,\"quantity\":1}]" "Carlos" "Comprador")
    o3=$(crear_pedido cliente2 on-hold    "[{\"product_id\":$p4,\"quantity\":1},{\"product_id\":$p2,\"quantity\":3}]" "Carlos" "Comprador")
    echo "  Pedidos: $o1 (cliente1), $o2 y $o3 (cliente2)"
  fi
fi

log "Resumen"
wp core version
wp plugin list --fields=name,status,version
wp user list --fields=ID,user_login,roles
log "Listo: ${WP_URL} (administración en ${WP_URL}/wp-admin)"
