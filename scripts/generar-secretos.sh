#!/usr/bin/env bash
# Escribe los secretos que usa docker-compose como Docker secrets, leyendo los valores del .env.
# Los archivos quedan en secrets/ (ignorado por git). Se ejecuta antes de levantar el entorno.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "No existe .env; copia .env.example a .env primero." >&2
  exit 1
fi

# Lee una variable del .env sin ejecutar el archivo (admite valores con espacios).
valor() {
  local v
  v=$(grep -E "^$1=" .env | head -1 | cut -d= -f2-)
  printf '%s' "$v"
}

mkdir -p secrets
chmod 700 secrets

escribir() {
  # $1 archivo, $2 nombre de la variable en .env, $3 1 si es obligatorio
  local val
  val=$(valor "$2")
  if [ -z "$val" ] && [ "${3:-0}" = "1" ]; then
    echo "Falta $2 en .env" >&2
    exit 1
  fi
  printf '%s' "$val" > "secrets/$1"
  chmod 600 "secrets/$1"
}

escribir mysql_root_password.txt MYSQL_ROOT_PASSWORD 1
escribir mysql_password.txt MYSQL_PASSWORD 1
escribir wp_admin_password.txt WP_ADMIN_PASSWORD 1
escribir gestor_password.txt GESTOR_PASSWORD 1
escribir editor_password.txt EDITOR_PASSWORD 1
escribir cliente_password.txt CLIENTE_PASSWORD 1
escribir consulta_pedidos_jwt_secret.txt CONSULTA_PEDIDOS_JWT_SECRET 0

echo "Secretos generados en secrets/"
